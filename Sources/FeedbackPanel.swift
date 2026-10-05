import AppKit

final class FeedbackPanel: NSObject {
    private let alert = NSAlert()
    override init() {
        super.init()
        alert.messageText = "帮助 OldLocal 变得更好"
        alert.informativeText = "向老李 Oldlee 反馈问题，或提出功能建议。\n会在浏览器打开 GitHub，编辑后由你提交。"
        alert.icon = OldLocalLogo.image(size: 72, tile: true)
        let problem = NSButton(title: "报告问题", target: self, action: #selector(reportProblem))
        let feature = NSButton(title: "功能建议", target: self, action: #selector(suggestFeature))
        let existing = NSButton(title: "查看已有反馈", target: self, action: #selector(openIssues))
        for button in [problem, feature, existing] { button.bezelStyle = .rounded }
        let row = NSStackView(views: [problem, feature, existing]); row.spacing = 12
        let privacy = textLabel("预填版本与系统信息；不附带坐标、收藏或诊断记录。\nGitHub Issues 公开可见，请检查文字与附件后再提交。", size: 11, color: .secondaryLabelColor)
        privacy.maximumNumberOfLines = 3; privacy.lineBreakMode = .byWordWrapping
        privacy.preferredMaxLayoutWidth = 410
        let stack = NSStackView(views: [row, privacy])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.frame = NSRect(x: 0, y: 0, width: 410, height: 90)
        alert.accessoryView = stack
        alert.addButton(withTitle: "关闭")
    }
    func show(on window: NSWindow) { alert.beginSheetModal(for: window) { [self] _ in _ = self } }
    @objc private func reportProblem() { NSWorkspace.shared.open(ProjectChannel.feedbackURL(feature: false)) }
    @objc private func suggestFeature() { NSWorkspace.shared.open(ProjectChannel.feedbackURL(feature: true)) }
    @objc private func openIssues() { NSWorkspace.shared.open(ProjectChannel.issues) }
}
