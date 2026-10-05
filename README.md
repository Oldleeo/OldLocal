# OldLocal

**Location Control for Mac — by 老李 Oldlee.**

原生 macOS 定位工具。粘贴经纬度、地图选点或选择收藏，一键应用并在结束时恢复。界面以地图为中心，使用 AppKit、MapKit 和本机 XPC 定位组件。

![OldLocal](docs/OldLocal.png)

## 下载与安装

从 [GitHub Releases](https://github.com/Oldleeo/OldLocal/releases/latest) 下载 `OldLocal-macOS-arm64.zip`，解压后将 `OldLocal.app` 拖到「应用程序」。首次打开按引导启用定位组件，系统会要求一次管理员授权；日常修改与恢复无需重复输入密码。软件更新后，组件需要重新批准一次。

当前发行包面向 **Apple Silicon、macOS 15 或更新版本**。实际定位修改在 macOS 15.7.4 测试过；其他系统版本的定位服务行为可能不同。代码使用本机系统定位模拟偏好，部分应用可能采用 IP 或自己的定位来源。

本地发行包使用 ad-hoc 签名，尚未经过 Apple 公证。若 macOS 拦截，请从系统设置的「隐私与安全性」检查并批准打开。没有要求关闭 SIP，也不要求重启 Mac。

## 功能

- 单框输入：`3.178400, 101.705500`，纬度在前，经度在后。
- 地图选点、地点搜索与自动补全、回到选点。
- 收藏备注、一键应用、明显的删除按钮与右键菜单、最近删除恢复。
- 收藏分组、重命名与删除、组内排序；删除分组保留收藏。
- IPv4 / IPv6 区域查询，或识别当前网络出口 IP（ipapi.co）。
- 每次启动引导、一次管理员批准的后台组件。
- 意见反馈、功能建议、GitHub 正式版检查与下载入口。

地图和搜索需要网络。IP 定位是区域估计，VPN/代理开启时可能对应出口位置。搜索和地图仅预览；点击「修改定位」或收藏的「应用」才会写入系统。

关闭软件不会自动恢复定位。结束时请点击「恢复原定位」；系统原始备份保存在 `/var/db/mac-location-lab/original.json`，不要删除。软件核对参数读回和服务刷新；地图显示仍需由用户检查，不能把参数成功等同于每个应用都已使用新位置。

## 意见反馈与更新

软件左下角的「意见反馈」可打开问题报告或功能建议，预填软件与系统版本。用户在 GitHub 编辑后自己提交，不自动上传坐标、收藏或诊断。Issues 是公开页面，提交前请检查附件中的个人信息。

「检查更新」访问本仓库最新正式 Release，显示版本及说明。发现新版本后可点击下载，在退出软件后手动替换应用；收藏保存在用户资料目录，更新不删除收藏。当前通道不执行自动安装。

- [报告问题 / 功能建议](https://github.com/Oldleeo/OldLocal/issues)
- [下载与更新记录](https://github.com/Oldleeo/OldLocal/releases)
- 作者：[X · @oldleeoo](https://x.com/oldleeoo) / [GitHub · Oldleeo](https://github.com/Oldleeo)

## 从源码构建

需要 Apple Silicon Mac、Xcode 或 Command Line Tools、与安装编译器兼容的 macOS SDK、Python 3。源码不依赖第三方 Swift 包。

```bash
bash scripts/test.sh
bash scripts/build.sh
```

构建默认在系统临时目录进行，输出路径会打印；可分发的 ZIP 和校验文件写入 `dist/`。临时目录能避免云盘附加 Finder 元数据破坏签名。

如编译器与默认 SDK 不兼容，可显式指定匹配 SDK：

```bash
SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk bash scripts/test.sh
SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk bash scripts/build.sh
```

已验证 Swift 6.1.2 + macOS 15.5 SDK 的完整源码构建。`SIGNING_IDENTITY` 可指定已有签名身份，默认 `-` 是 ad-hoc；脚本不执行 Apple 公证，也不安装系统组件。自行构建后需将应用放到 `/Applications/OldLocal.app`，再在软件引导中批准组件。

发布新版本：修改 `Resources/Info.plist` 中的版本和构建号，执行检查及构建，将提交推送到 main，随后运行 `bash scripts/release.sh vX.Y.Z`。脚本检查标签与源码版本、工作区、ZIP 与校验文件，并将文件发布到 GitHub Releases。

## 安全与数据

软件不保存管理员密码，不设置 sudo 免密规则、不监听网络端口。定位后台组件以 root 运行，通过 XPC 限定指令、坐标范围、当前登录用户、本机应用路径及已批准的代码签名哈希；每次重编译需更新批准。组件和后台代码副本由 root 拥有。

收藏与最近删除位于 `~/Library/Application Support/art.oldlee.maclocation/`。分组和上次输入保存在用户偏好中。发布源码不包含任何个人收藏、当前定位备份或操作日志。

普通测试覆盖坐标校验、旧收藏兼容、保存/恢复、分组数据保留、组件指令策略、失败回退、版本比较及 Release 下载地址限制，不会修改系统定位。实际定位修改测试需要在本机明确选择位置并检查地图。拖拽排序未完成自动 GUI 验证，上下移动按钮已验证。

## License

软件代码采用 [MIT](LICENSE)，Copyright © 2026 老李 Oldlee。后端基于 TimBitBox 的 MIT 项目，原许可保留，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。作者形象、Logo 及品牌另有说明，不授予用于其他产品的商标或肖像权。
