#!/bin/bash
# Experimental build recipe. Requires macOS + Xcode; not hardware verified.
set -euo pipefail
recipe_dir="$(cd "$(dirname "$0")" && pwd)"
source_dir="${1:?Pass the pinned AirportRTW checkout directory}"
python3 "$recipe_dir/prepare_rtwcore.py" "$source_dir"
cd "$source_dir"
mkdir -p build/experimental-rtwcore
excludes=$(python3 - <<'PY'
from pathlib import Path
base=Path('rtw/hal_rtw89')
print(' '.join(sorted({p.name for folder in ('driver','compat') for p in (base/folder).glob('*.c')})))
PY
)
xcodebuild -project AirportRTW.xcodeproj -target RTWCore \
  -configuration Release ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  EXCLUDED_SOURCE_FILE_NAMES="$excludes" \
  'OTHER_LDFLAGS=$(inherited) $(DERIVED_FILE_DIR)/librtw89_c.a' \
  SYMROOT="$PWD/build/experimental-rtwcore/products" \
  OBJROOT="$PWD/build/experimental-rtwcore/objects" \
  2>&1 | tee build/experimental-rtwcore/build.log
kext="$PWD/build/experimental-rtwcore/products/Release/RTWCore.kext"
test -f "$kext/Contents/MacOS/RTWCore"
xcrun lipo -verify_arch x86_64 "$kext/Contents/MacOS/RTWCore"
xcrun nm -u "$kext/Contents/MacOS/RTWCore" > build/experimental-rtwcore/undefined-symbols.txt
if grep -E 'IO80211|IOSkywalk|CCPipe' build/experimental-rtwcore/undefined-symbols.txt; then
  echo 'Unexpected native wireless framework references. Do not use this build.' >&2
  exit 1
fi
echo 'Build passed architecture and framework-reference checks. Runtime remains untested.'
