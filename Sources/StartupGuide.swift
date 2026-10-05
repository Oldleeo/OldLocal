import AppKit

final class StartupGuide {
    private let alert = NSAlert()
    private let componentStatus = textLabel("正在检查定位组件…", size: 12, weight: .medium)
    private var ready = false
    private let onEnable: () -> Void
    init(onEnable: @escaping () -> Void) {
        self.onEnable = onEnable
        alert.messageText = "欢迎使用 OldLocal"
        alert.informativeText = "开始前，花几秒确认这三个步骤。"
        alert.icon = OldLocalLogo.image(size: 72, tile: true)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 19
        let steps = [
            ("1  启用定位组件", "首次启用需管理员授权。日常修改和恢复无需重复输入密码。"),
            ("2  选择你的落点", "地图选点、搜索补全或 IP 识别。收藏支持分组排序，点击卡片应用即可切换。"),
            ("3  应用，再手动恢复", "点击「修改定位」生效。结束时点击「恢复原定位」；关闭软件不会自动恢复。")
        ]
        for (title, detail) in steps {
            let heading = textLabel(title, size: 13, weight: .semibold)
            let description = textLabel(detail, size: 12, color: .secondaryLabelColor)
            description.lineBreakMode = .byWordWrapping
            description.maximumNumberOfLines = 3
            description.preferredMaxLayoutWidth = 390
            let group = NSStackView(views: [heading, description])
            group.orientation = .vertical
            group.alignment = .leading
            group.spacing = 6
            stack.addArrangedSubview(group)
            description.widthAnchor.constraint(equalToConstant: 390).isActive = true
        }
        stack.addArrangedSubview(componentStatus)
        let update = textLabel("软件更新后，可能需要重新批准定位组件。", size: 10.5, color: .secondaryLabelColor)
        stack.addArrangedSubview(update)
        stack.frame = NSRect(x: 0, y: 0, width: 390, height: 265)
        alert.accessoryView = stack
        alert.addButton(withTitle: "正在检查…")
        alert.buttons[0].isEnabled = false
        alert.addButton(withTitle: "先查看地图")
    }
    func update(ready: Bool) {
        self.ready = ready
        componentStatus.stringValue = ready ? "● 定位组件已就绪，可直接使用" : "● 需要首次启用或更新定位组件"
        componentStatus.textColor = ready ? .systemGreen : .systemOrange
        alert.buttons[0].title = ready ? "进入 OldLocal" : "启用定位组件"
        alert.buttons[0].isEnabled = true
    }
    func show(on window: NSWindow, completion: @escaping () -> Void) {
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            completion()
            if response == .alertFirstButtonReturn && !self.ready { self.onEnable() }
        }
    }
}
