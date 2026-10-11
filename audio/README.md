# Senary 14F1:1F87 audio experiment

This is an unqualified ID-match prototype for Redmi G 2022 / TIMI TM2135,
macOS 15.8.1, codec 14F1:1F87 revision 0x100100, Intel controller 8086:51C8.

It adds a separate codec resource to pinned upstream AppleALC 1.9.8.
Original CX8070 support is retained. It adapts the AppleHDA codec patch,
both layout CodecID values and pin configurations for layouts 15 and 21.
Routing and initialization verbs are borrowed from CX8070 laptop profiles.
A passing build is not proof of working speakers, microphone or wake.

## Test (Chinese)
1. 备份实际启动 EFI，保留另一套能启动的外置 EFI。
2. 解压内部的 AppleALC-Senary1F87-experimental.zip。
3. 将实际启动 EFI/OC/Kexts/AppleALC.kext 整个文件夹替换为实验版。
   原版移到 EFI 之外；不要同时加载两个 AppleALC，也不要新增重复 Kernel/Add 条目。
4. 首次保留 alcid=15，不改 NVIDIA、无线、ACPI 或其他启动参数。
5. 重启，检查 system_profiler SPAudioDataType。
6. 若出现输出设备，以低音量测试扬声器及耳机。先不测试睡眠唤醒。
7. 若无设备，收集 HDEF 设备树和 AppleALC debug 日志，再考虑布局21。
8. 失败时从备用 EFI 启动，将原版 AppleALC.kext 放回原位置。

Do not replace the NVIDIA driver or AppleHDA system files.
No automatic install, disk partition changes, or telemetry is included.
