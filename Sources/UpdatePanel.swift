import AppKit

final class UpdatePanel: NSObject {
    private let alert = NSAlert()
    private let status = textLabel("正在连接 GitHub Releases…", size: 13, weight: .medium)
    private let notes = NSTextView()
    private var downloadURL: URL?
    private var closed = false
    override init() {
        super.init()
        alert.messageText = "检查 OldLocal 更新"
        alert.informativeText = "当前版本 \(ProjectChannel.version) · 正式版通道\n下载后退出 OldLocal，将新版拖到「应用程序」替换；收藏会保留。"
        alert.icon = OldLocalLogo.image(size: 72, tile: true)
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 3
        status.preferredMaxLayoutWidth = 440
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 440, height: 170))
        scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder
        notes.isEditable = false; notes.isSelectable = true
        notes.font = .systemFont(ofSize: 12)
        notes.textContainerInset = NSSize(width: 10, height: 10)
        notes.isVerticallyResizable = true; notes.isHorizontallyResizable = false
        notes.textContainer?.widthTracksTextView = true
        notes.frame = scroll.bounds; scroll.documentView = notes
        let page = NSButton(title: "查看全部版本", target: self, action: #selector(openReleases))
        page.bezelStyle = .rounded
        let stack = NSStackView(views: [status, scroll, page])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 12
        stack.frame = NSRect(x: 0, y: 0, width: 440, height: 240)
        scroll.widthAnchor.constraint(equalToConstant: 440).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 170).isActive = true
        status.widthAnchor.constraint(equalToConstant: 440).isActive = true
        alert.accessoryView = stack
        alert.addButton(withTitle: "下载新版"); alert.buttons[0].isEnabled = false
        alert.addButton(withTitle: "关闭")
    }
    func show(on window: NSWindow) {
        alert.beginSheetModal(for: window) { [self] response in
            closed = true
            if response == .alertFirstButtonReturn, let url = downloadURL { NSWorkspace.shared.open(url) }
        }
        ReleaseLookup.check { [weak self] result in
            guard let self = self, !self.closed else { return }
            switch result {
            case .success(let release):
                self.notes.string = String((release.body ?? "此版本暂无更新说明。").prefix(16000))
                guard let latest = StableVersion(release.tag_name), let current = StableVersion(ProjectChannel.version) else {
                    self.status.stringValue = "无法比较版本，请查看全部版本。"; return
                }
                if latest > current {
                    self.status.stringValue = "发现新版本 \(release.tag_name)"
                    self.status.textColor = .systemBlue
                    self.downloadURL = release.download
                    self.alert.buttons[0].isEnabled = self.downloadURL != nil
                    if self.downloadURL == nil { self.status.stringValue += "，下载包尚未上传。" }
                } else {
                    self.status.stringValue = latest == current ? "当前已是最新正式版 \(release.tag_name)" : "当前版本比已发布的正式版更新。"
                    self.status.textColor = .systemGreen
                }
            case .failure(let error):
                self.status.textColor = .systemOrange
                switch error {
                case ReleaseFailure.notPublished: self.status.stringValue = "正式版暂未发布，请稍后再检查。"
                case ReleaseFailure.rateLimited: self.status.stringValue = "GitHub 请求次数受限，请稍后重试。"
                default: self.status.stringValue = "暂时无法检查更新，请检查网络或查看全部版本。"
                }
                self.notes.string = "更新检查只访问公开版本信息，不会上传收藏、坐标或诊断记录。\n新版安装后，定位组件可能需要一次管理员批准。"
            }
        }
    }
    @objc private func openReleases() { NSWorkspace.shared.open(ProjectChannel.releases) }
}
