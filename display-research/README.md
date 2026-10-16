# NVRMFB 2.0.4 HiDPI source-cap experiment

Target: RTX 3050 Laptop, macOS 15.8.1, internal 2560x1600 panel.
The observed stock driver reserves 16,000 KB and publishes a 2560x1600 scaler ceiling.
1280x800 HiDPI works; 1600x1000 and larger HiDPI desktop sizes are unavailable.

This is a private testing recipe, not an upstream contribution or a hardware-qualified fix.
Upstream source: nullmoth/nvidia-macos-driver b737dedc11fa4edbcb4abe8d51e94cebfed21ac6 (2.0.4).
NVIDIA headers: NVIDIA/open-gpu-kernel-modules e4a5faa2567f28c8eabe0ebb6422b6d0abcf37eb (610.57.04).

With `nvfbhidpi=1` AND boot panel dimensions 2560x1600, reserve a source surface up to
3840x2400 (enough for 1600x1000 and 1680x1050 HiDPI). Keep the physical raster width
ceiling at the stock value. Existing NVKMS timing checks, memory checks and allocation
fallback remain. Without the argument, source behavior is unchanged.

The build compiles stock and patched framebuffer code with the same toolchain and
checks that undefined-symbol sets match. That is not a substitute for kmutil validation
against the installed kernel collections or a real boot. Source and external ABI headers
are not changed. The artifact contains only NVRMFB, not NVRM, NVAccel or the Metal plugin.

## 安装边界

当前配方不自动安装。必须先核对 2.0.4、备份原版 NVRMFB 和实际启动 EFI，并保留恢复入口。
NVRMFB 安装位置是 /Library/Extensions/NVRMFB.kext，不能放进 EFI 注入。
应先通过本机 kmutil 的测试构建，再替换、重建辅助内核集合，随后重启。
先测试 60 Hz 下的 1600x1000 HiDPI，再测试 165 Hz。不要同时改颜色配置或其他驱动。
失败时用备用 EFI / -nvoff 启动并恢复原版。移除 nvfbhidpi=1 可停用本实验的容量变化。

A successful cloud build proves compilation and package structure only. The display may
still reject the scaled commit or exhibit cursor, flicker, wake or performance problems.
