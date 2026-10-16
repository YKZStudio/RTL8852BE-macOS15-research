#!/usr/bin/env python3
"""Prepare an opt-in, 2560x1600-only NVRMFB scaling experiment."""
from pathlib import Path
import difflib
import sys

root = Path(sys.argv[1])
path = root / "kexts/NVRMFB/fb/nvrm-fb.cpp"
source = path.read_text()
old = """    fScalerMaxW = mw; fScalerMaxH = mh; fRasterMaxW = mw;
    const NvU64 mp_ = ((NvU64)mw * 4 + pitchAlign - 1) & ~((NvU64)pitchAlign - 1);"""
new = """    const NvU32 rasterMaxW = mw;
    // Test only: reserve a larger source surface without advertising a larger panel raster.
    // Keep the stock caps unless explicitly enabled on the observed 2560x1600 boot mode.
    UInt32 hidpiTest = 0;
    PE_parse_boot_argn("nvfbhidpi", &hidpiTest, sizeof hidpiTest);
    if (hidpiTest == 1 && fBootW == 2560 && fBootH == 1600) {
        if (mw < 3840) mw = 3840;
        if (mh < 2400) mh = 2400;
        FBLOG("HiDPI experiment: source ceiling %ux%u, physical raster width ceiling %u", mw, mh, rasterMaxW);
    }
    fScalerMaxW = mw; fScalerMaxH = mh; fRasterMaxW = rasterMaxW;
    const NvU64 mp_ = ((NvU64)mw * 4 + pitchAlign - 1) & ~((NvU64)pitchAlign - 1);"""
assert source.count(old) == 1, "Pinned source changed; refusing an ambiguous patch"
patched = source.replace(old, new)
guard_old = "        bool onScanout = p && fPhys  && fSize     && p < (fPhys + fSize)         && (p + want) > fPhys;"
guard_new = """        const NvU64 scanoutBytes = fMemBytes ? fMemBytes : fSize;
        bool onScanout = p && fPhys && scanoutBytes && p < (fPhys + scanoutBytes) && (p + want) > fPhys;"""
end_old = "const NvU64 rEnd = onScanout ? fPhys + fSize : fConsPhys + fConsSize;"
end_new = "const NvU64 rEnd = onScanout ? fPhys + scanoutBytes : fConsPhys + fConsSize;"
assert patched.count(guard_old) == 1 and patched.count(end_old) == 1
patched = patched.replace(guard_old, guard_new).replace(end_old, end_new)
mode_anchor = '    setProperty("NVRMRefreshModesAdded", (unsigned long long)added, 32);'
assert patched.count(mode_anchor) == 1, "Refresh-mode insertion point changed"
mode_code = (Path(__file__).parent / "hidpi60_modes.cpp.inc").read_text()
patched = patched.replace(mode_anchor, mode_code + mode_anchor)
path.write_text(patched)
patch = "".join(difflib.unified_diff(source.splitlines(True), patched.splitlines(True),
    fromfile="a/kexts/NVRMFB/fb/nvrm-fb.cpp", tofile="b/kexts/NVRMFB/fb/nvrm-fb.cpp"))
Path("NVRMFB-hidpi.patch").write_text(patch)
print("Prepared opt-in source cap and explicit 60 Hz mode experiments; mode validation retained")
