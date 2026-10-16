#!/bin/bash
# Scoped to the 2.0.4 NVRMFB experiment. No EFI, boot-argument or userland changes.
set -euo pipefail
die() { echo "STOP: $*" >&2; exit 1; }
usage() { echo 'Usage: sudo bash install_framebuffer.sh --install'; echo 'Restore: sudo bash install_framebuffer.sh --restore /Library/NullMoth/hidpi-backup-...'; exit 2; }
[ "$#" -ge 1 ] || usage
mode=$1
case "$mode" in --install) [ "$#" = 1 ] || usage;; --restore) [ "$#" = 2 ] || usage;; *) usage;; esac
[ "$(id -u)" -eq 0 ] || die 'Run with sudo'
[ "$(uname -m)" = x86_64 ] || die 'x86_64 only'
case "$(sw_vers -productVersion)" in 15.*) ;; *) die 'This experiment is scoped to macOS 15';; esac
[ "$(cat /Library/NullMoth/driver-version 2>/dev/null)" = 2.0.4 ] || die 'Installed driver version must be 2.0.4'
here=$(cd "$(dirname "$0")" && pwd)
ext=/Library/Extensions/NVRMFB.kext
kc=/Library/KernelCollections/AuxiliaryKernelExtensions.kc
lock=/Library/NullMoth/install.lock
backup=''; writing=0; held=0; newkc=''
[ -d /Library/NullMoth ] && [ ! -L /Library/NullMoth ] || die 'Unexpected NullMoth directory'
[ -d "$ext" ] && [ ! -L "$ext" ] || die 'Expected a real installed NVRMFB bundle'
[ -f "$kc" ] && [ ! -L "$kc" ] || die 'Expected an existing auxiliary kernel collection'
restore_files() {
  [ -d "$backup/NVRMFB.kext" ] && [ -s "$backup/AuxiliaryKernelExtensions.kc" ] || return 1
  rm -rf "$ext" || return 1
  ditto "$backup/NVRMFB.kext" "$ext" || return 1
  chown -R root:wheel "$ext" || return 1
  chmod -R go-w,a+rX "$ext" || return 1
  cp -p "$backup/AuxiliaryKernelExtensions.kc" "$kc" || return 1
}
cleanup() {
  local status=$?
  trap - EXIT HUP INT TERM
  if [ "$writing" = 1 ]; then
    echo 'Installation interrupted or failed; restoring the saved NVRMFB and kernel collection.' >&2
    if restore_files; then echo 'Original files restored.' >&2
    else echo "RESTORE INCOMPLETE: keep backup $backup and use the existing driver recovery entry." >&2; status=1; fi
  fi
  [ -z "$newkc" ] || rm -f "$newkc" || true
  [ "$held" = 0 ] || rmdir "$lock" || true
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM
mkdir -m 700 "$lock" 2>/dev/null || die 'Another driver operation or its guard exists; do not remove it while another operation runs'
held=1
if [ "$mode" = --restore ]; then
  backup=${2%/}
  case "$backup" in /Library/NullMoth/hidpi-backup-*/*) die 'Nested backup paths are not accepted';; esac
  case "$backup" in /Library/NullMoth/hidpi-backup-*) ;; *) die 'Unexpected backup path';; esac
  [ -d "$backup" ] && [ ! -L "$backup" ] && [ "$(stat -f %u "$backup")" = 0 ] || die 'Backup is not a root-owned directory'
  [ "$(cat "$backup/macos-build")" = "$(sw_vers -buildVersion)" ] || die 'Backup belongs to a different macOS build'
  restore_files || die "Restore failed; retain $backup and use the existing driver recovery entry"
  echo "RESTORED from $backup"
  echo 'Remove nvfbhidpi=1 from your startup config if present, then restart.'
  exit 0
fi
[ -f "$here/check_framebuffer.sh" ] || die 'Keep check_framebuffer.sh in this folder'
/bin/bash "$here/check_framebuffer.sh"
backup=$(mktemp -d "/Library/NullMoth/hidpi-backup-$(date +%Y%m%d-%H%M%S).XXXXXX")
echo "BACKUP: $backup"
sw_vers -buildVersion > "$backup/macos-build"
ditto "$ext" "$backup/NVRMFB.kext"
cp -p "$kc" "$backup/AuxiliaryKernelExtensions.kc"
cmp "$ext/Contents/MacOS/NVRMFB" "$backup/NVRMFB.kext/Contents/MacOS/NVRMFB"
cmp "$kc" "$backup/AuxiliaryKernelExtensions.kc"
# Stage in the private backup directory and verify exactly what will be installed.
ditto "$here/NVRMFB.kext" "$backup/experimental/NVRMFB.kext"
cp "$here/PAYLOAD-SHA256.txt" "$backup/experimental/PAYLOAD-SHA256.txt"
(cd "$backup/experimental" && shasum -a 256 -c PAYLOAD-SHA256.txt)
writing=1
rm -rf "$ext"
ditto "$backup/experimental/NVRMFB.kext" "$ext"
chown -R root:wheel "$ext"
chmod -R go-w,a+rX "$ext"
args=(--allow-missing-kdk)
[ ! -f /System/Library/Kernels/kernel ] || args+=(--kernel /System/Library/Kernels/kernel)
candidate="/Library/KernelCollections/AuxiliaryKernelExtensions.hidpi-$$.kc"
[ ! -e "$candidate" ] || die 'Temporary collection path already exists'
newkc=$candidate
if ! kmutil create -n aux --volume-root / "${args[@]}" \
  -B /System/Library/KernelCollections/BootKernelExtensions.kc \
  -S /System/Library/KernelCollections/SystemKernelExtensions.kc \
  --repository /Library/Extensions -A "$newkc" -z > "$backup/kmutil-install.log" 2>&1; then
  tail -n 45 "$backup/kmutil-install.log"
  die 'Live collection build failed'
fi
[ -s "$newkc" ] || die 'New collection is empty'
kmutil inspect -a x86_64 -A "$newkc" > "$backup/inspect.txt" 2>&1
for k in NVRM NVAccel NVRMFB NVRMAGDC; do
  grep -oE 'com\.nullmoth\.[A-Za-z0-9]+' "$backup/inspect.txt" | grep -Fx "com.nullmoth.$k" > /dev/null \
    || die "New collection omitted $k"
done
mv -f "$newkc" "$kc"
newkc=''; writing=0
echo "INSTALL OK. Backup retained: $backup"
echo 'The currently running driver is unchanged until restart.'
echo 'Enable nvfbhidpi=1 in the actual startup OpenCore config, then restart.'
echo 'First test 1600x1000 HiDPI at 60 Hz. No automatic restart was performed.'
