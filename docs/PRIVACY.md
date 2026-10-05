# 隐私与本机数据

[← 首页](../README.md) · [使用教程](USER_GUIDE.md)

## 什么保存在 Mac 上？

| 数据 | 位置与说明 |
| :--- | :--- |
| 收藏和最近删除 | `~/Library/Application Support/art.oldlee.maclocation/` 的 JSON 文件。包含备注、坐标和分组。 |
| 分组、上次输入 | 应用的用户偏好。 |
| 原定位模拟参数备份 | `/var/db/mac-location-lab/original.json`，系统权限保护；恢复需要它。 |
| 特权组件与受保护应用副本 | `/Library/PrivilegedHelperTools/art.oldlee.oldlocal/`。 |
| launchd 服务定义 | `/Library/LaunchDaemons/art.oldlee.oldlocal.helper.plist`。 |

卸载组件保留收藏和备份。退出应用不会自动恢复系统参数。

## 什么时候访问网络？

| 功能 | 目标 | 信息 |
| :--- | :--- | :--- |
| 地图、搜索与补全 | Apple MapKit | 地图区域、搜索内容等由地图框架处理。 |
| 指定 IP 查询 | ipapi.co | 输入的 IP，通过 HTTPS 请求查询其区域。 |
| 当前出口查询 | ipapi.co | 用户点击后发送请求，服务能识别连接出口。 |
| 检查更新 | GitHub API | 公开 Release 信息请求，User-Agent 含应用版本，不附带收藏或坐标。 |
| 反馈 | GitHub Issues | 浏览器打开预填版本、系统信息的问题或建议模板，用户自行提交。 |

这些服务有自己的隐私政策和条款。没有网络时，在线功能可能不可用，已保存的收藏仍在本机。

## 管理员密码与组件权限

软件通过 macOS 管理员弹窗批准组件安装或更新，不读取、不保存密码，不设置 sudo 免密规则。

root 组件通过 XPC 接收受限的修改、恢复命令；检查坐标范围、安装用户、当前登录会话、应用路径及已批准的代码签名哈希。组件不监听 TCP 网络端口。

软件重新编译或更新后，签名哈希变化，需要更新组件批准。移除组件走同一系统管理员授权方式。更多结构见 [开发说明](DEVELOPMENT.md)。

## 公开反馈时注意什么？

Issues 是公开的，任何手动写入的坐标、上传的截图或诊断，都可能被他人查看。软件的反馈入口不自动附加这些文件。发布仓库和教程使用公开地标示例，不包含用户个人收藏或当前定位备份。
