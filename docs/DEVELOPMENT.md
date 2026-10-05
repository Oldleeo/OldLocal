# 开发、构建与发布

[← 首页](../README.md) · [贡献说明](../CONTRIBUTING.md)

## 环境

需要 Apple Silicon Mac、Xcode 或 Command Line Tools、与编译器匹配的 macOS SDK，以及 Python 3。目标为 arm64 / macOS 15，不依赖第三方 Swift 包。

本机完整构建验证：Swift 6.1.2、macOS 15.5 SDK。没有配置自动构建 CI；当前检查脚本由本机运行。

## 快速构建

```bash
git clone https://github.com/Oldleeo/OldLocal.git
cd OldLocal
bash scripts/test.sh
bash scripts/build.sh
```

如果默认 SDK 与 Swift 不兼容，可以显式指定已安装且匹配的 SDK：

```bash
SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk bash scripts/test.sh
SWIFT_SDK=/Library/Developer/CommandLineTools/SDKs/MacOSX15.5.sdk bash scripts/build.sh
```

构建默认在系统临时目录，打印生成的 `.app` 路径。避免云盘写入 Finder 元数据使严格签名检查失败。`dist/` 包含应用 ZIP 与 `SHA256SUMS`。

| 环境变量 | 用途 |
| :--- | :--- |
| `SWIFT_SDK` | 指定 SDK；默认 xcrun 的 macOS SDK。 |
| `OLDLOCAL_BUILD_DIR` | 指定本次构建目录，推荐不被云盘同步的目录。 |
| `SIGNING_IDENTITY` | 已有签名身份，默认 `-` 为 ad-hoc。 |

构建脚本签名并核验应用，不执行 Apple 公证、不安装后台组件。安装需将应用放到 `/Applications/OldLocal.app`，通过引导批准组件。

## 源码结构

```text
Sources/
  Main.swift                 主界面、状态与操作
  MapCanvas.swift            地图、选点、搜索补全
  Coordinates.swift          坐标、收藏、存储、排序
  GroupManager.swift         分组管理窗口
  GroupOperations.swift      分组数据变换
  IPLocation*.swift          IP 查询与面板
  ReleaseChannel.swift       版本比较与公开 Release 查询
  FeedbackPanel.swift        GitHub 反馈入口
  UpdatePanel.swift          版本说明与下载
  helper/                    XPC、签名校验与安装组件
  preferences/               完整精度 CFPreferences 读写
Backend/                     定位、恢复与失败回退
Resources/                   应用信息、图标与作者形象
Tests/                       非特权测试
scripts/                     检查、构建、打包、发布
docs/                        使用教程与配图
```

## 操作链

```mermaid
flowchart LR
  UI[AppKit 界面] -->|受限指令| XPC[本机 XPC 组件]
  XPC -->|身份和签名核对| Backend[定位与恢复后端]
  Backend --> CF[完整精度参数读写]
  CF --> Verify[参数读回核对]
  Verify --> Refresh[正常刷新定位服务]
  Refresh --> Result[返回结构化结果]
  Result --> UI
```

首次批准安装 root 拥有的应用副本与 launchd 定义。helper 接受安装用户且当前 console 会话的请求，固定应用路径，并限定为已批准的主程序 cdhash。指令仅为 set/reset，坐标有限且在范围内；不接收任意 shell 或路径。

定位后端修改两个 locationd domain 中的六项模拟参数。恢复核对只恢复对应的原值，保留原始备份。原始参数与服务刷新均需要核对，地图显示仍由用户验证。

## 测试范围

`scripts/test.sh` 不修改实际定位，覆盖：

- 坐标输入、边界、Unicode 和无效数值。
- 收藏保存、旧格式兼容、删除与恢复、损坏文件保留。
- 分组重命名/删除、身份与坐标保留、保留名称。
- 指令白名单、有限坐标与签名规则语法。
- 版本排序、稳定 Release、仓库下载 URL 限制、反馈 URL 编码。
- Python 后端的异常、参数回退和服务刷新逻辑（mock）。

精度跨进程测试源文件为 `Tests/PrecisionTests.swift`，不属于默认测试脚本。实际系统写入、地图当前位置、管理员弹窗及用户设备行为需要单独人工检查，不以模型测试代替。

上下排序已实机检查；拖拽手势尚未完成自动 GUI 验证。教程示例应用与正式源码共用界面，使用隔离公开数据且阻断定位执行，仅用于采图，不作为额外发行版本。

## 发布

1. 更新 `Resources/Info.plist` 的显示版本和构建号，版本为三段数字。
2. 修改 `CHANGELOG.md`，运行测试与构建。
3. 检查可解压包、执行权限和代码签名。
4. 提交并推送到 `origin/main`。
5. 运行匹配版本的发布脚本：

```bash
bash scripts/release.sh vX.Y.Z
```

脚本要求工作区干净、源码版本与包一致、SHA256 校验通过且提交与 origin/main 一致，然后上传 ZIP 与校验文件到本仓库 Releases。

更新通道使用 GitHub latest Release，只接受正式三段版本；不自动安装，不把未发布、限流或网络错误当作最新版。

## 许可

代码 MIT。保留 TimBitBox 上游许可。品牌与作者形象说明见 [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md)，不要把软件许可当作其他产品的商标或肖像授权。
