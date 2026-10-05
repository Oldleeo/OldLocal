import AppKit

final class IPLocationPanel: NSObject {
    private let alert = NSAlert()
    private let input = NSTextField(string: "")
    private let status = textLabel("输入 IP，或直接查询当前网络出口。", size: 12)
    private var queryButton: NSButton!
    private var ownButton: NSButton!
    private var result: IPLocation?
    private var closed = false
    private var requestID = UUID()
    private let onSelect: (IPLocation) -> Void
    init(onSelect: @escaping (IPLocation) -> Void) {
        self.onSelect = onSelect
        super.init()
        alert.messageText = "根据 IP 识别位置"
        alert.informativeText = "通过 ipapi.co 查询 IP 的区域估计位置。\nVPN 或代理开启时，结果可能对应网络出口。"
        input.placeholderString = "IPv4 / IPv6，例如 8.8.8.8"
        input.setAccessibilityLabel("要查询的 IP")
        input.target = self; input.action = #selector(querySpecified)
        input.cell?.sendsActionOnEndEditing = false
        queryButton = NSButton(title: "查询此 IP", target: self, action: #selector(querySpecified))
        ownButton = NSButton(title: "识别当前出口 IP", target: self, action: #selector(queryOwn))
        queryButton.bezelStyle = .rounded; ownButton.bezelStyle = .rounded
        let buttons = NSStackView(views: [queryButton, ownButton])
        buttons.orientation = .horizontal; buttons.spacing = 10
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 5; status.preferredMaxLayoutWidth = 410
        let stack = NSStackView(views: [input, buttons, status])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.frame = NSRect(x: 0, y: 0, width: 410, height: 165)
        input.widthAnchor.constraint(equalToConstant: 410).isActive = true
        status.widthAnchor.constraint(equalToConstant: 410).isActive = true
        alert.accessoryView = stack
        alert.addButton(withTitle: "使用此坐标")
        alert.buttons[0].isEnabled = false
        alert.addButton(withTitle: "取消")
    }
    func show(on window: NSWindow) {
        alert.beginSheetModal(for: window) { [self] response in
            closed = true; requestID = UUID()
            if response == .alertFirstButtonReturn, let result = result { onSelect(result) }
        }
    }
    @objc private func querySpecified() {
        guard !input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            status.stringValue = "请输入 IP 地址，或点击识别当前出口 IP。"; return
        }
        query(input.stringValue)
    }
    @objc private func queryOwn() { query(nil) }
    private func query(_ ip: String?) {
        requestID = UUID(); let id = requestID
        result = nil; alert.buttons[0].isEnabled = false
        queryButton.isEnabled = false; ownButton.isEnabled = false
        status.stringValue = "正在查询…"
        IPLookup.query(ip: ip) { [weak self] response in
            guard let self = self, !self.closed, self.requestID == id else { return }
            self.queryButton.isEnabled = true; self.ownButton.isEnabled = true
            switch response {
            case .success(let location):
                self.result = location
                self.status.stringValue = "IP：\(location.ip)\n\(location.place)\n\(location.coordinates.text)\n这是 IP 区域估计；使用坐标后仍需点击修改定位。"
                self.alert.buttons[0].isEnabled = true
            case .failure(let error):
                if case IPLookupFailure.invalidIP = error { self.status.stringValue = "请输入有效 IPv4 或 IPv6 地址。" }
                else if case IPLookupFailure.rateLimited = error { self.status.stringValue = "查询频率受限，请稍后重试。" }
                else { self.status.stringValue = "暂时无法识别此 IP，请检查网络或更换 IP。" }
            }
        }
    }
}
