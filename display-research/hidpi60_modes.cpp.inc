    // Opt-in diagnostic: offer explicit 60 Hz scaled desktops using the panel's
    // own validated timing. Keep the existing 165 Hz entries and validation path.
    UInt32 hidpiCaps = 0, hidpi60 = 0;
    PE_parse_boot_argn("nvfbhidpi", &hidpiCaps, sizeof hidpiCaps);
    PE_parse_boot_argn("nvfbhidpi60", &hidpi60, sizeof hidpi60);
    if (hidpiCaps == 1 && hidpi60 == 1 && fInternal && fBootW == 2560 && fBootH == 1600) {
        struct NvKmsKapiDisplayMode sixty = {}; bool found60 = false;
        for (NvU32 i = 0; i < 256; i++) {
            struct NvKmsKapiDisplayMode m = {}; NvBool valid = NV_FALSE, pref = NV_FALSE;
            const int r = fKms->getDisplayMode(fDev, fDisplay, i, &m, &valid, &pref);
            if (r < 0) break;
            if (r == 0 || !valid) continue;
            const struct NvKmsKapiDisplayModeTimings &k = m.timings;
            if (k.hVisible != 2560 || k.vVisible != 1600 || k.flags.interlaced || k.flags.doubleScan ||
                !k.pixelClockHz || k.hTotal <= k.hVisible || k.vTotal <= k.vVisible ||
                k.hSyncStart < k.hVisible || k.hSyncEnd < k.hSyncStart ||
                k.vSyncStart < k.vVisible || k.vSyncEnd < k.vSyncStart) continue;
            const NvU64 total = (NvU64)k.hTotal * k.vTotal;
            const NvU64 rate = ((NvU64)k.pixelClockHz * 1000 + total / 2) / total;
            if (rate < 59500 || rate > 60500) continue;
            sixty = m; found60 = true; break;
        }
        if (found60) {
            const struct NvKmsKapiDisplayModeTimings &k = sixty.timings;
            const NvU32 desktops[][2] = {{3200, 2000}, {3360, 2100}, {3414, 2134}, {3840, 2400}};
            for (unsigned t = 0; t < sizeof desktops / sizeof desktops[0] && n < cap; t++) {
                const NvU32 sw = desktops[t][0], sh = desktops[t][1];
                NvU32 pitch = 0;
                if (sw > fScalerMaxW || sh > fScalerMaxH ||
                    !nvrmCheckedPitch(sw, fPitchAlign, &pitch) || (NvU64)pitch * sh > fMemBytes) continue;
                IODetailedTimingInformationV2 b; nvu_zero(&b, sizeof b);
                b.signalConfig = kIODigitalSignal;
                b.pixelClock = b.minPixelClock = b.maxPixelClock = k.pixelClockHz;
                b.horizontalActive = k.hVisible; b.verticalActive = k.vVisible;
                b.horizontalBlanking = k.hTotal - k.hVisible;
                b.horizontalSyncOffset = k.hSyncStart - k.hVisible;
                b.horizontalSyncPulseWidth = k.hSyncEnd - k.hSyncStart;
                b.verticalBlanking = k.vTotal - k.vVisible;
                b.verticalSyncOffset = k.vSyncStart - k.vVisible;
                b.verticalSyncPulseWidth = k.vSyncEnd - k.vSyncStart;
                b.horizontalSyncConfig = k.flags.hSyncPos ? 1 : 0;
                b.verticalSyncConfig = k.flags.vSyncPos ? 1 : 0;
                b.horizontalScaled = sw; b.verticalScaled = sh;
                b.scalerFlags = kIOScaleStretchToFit;
                // 0x10000..0x1ff00 are the stock NVKMS entries; macOS uses 0x80000000+.
                b.detailedTimingModeID = 0x20000u | t;
                bool duplicate = false;
                for (unsigned j = 0; j < n; j++) {
                    const IODetailedTimingInformationV2 &d = fDT[j];
                    if (d.horizontalScaled == sw && d.verticalScaled == sh &&
                        d.horizontalActive == k.hVisible && d.verticalActive == k.vVisible &&
                        d.pixelClock == k.pixelClockHz &&
                        d.horizontalActive + d.horizontalBlanking == k.hTotal &&
                        d.verticalActive + d.verticalBlanking == k.vTotal) { duplicate = true; break; }
                }
                if (duplicate) continue;
                fDT[n++] = b;
                FBLOG("HiDPI60 experiment: desktop %ux%u -> raster %ux%u @%u mHz pclk %u as dt 0x%x",
                      sw, sh, k.hVisible, k.vVisible, k.refreshRate, k.pixelClockHz, b.detailedTimingModeID);
            }
        } else FBLOG("HiDPI60 experiment: no validated native 60 Hz timing; no modes added");
    }
