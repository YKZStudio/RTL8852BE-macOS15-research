#!/bin/bash
# Local compatibility preflight only. Does not replace drivers or active collections.
set -euo pipefail
die() { echo "STOP: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "Run with sudo"
[ "$(uname -m)" = x86_64 ] || die "x86_64 only"
case "$(sw_vers -productVersion)" in 15.*) ;; *) die "This experiment is scoped to macOS 15";; esac
[ "$(cat /Library/NullMoth/driver-version 2>/dev/null)" = 2.0.4 ] || die "Installed driver version record must be 2.0.4"
here=$(cd "$(dirname "$0")" && pwd)
[ -f "$here/NVRMFB.kext/Contents/MacOS/NVRMFB" ] || die "Unzip the experimental NVRMFB next to this script"
bundle=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$here/NVRMFB.kext/Contents/Info.plist")
[ "$bundle" = com.nullmoth.NVRMFB ] || die "Unexpected bundle ID"
(cd "$here" && shasum -a 256 -c PAYLOAD-SHA256.txt) || die "Payload hash mismatch"
for k in NVRM NVAccel NVRMFB NVRMAGDC; do
  [ -f "/Library/Extensions/$k.kext/Contents/MacOS/$k" ] || die "Missing installed $k"
done
tmp=$(mktemp -d /private/var/tmp/nvrmfb-hidpi-check.XXXXXX)
# Keep the log if the test fails. mktemp created a private, root-owned directory.
echo "LOG DIRECTORY: $tmp"
mkdir "$tmp/repo"
for x in /Library/Extensions/*.kext; do
  [ -d "$x" ] || continue
  [ "$(basename "$x")" = NVRMFB.kext ] && continue
  ditto "$x" "$tmp/repo/$(basename "$x")"
done
ditto "$here/NVRMFB.kext" "$tmp/repo/NVRMFB.kext"
chown -R root:wheel "$tmp/repo"
chmod -R go-w,a+rX "$tmp/repo"
args=(--allow-missing-kdk)
[ ! -f /System/Library/Kernels/kernel ] || args+=(--kernel /System/Library/Kernels/kernel)
if ! kmutil create -n aux --volume-root / "${args[@]}" \
  -B /System/Library/KernelCollections/BootKernelExtensions.kc \
  -S /System/Library/KernelCollections/SystemKernelExtensions.kc \
  --repository "$tmp/repo" -A "$tmp/aux.kc" -z >"$tmp/kmutil.log" 2>&1; then
  tail -n 45 "$tmp/kmutil.log"
  die "Test kernel collection failed; active drivers were not changed"
fi
[ -s "$tmp/aux.kc" ] || die "Test collection is empty"
kmutil inspect -a x86_64 -A "$tmp/aux.kc" > "$tmp/inspect.txt" 2>&1 || die "Cannot inspect test collection"
for k in NVRM NVAccel NVRMFB NVRMAGDC; do
  grep -oE 'com\.nullmoth\.[A-Za-z0-9]+' "$tmp/inspect.txt" | grep -Fx "com.nullmoth.$k" > /dev/null \
    || die "Test collection omitted $k"
done
echo 'CHECK PASS: all four driver kexts are present in the test kernel collection.'
echo 'No installed driver, EFI, NVRAM or active kernel collection was changed.'
