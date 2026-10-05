import AppKit

func textLabel(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
    let field = NSTextField(labelWithString: text)
    field.font = .systemFont(ofSize: size, weight: weight)
    field.textColor = color
    return field
}

final class ActionButton: NSButton {
    private let primary: Bool
    init(_ title: String, symbol: String? = nil, primary: Bool = false, target: AnyObject?, action: Selector?) {
        self.primary = primary
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.font = .systemFont(ofSize: 13, weight: .medium)
        self.wantsLayer = true
        self.layer?.cornerRadius = 9
        self.setButtonType(.momentaryPushIn)
        if let symbol = symbol, title.isEmpty {
            self.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            self.imagePosition = .imageLeft
        }
        restyle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isEnabled: Bool { didSet { alphaValue = isEnabled ? 1 : 0.42 } }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); restyle() }
    private func restyle() {
        let foreground: NSColor = primary ? .white : .labelColor
        self.attributedTitle = NSAttributedString(string: title, attributes: [.font: font!, .foregroundColor: foreground])
        self.contentTintColor = foreground
        layer?.backgroundColor = (primary ? NSColor.systemBlue : NSColor.labelColor.withAlphaComponent(0.065)).cgColor
    }
}

final class FavoriteCell: NSTableCellView {
    private let card = NSView()
    private let titleField = textLabel("", size: 13, weight: .semibold)
    private let coordinateField = textLabel("", size: 11, color: .secondaryLabelColor)
    private let groupField = textLabel("", size: 10.5, color: .secondaryLabelColor)
    private var applyButton: NSButton!
    private var trashButton: NSButton!
    var onApply: (() -> Void)?
    var onDelete: (() -> Void)?
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        card.wantsLayer = true; card.layer?.cornerRadius = 11; card.layer?.borderWidth = 0.75
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            card.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
        titleField.lineBreakMode = .byTruncatingTail
        coordinateField.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        trashButton = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "删除收藏")!, target: self, action: #selector(deleteItem))
        trashButton.isBordered = false; trashButton.toolTip = "删除收藏（可恢复）"
        trashButton.setAccessibilityLabel("删除此收藏")
        trashButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let top = NSStackView(views: [titleField, trashButton])
        top.orientation = .horizontal; top.distribution = .fill; top.spacing = 8
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        applyButton = ActionButton("应用", primary: true, target: self, action: #selector(applyItem))
        applyButton.setAccessibilityLabel("一键应用此收藏")
        applyButton.widthAnchor.constraint(equalToConstant: 54).isActive = true
        applyButton.heightAnchor.constraint(equalToConstant: 25).isActive = true
        groupField.lineBreakMode = .byTruncatingTail
        groupField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let bottom = NSStackView(views: [groupField, applyButton])
        bottom.orientation = .horizontal; bottom.distribution = .fill; bottom.spacing = 8
        let stack = NSStackView(views: [top, coordinateField, bottom])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            top.widthAnchor.constraint(equalTo: stack.widthAnchor),
            bottom.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        self.textField = titleField
        restyle()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(_ favorite: Favorite, ready: Bool, editable: Bool) {
        titleField.stringValue = favorite.note
        coordinateField.stringValue = favorite.coordinates.text
        groupField.stringValue = "▱ " + favorite.group
        toolTip = favorite.note + "\n" + favorite.coordinates.text + "\n拖动可排序"
        applyButton.isEnabled = ready; trashButton.isEnabled = editable
        applyButton.toolTip = ready ? "立即修改定位为这个收藏的位置" : "请先启用定位组件"
    }
    @objc private func applyItem() { onApply?() }
    @objc private func deleteItem() { onDelete?() }
    override var backgroundStyle: NSView.BackgroundStyle { didSet { restyle() } }
    private func restyle() {
        let selected = backgroundStyle == .emphasized
        card.layer?.backgroundColor = (selected ? NSColor.systemBlue.withAlphaComponent(0.10) : NSColor.white.withAlphaComponent(0.72)).cgColor
        card.layer?.borderColor = (selected ? NSColor.systemBlue.withAlphaComponent(0.32) : NSColor.black.withAlphaComponent(0.055)).cgColor
        for field in [titleField, coordinateField, groupField] { field.cell?.backgroundStyle = .normal }
        trashButton?.cell?.backgroundStyle = .normal
        trashButton?.contentTintColor = .secondaryLabelColor
        titleField.textColor = selected ? .systemBlue : .labelColor
        coordinateField.textColor = NSColor(calibratedWhite: 0.43, alpha: 1)
        groupField.textColor = NSColor(calibratedWhite: 0.43, alpha: 1)
    }
}

final class FavoriteRow: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {}
}

final class MapToolButton: NSButton {
    private let symbol: NSImage
    init(_ title: String, symbol: String, target: AnyObject?, action: Selector?) {
        self.symbol = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)!
        super.init(frame: .zero)
        self.title = title; self.target = target; self.action = action
        isBordered = false; setButtonType(.momentaryPushIn)
        wantsLayer = true
        layer?.backgroundColor = NSColor.white.cgColor
        layer?.cornerRadius = 11
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.23).cgColor
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.18
        layer?.shadowRadius = 9
        layer?.shadowOffset = NSSize(width: 0, height: -2)
        setAccessibilityLabel(title)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isEnabled: Bool { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let color: NSColor = isEnabled ? .systemBlue : .secondaryLabelColor
        let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: color])
        let size = text.size()
        let x = (bounds.width - size.width - 25) / 2
        let tinted = NSImage(size: NSSize(width: 17, height: 17), flipped: false) { [symbol] rect in
            symbol.draw(in: rect)
            color.setFill(); rect.fill(using: .sourceIn)
            return true
        }
        tinted.draw(in: NSRect(x: x, y: (bounds.height - 17)/2, width: 17, height: 17))
        text.draw(at: NSPoint(x: x + 25, y: (bounds.height - size.height)/2))
    }
}
