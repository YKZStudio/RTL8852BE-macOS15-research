#!/bin/bash
set -euo pipefail
src=$(cd "$1" && pwd)
ogkm=$(cd "$2" && pwd)
out=$3
mkdir -p "$out/NVRMFB.kext/Contents/MacOS"
sdk=$(xcrun --sdk macosx --show-sdk-path)
khdr="$sdk/System/Library/Frameworks/Kernel.framework/Headers"
test -f "$khdr/IOKit/graphics/IOFramebuffer.h"
incs=( -I"$khdr" -I"$src/kexts/NVRMFB"
  -I"$ogkm/src/nvidia/arch/nvalloc/unix/include"
  -I"$ogkm/src/common/sdk/nvidia/inc/hw"
  -I"$ogkm/src/common/shared/inc"
  -I"$ogkm/src/nvidia/inc"
  -I"$ogkm/src/common/unix/nvidia-push/interface"
  -I"$ogkm/src/common/unix/common/utils/interface"
  -I"$ogkm/src/nvidia-modeset/kapi/include"
  -I"$ogkm/src/common/sdk/nvidia/inc"
  -I"$ogkm/src/common/inc"
  -I"$ogkm/src/common/modeset"
  -I"$ogkm/src/common/unix/common/inc"
  -I"$ogkm/src/nvidia-modeset/os-interface/include"
  -I"$ogkm/src/nvidia-modeset/kapi/interface"
  -I"$ogkm/src/nvidia-modeset/interface"
  -I"$ogkm/src/nvidia-modeset/include" )
xcrun clang++ -arch x86_64 -fapple-kext -mkernel -nostdinc "${incs[@]}" \
  -DKERNEL -DKERNEL_PRIVATE -DDRIVER_PRIVATE -DAPPLE -DNeXT \
  -std=c++17 -fno-rtti -fno-exceptions -fno-builtin -fno-common \
  -Wall -Wno-unused-parameter -Wno-inconsistent-missing-override -Wno-unused-function -O2 \
  -c "$src/kexts/NVRMFB/fb/nvrm-fb.cpp" -o "$out/nvrm-fb.o"
xcrun clang++ -arch x86_64 -fapple-kext -nostdlib -Xlinker -kext \
  -lkmodc++ -lkmod -lcc_kext "$out/nvrm-fb.o" -o "$out/NVRMFB.kext/Contents/MacOS/NVRMFB"
cp "$src/kexts/NVRMFB/fb/Info.plist" "$out/NVRMFB.kext/Contents/Info.plist"
xcrun lipo "$out/NVRMFB.kext/Contents/MacOS/NVRMFB" -verify_arch x86_64
plutil -lint "$out/NVRMFB.kext/Contents/Info.plist"
