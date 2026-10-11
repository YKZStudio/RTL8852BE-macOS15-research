# RTL8852BE / macOS 15.4 研究记录

这是一份静态研究结果和实验构建配方，不是已经编译、实机验证的驱动。

## 已确认

- 上传的 BootKernelExtensions.kc 是 65,978,368 字节的 x86_64 Mach-O fileset。
- 内核字符串为 Darwin 24.4.0 / xnu-11417.101.15~117，与启动日志一致。
- IO80211Family、IOSkywalkFamily 的 Mach-O 符号表可以正常读取。
- 当前 AirportRTW 2.4.0 Sonoma14.4 二进制与这份系统存在接口不匹配。
- 查到 37 个未在系统定义符号集中精确匹配的苹果 C++ 未定义引用；其中包含两个 IONetworkController 预留接口。这个计数不是“37 个必改错误”，也没有证明其余接口兼容。
- 原生无线控制器的四个 apple80211_ioctl_get/set 旧签名均未找到。
- getIO80211CommandGate、getLogger、getBSDName 等接口增加 const 修饰。
- IO80211InfraInterface::inputPacket 增加一个 bool 参数；setLinkStateInternal 删除最后的事件数据引用参数。
- IO80211Controller::postMessage 的参数表改变；FlowQueue 接口由整数参数变为 IO80211FlowQueueHash 类型。

7-Zip 的链接创建失败不妨碍本次读取这个独立文件；没有官方哈希可供比较，因此不能据此宣称整个镜像或文件已通过官方完整性验证。

## 更小的实验方向：RTWCore

固定源码：souissiak1-maker/AirportRTW，提交 91f1c8a28d39e23ae70088a4224a0f7546810bca。

该仓库已有 RTWCore 目标，RTWCore 继承 IOEthernetController，并通过 ItlRtw89 后端处理真实无线硬件。匹配函数及固件选择均包含 RTL8852BE（10EC:B852）。这不是要求使用网线：无线硬件在系统中表现为以太网形式的接口。

这个方向减少对 IO80211/Skywalk 原生无线接口的依赖，但仍需编译、检查 IONetworkingFamily 兼容性，并实机验证扫描、关联、WPA2、DHCP及恢复安装器的网络识别。Wi-Fi 菜单不会因此自动出现。

源码支持通过 Info.plist 中 RTWCore personality 的 WiFiConfig 字典配置自动连接网络。实验配方清除了上游的示例网络和密码。不要在公开仓库或构建任务里填写自己的 Wi-Fi 密码。

## 无 Mac 时进行实验构建

1. 在自己的 GitHub 仓库中保留本包的目录结构，上传 README.md、build_rtwcore.sh、prepare_rtwcore.py，以及 .github/workflows/build-rtwcore.yml。
2. 打开 Actions（工作流），选择 Experimental RTWCore build，点击 Run workflow（运行工作流）。此操作需由你自己执行；本次没有创建仓库或启动云端任务。
3. 工作流在 GitHub 的 macOS 15 Intel 环境中拉取上述固定提交并尝试编译。账户的工作流额度与费用规则以 GitHub 为准。
4. 下载 RTWCore-experimental-build 产物。即使构建失败，也会尝试保存 build.log；把日志发回可继续处理具体编译错误。
5. 构建成功不代表无线已可用。先检查产物，再设置本地网络参数并修改备用 EFI，不要直接覆盖唯一可启动的配置。

也可在有 Xcode 的 macOS 上运行：

```bash
bash build_rtwcore.sh /绝对路径/AirportRTW
```

脚本为 RTWCore 补上已有的 C 后端归档构建阶段，避免重复编译这些 C 源，并检查 x86_64 架构与是否仍引用原生无线框架。这个配方在本环境仅完成源文件修改和脚本结构检查，没有经过 Xcode 构建。

上游 tools/validate_rtw89_backend.py 在本次执行时因仍指向不存在的 itlwm.xcodeproj 而退出，未通过验证；不能引用其结果作为驱动可用证明。

## 原生 AirportRTW 移植仍需做什么

重建 macOS 15.4 对应的 IO80211/Skywalk 类声明、虚函数顺序与实例布局，调整调用点，然后用 macOS 工具链编译并检查加载、扫描、认证和数据收发。单纯替换符号字符串、删去第一个报错函数，或降低依赖版本均不足以证明正确。

研究未产生“已完成的 macOS 15 无线驱动”，也未对 NVIDIA 驱动进行二进制修改。
