# NVRMFB 2.0.4 HiDPI source-cap and explicit 60 Hz experiments

Target: RTX 3050 Laptop, macOS 15.8.1, internal 2560x1600 panel.
The observed stock driver reserves 16,000 KB and publishes a 2560x1600 scaler ceiling.
1280x800 HiDPI works; 1600x1000 and larger HiDPI desktop sizes are unavailable.

本机后续测试：扩大容量后，3414x2134 和 3840x2400 渲染尺寸可以送到驱动，
但搭配原生 165 Hz 输出时，NVKMS 的 test 返回 false，没有进入 COMMIT。
当前只能确认模式被拒绝，不能据此认定 165 Hz 就是原因。

新增 `nvfbhidpi60=1`（同时保留 `nvfbhidpi=1`）：仅对内置 2560x1600 启动屏幕，
从 NVKMS 有效模式中选择原生约 60 Hz 时序，额外发布四个缩放桌面：
3200x2000、3360x2100、3414x2134、3840x2400，对应 HiDPI 逻辑尺寸
1600x1000、1680x1050、1707x1067、1920x1200。
不生成新的面板时序、不覆盖原有 165 Hz 模式、不跳过 NVKMS 测试和提交检查。
如果没有有效原生 60 Hz 时序或容量不足，则不添加对应模式。

安装：解压产物及其中的驱动 ZIP，让 NVRMFB.kext、PAYLOAD-SHA256.txt、
check_framebuffer.sh、install_framebuffer.sh 处于同一目录。终端进入该目录后运行：

```bash
sudo /bin/bash ./install_framebuffer.sh --install
```

看到 INSTALL OK 后，在实际启动 EFI 的 boot-args 中保留 `nvfbhidpi=1`，
添加 `nvfbhidpi60=1`，重启。选择标注 60 Hz 的 1707x1067 HiDPI 模式。
本次只验证能否发布并切换 60 Hz 缩放模式，尚未通过真实硬件测试。

日志：

```bash
sudo log show --last boot --style compact --predicate 'process == "kernel"' | grep -Ei 'HiDPI60 experiment:|setDisplayMode|switchMode' | tail -n 60
```

预期新增日志为 `HiDPI60 experiment: desktop 3414x2134 ... @60000 mHz`（刷新率可能略有偏差）。
切换日志必须同时出现该渲染尺寸、约 60000 mHz 和 COMMIT 成功，才能算生效。
仅出现模式条目或 test 成功不能证明最终切换成功。
移除 `nvfbhidpi60=1` 停用新增的 60 Hz 模式；安装器会备份旧驱动和辅助内核集合并支持恢复。

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

安装脚本限定 2.0.4，会先测试构建并备份现有 NVRMFB 和辅助内核集合；实际启动 EFI 需自行备份。
NVRMFB 安装位置是 /Library/Extensions/NVRMFB.kext，不能放进 EFI 注入。
应先通过本机 kmutil 的测试构建，再替换、重建辅助内核集合，随后重启。
先测试 60 Hz 下的 1600x1000 HiDPI，再测试 165 Hz。不要同时改颜色配置或其他驱动。
失败时用备用 EFI / -nvoff 启动并恢复原版。移除 nvfbhidpi=1 可停用本实验的容量变化。

A successful cloud build proves compilation and package structure only. The display may
still reject the scaled commit or exhibit cursor, flicker, wake or performance problems.
