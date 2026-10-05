import AppKit

final class GroupManager: NSObject, NSWindowDelegate {
    private let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 490, height: 335), styleMask: [.titled, .closable], backing: .buffered, defer: false)
    private let picker = NSPopUpButton()
    private let input = NSTextField(string: "")
    private let info = textLabel("", size: 12, color: .secondaryLabelColor)
    private let status = textLabel("删除分组会把收藏移到未分组，保留所有位置。", size: 11, color: .secondaryLabelColor)
    private var renameButton: NSButton!
    private var deleteButton: NSButton!
    private var undoButton: NSButton!
    private let names: () -> [String]
    private let count: (String) -> Int
    private let rename: (String, String) throws -> Void
    private let remove: (String) throws -> Void
    private let undo: () throws -> Void
    private let canUndo: () -> Bool
    private let completion: () -> Void
    init(names: @escaping () -> [String], count: @escaping (String) -> Int, rename: @escaping (String, String) throws -> Void,
         remove: @escaping (String) throws -> Void, undo: @escaping () throws -> Void, canUndo: @escaping () -> Bool, completion: @escaping () -> Void) {
        self.names = names; self.count = count; self.rename = rename; self.remove = remove
        self.undo = undo; self.canUndo = canUndo; self.completion = completion
        super.init()
        panel.title = "管理收藏分组"; panel.isReleasedWhenClosed = false; panel.delegate = self
        let stack = NSStackView()
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false; panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 22)
        ])
        stack.addArrangedSubview(textLabel("重命名或删除分组", size: 19, weight: .semibold))
        picker.setAccessibilityLabel("要管理的收藏分组"); picker.target = self; picker.action = #selector(selectGroup)
        stack.addArrangedSubview(picker); picker.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.addArrangedSubview(info)
        input.placeholderString = "输入分组新名称"; input.setAccessibilityLabel("分组新名称")
        input.cell?.sendsActionOnEndEditing = false
        stack.addArrangedSubview(input); input.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        renameButton = NSButton(title: "重命名", target: self, action: #selector(renameGroup))
        deleteButton = NSButton(title: "删除分组", target: self, action: #selector(deleteGroup))
        undoButton = NSButton(title: "撤销此操作", target: self, action: #selector(undoGroup))
        for button in [renameButton!, deleteButton!, undoButton!] { button.bezelStyle = .rounded }
        let row = NSStackView(views: [renameButton, deleteButton, undoButton]); row.spacing = 8
        stack.addArrangedSubview(row)
        status.lineBreakMode = .byWordWrapping; status.maximumNumberOfLines = 2; status.preferredMaxLayoutWidth = 442
        stack.addArrangedSubview(status); status.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let close = NSButton(title: "完成", target: self, action: #selector(finish)); close.bezelStyle = .rounded
        stack.addArrangedSubview(close)
        reload(selected: names().first(where: { $0 != "未分组" }) ?? "未分组")
    }
    func show(on parent: NSWindow) { parent.beginSheet(panel) }
    private func reload(selected: String) {
        picker.removeAllItems(); picker.addItems(withTitles: names()); picker.selectItem(withTitle: selected)
        if picker.indexOfSelectedItem < 0 { picker.selectItem(at: 0) }
        selectGroup(); undoButton.isEnabled = canUndo()
    }
    @objc private func selectGroup() {
        let name = picker.titleOfSelectedItem ?? "未分组"
        input.stringValue = name
        let editable = name != "未分组"
        renameButton.isEnabled = editable; deleteButton.isEnabled = editable; input.isEnabled = editable
        info.stringValue = editable ? "包含 \(count(name)) 个收藏" : "未分组是默认收纳区，保留且不可重命名。"
    }
    @objc private func renameGroup() {
        guard let current = picker.titleOfSelectedItem else { return }
        do { let target = try GroupOperations.name(input.stringValue); try rename(current, target); reload(selected: target); status.stringValue = "分组已重命名，收藏和最近删除中的分组同步更新。" }
        catch { showError(error) }
    }
    @objc private func deleteGroup() {
        guard let current = picker.titleOfSelectedItem, current != "未分组" else { return }
        let alert = NSAlert(); alert.messageText = "删除分组「\(current)」？"
        alert.informativeText = "组内 \(count(current)) 个收藏将移到未分组，坐标与备注保留。此窗口中可以撤销。"
        alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "删除分组")
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard let self = self, response == .alertSecondButtonReturn else { return }
            do { try self.remove(current); self.reload(selected: "未分组"); self.status.stringValue = "分组已删除，收藏已移到未分组。" }
            catch { self.showError(error) }
        }
    }
    @objc private func undoGroup() {
        do { try undo(); reload(selected: "未分组"); status.stringValue = "已撤销刚才的分组操作。" }
        catch { showError(error) }
    }
    private func showError(_ error: Error) {
        if case GroupFailure.duplicate = error { status.stringValue = "这个分组名已存在，请换个名称。" }
        else if case GroupFailure.empty = error { status.stringValue = "分组名称不能为空。" }
        else if case GroupFailure.reserved = error { status.stringValue = "未分组和全部分组是保留名称。" }
        else { status.stringValue = "保存未完成，原数据已保留，请稍后重试。" }
    }
    @objc private func finish() {
        if let parent = panel.sheetParent { parent.endSheet(panel) }
        panel.orderOut(nil); completion()
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool { finish(); return false }
}
