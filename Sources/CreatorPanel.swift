import AppKit

final class CreatorPanel {
    static let xURL = URL(string: "https://x.com/oldleeoo")!
    static let githubURL = URL(string: "https://github.com/Oldleeo")!
    private let alert = NSAlert()
    func show(on window: NSWindow) {
        alert.messageText = "OldLocal · 老李 Oldlee"
        alert.informativeText = "Copyright © 2026 老李 Oldlee\nLocation Control for Mac · \(ProjectChannel.version)"
        alert.icon = OldLocalLogo.image(size: 72, tile: true)
        let links = NSStackView()
        links.orientation = .horizontal
        links.spacing = 12
        let x = NSButton(title: "X · @oldleeoo", target: self, action: #selector(openX))
        let github = NSButton(title: "GitHub · Oldleeo", target: self, action: #selector(openGitHub))
        x.bezelStyle = .rounded; github.bezelStyle = .rounded
        x.toolTip = Self.xURL.absoluteString; github.toolTip = Self.githubURL.absoluteString
        links.addArrangedSubview(x); links.addArrangedSubview(github)
        let profile = NSStackView()
        profile.orientation = .horizontal; profile.spacing = 18
        if let url = Bundle.main.url(forResource: "OldleePortrait", withExtension: "png"), let image = NSImage(contentsOf: url) {
            let portrait = NSImageView(image: image)
            portrait.imageScaling = .scaleProportionallyUpOrDown
            portrait.setAccessibilityLabel("老李 Oldlee IP 形象")
            portrait.widthAnchor.constraint(equalToConstant: 84).isActive = true
            portrait.heightAnchor.constraint(equalToConstant: 100).isActive = true
            profile.addArrangedSubview(portrait)
        }
        let name = textLabel("老李 Oldlee", size: 20, weight: .semibold)
        let subtitle = textLabel("个人主页与作品", size: 12, color: .secondaryLabelColor)
        let words = NSStackView(views: [name, subtitle])
        words.orientation = .vertical; words.alignment = .leading; words.spacing = 6
        profile.addArrangedSubview(words)
        let stack = NSStackView(views: [profile, links])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        stack.frame = NSRect(x: 0, y: 0, width: 340, height: 155)
        alert.accessoryView = stack
        alert.addButton(withTitle: "关闭")
        alert.beginSheetModal(for: window) { [self] _ in _ = self }
    }
    @objc private func openX() { NSWorkspace.shared.open(Self.xURL) }
    @objc private func openGitHub() { NSWorkspace.shared.open(Self.githubURL) }
}
