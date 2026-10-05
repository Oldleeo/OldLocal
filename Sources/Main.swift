import AppKit

final class LocationApp: NSObject, NSApplicationDelegate, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private var window: NSWindow!
    private var coordinatesInput: NSTextField!
    private var noteInput: NSTextField!
    private var favoritesTable: FavoriteTable!
    private var saveButton: NSButton!
    private var updateButton: NSButton!
    private var groupFilter: NSPopUpButton!
    private var groupInput: NSComboBox!
    private var upButton: NSButton!
    private var downButton: NSButton!
    private let favoriteDragType = NSPasteboard.PasteboardType("art.oldlee.oldlocal.favorite")
    private let creatorPanel = CreatorPanel()
    private var groupManager: GroupManager?
    private var undoGroupChange: (() throws -> Void)?
    private var favorites: [Favorite] = []
    private let favoritesStore = FavoritesStore.local()
    private var favoritesReadable = true
    private var applyButton: NSButton!
    private var restoreButton: NSButton!
    private var statusLabel: NSTextField!
    private var detailLabel: NSTextField!
    private var statusDot: NSImageView!
    private var countLabel: NSTextField!
    private var diagnosticsButton: NSButton!
    private var mapCanvas: MapCanvas!
    private var running = false
    private var helperReady = false
    private let helperClient = HelperClient()
    private var startupGuide: StartupGuide?
    private var diagnostics = "尚无操作记录。"
    private let worker = DispatchQueue(label: "com.oldlee.maclocation.operations", qos: .userInitiated)

    func applicationDidFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "favoriteGroups") == nil {
            UserDefaults.standard.set(["未分组", "工作", "旅行", "家"], forKey: "favoriteGroups")
        }
        buildMenu()
        NSApp.applicationIconImage = OldLocalLogo.image(size: 512, tile: true)
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: min(1160, screen.width - 80), height: min(820, screen.height - 65)),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "OldLocal"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.minSize = NSSize(width: 1000, height: 740)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.center()
        let content = window.contentView!
        let sidebar = NSView()
        sidebar.wantsLayer = true
        sidebar.layer?.backgroundColor = NSColor(calibratedWhite: 0.965, alpha: 1).cgColor
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(sidebar)
        mapCanvas = MapCanvas(frame: .zero)
        mapCanvas.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(mapCanvas)
        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 360),
            mapCanvas.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            mapCanvas.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            mapCanvas.topAnchor.constraint(equalTo: content.topAnchor),
            mapCanvas.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ])
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 54),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -18)
        ])
        let logo = NSImageView(image: OldLocalLogo.image(size: 40, tile: true))
        logo.setAccessibilityLabel("OldLocal Logo")
        logo.widthAnchor.constraint(equalToConstant: 40).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let brand = NSStackView(views: [label("OldLocal", size: 25, weight: .semibold), label("Location Control for Mac", size: 10.5, color: .secondaryLabelColor)])
        brand.orientation = .vertical
        brand.alignment = .leading
        brand.spacing = 3
        let header = NSStackView(views: [logo, brand])
        header.orientation = .horizontal
        header.spacing = 10
        stack.addArrangedSubview(header)
        stack.setCustomSpacing(14, after: header)

        let coordinateGroup = NSStackView()
        coordinateGroup.orientation = .vertical
        coordinateGroup.alignment = .leading
        coordinateGroup.spacing = 8
        coordinateGroup.addArrangedSubview(label("坐标（纬度，经度）", size: 12, weight: .medium))
        coordinatesInput = NSTextField(string: "")
        coordinatesInput.placeholderString = "3.178400, 101.705500"
        coordinatesInput.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        coordinatesInput.bezelStyle = .roundedBezel
        coordinatesInput.controlSize = .large
        coordinatesInput.setAccessibilityLabel("经纬度，纬度在前，经度在后")
        coordinatesInput.setAccessibilityIdentifier("coordinatesInput")
        coordinatesInput.cell?.sendsActionOnEndEditing = false
        coordinatesInput.delegate = self
        coordinatesInput.target = self
        coordinatesInput.action = #selector(previewCoordinates)
        coordinateGroup.addArrangedSubview(coordinatesInput)
        coordinatesInput.heightAnchor.constraint(equalToConstant: 38).isActive = true
        coordinatesInput.widthAnchor.constraint(equalTo: coordinateGroup.widthAnchor).isActive = true
        coordinateGroup.addArrangedSubview(label("WGS84 · 回车预览地图位置", size: 10, color: .secondaryLabelColor))
        stack.addArrangedSubview(coordinateGroup)
        coordinateGroup.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let actions = NSStackView()
        actions.orientation = .vertical
        actions.spacing = 9
        applyButton = ActionButton("修改定位", symbol: "location.fill", primary: true, target: self, action: #selector(applyLocation))
        restoreButton = ActionButton("恢复原定位", symbol: "arrow.counterclockwise", target: self, action: #selector(restoreLocation))
        for button in [applyButton!, restoreButton!] {
            actions.addArrangedSubview(button)
            button.widthAnchor.constraint(equalTo: actions.widthAnchor).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        }
        stack.addArrangedSubview(actions)
        actions.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

        let separator = NSBox()
        separator.boxType = .separator
        stack.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        buildFavorites(in: stack)

        let status = NSStackView()
        status.orientation = .vertical
        status.alignment = .leading
        status.spacing = 6
        statusDot = NSImageView(image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)!)
        statusDot.contentTintColor = .systemGreen
        statusDot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        statusLabel = label("准备就绪", size: 12, weight: .medium)
        statusLabel.setAccessibilityIdentifier("operationStatus")
        status.addArrangedSubview(NSStackView(views: [statusDot, statusLabel]))
        detailLabel = label("点击地图选点，或粘贴经纬度。", size: 10.5, color: .secondaryLabelColor)
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 3
        detailLabel.preferredMaxLayoutWidth = 316
        status.addArrangedSubview(detailLabel)
        stack.addArrangedSubview(status)
        detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.spacing = 14
        let map = NSButton(title: "苹果地图", target: self, action: #selector(openMaps))
        map.bezelStyle = .inline
        map.font = .systemFont(ofSize: 10.5)
        diagnosticsButton = NSButton(title: "查看诊断", target: self, action: #selector(showDiagnostics))
        diagnosticsButton.bezelStyle = .inline
        diagnosticsButton.font = .systemFont(ofSize: 10.5)
        let guideButton = NSButton(title: "使用引导", target: self, action: #selector(showStartupGuide))
        guideButton.bezelStyle = .inline
        guideButton.font = .systemFont(ofSize: 10.5)
        footer.addArrangedSubview(guideButton)
        footer.addArrangedSubview(map)
        footer.addArrangedSubview(diagnosticsButton)
        stack.addArrangedSubview(footer)
        let community = NSStackView()
        community.orientation = .horizontal; community.spacing = 10
        for (title, action) in [("意见反馈", #selector(showFeedback)), ("检查更新", #selector(checkUpdates)), ("开源仓库", #selector(openRepository))] {
            let button = NSButton(title: title, target: self, action: action)
            button.bezelStyle = .rounded; button.font = .systemFont(ofSize: 11)
            community.addArrangedSubview(button)
        }
        stack.addArrangedSubview(community)
        let authorRow = NSStackView()
        authorRow.orientation = .horizontal; authorRow.spacing = 7
        if let avatarURL = Bundle.main.url(forResource: "OldleePortrait", withExtension: "png"), let image = NSImage(contentsOf: avatarURL) {
            let avatar = NSImageView(image: image)
            avatar.imageScaling = .scaleProportionallyUpOrDown
            avatar.setAccessibilityLabel("老李 Oldlee IP 形象")
            avatar.widthAnchor.constraint(equalToConstant: 24).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 28).isActive = true
            authorRow.addArrangedSubview(avatar)
        }
        let author = NSButton(title: "© 2026 老李 Oldlee", target: self, action: #selector(showCreator))
        author.bezelStyle = .inline; author.font = .systemFont(ofSize: 10.5)
        authorRow.addArrangedSubview(author)
        for (title, action) in [("X", #selector(openCreatorX)), ("GitHub", #selector(openCreatorGitHub))] {
            let link = NSButton(title: title, target: self, action: action)
            link.bezelStyle = .inline; link.font = .systemFont(ofSize: 10.5)
            authorRow.addArrangedSubview(link)
        }
        stack.addArrangedSubview(authorRow)
        mapCanvas.onIPLookup = { [weak self] in self?.showIPLookup() }
        mapCanvas.onSelection = { [weak self] coordinates in
            guard let self = self, !self.running else { return }
            self.favoritesTable.deselectAll(nil)
            self.coordinatesInput.stringValue = coordinates.text
            self.noteInput.stringValue = ""
            self.setStatus("已选中位置", detail: "点击修改定位应用，也可备注后收藏。")
        }
        do { favorites = try favoritesStore.load(); rebuildGroups(); favoritesTable.reloadData(); refreshFavoriteButtons() }
        catch {
            favoritesReadable = false
            refreshFavoriteButtons()
            setStatus("收藏读取失败", detail: "原收藏文件已保留，暂时无法保存。", color: .systemRed)
            diagnostics = "收藏读取失败：" + error.localizedDescription
        }
        if let input = UserDefaults.standard.string(forKey: "lastCoordinate"), let coordinates = Coordinates.parse(input) {
            coordinatesInput.stringValue = input
            noteInput.stringValue = UserDefaults.standard.string(forKey: "lastNote") ?? ""
            mapCanvas.show(coordinates, animated: false)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeFirstResponder(coordinatesInput)
        DispatchQueue.main.async { self.showStartupGuide() }
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        textLabel(text, size: size, weight: weight, color: color)
    }

    private var visibleFavorites: [Favorite] {
        let filter = groupFilter?.titleOfSelectedItem ?? "全部分组"
        return filter == "全部分组" ? favorites : favorites.filter { $0.group == filter }
    }
    private var selectedFavorite: Favorite? {
        let visible = visibleFavorites
        let row = favoritesTable.selectedRow
        return visible.indices.contains(row) ? visible[row] : nil
    }
    private var groupNames: [String] {
        var result = ["未分组"]
        for name in (UserDefaults.standard.stringArray(forKey: "favoriteGroups") ?? []) + favorites.map(\.group) {
            let name = Favorite.normalizedGroup(name)
            if name != "全部分组", !result.contains(name) { result.append(name) }
        }
        return result
    }
    private func rebuildGroups() {
        let filter = groupFilter.titleOfSelectedItem ?? "全部分组"
        let input = groupInput.stringValue
        groupFilter.removeAllItems(); groupFilter.addItems(withTitles: ["全部分组"] + groupNames)
        groupFilter.selectItem(withTitle: groupNames.contains(filter) ? filter : "全部分组")
        groupInput.removeAllItems(); groupInput.addItems(withObjectValues: groupNames)
        groupInput.stringValue = input.isEmpty ? "未分组" : input
    }
    private func buildFavorites(in stack: NSStackView) {
        let heading = NSStackView(views: [label("收藏位置", size: 13, weight: .semibold)])
        heading.orientation = .horizontal; heading.spacing = 8
        countLabel = label("0", size: 11, color: .secondaryLabelColor)
        heading.addArrangedSubview(countLabel)
        heading.addArrangedSubview(label("拖动排序", size: 10.5, color: .secondaryLabelColor))
        stack.addArrangedSubview(heading)
        let filters = NSStackView()
        filters.orientation = .horizontal; filters.distribution = .fill; filters.spacing = 8
        groupFilter = NSPopUpButton()
        groupFilter.setAccessibilityLabel("收藏分组筛选")
        groupFilter.target = self; groupFilter.action = #selector(filterGroup)
        groupFilter.setContentHuggingPriority(.defaultLow, for: .horizontal)
        filters.addArrangedSubview(groupFilter)
        let addGroup = NSButton(image: NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: "新建分组")!, target: self, action: #selector(createGroup))
        addGroup.bezelStyle = .rounded; addGroup.setAccessibilityLabel("新建收藏分组")
        filters.addArrangedSubview(addGroup)
        let manage = NSButton(title: "管理", target: self, action: #selector(manageGroups))
        manage.bezelStyle = .rounded; manage.setAccessibilityLabel("管理收藏分组")
        filters.addArrangedSubview(manage)
        stack.addArrangedSubview(filters)
        filters.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        favoritesTable = FavoriteTable()
        favoritesTable.headerView = nil; favoritesTable.style = .plain; favoritesTable.rowHeight = 96
        favoritesTable.intercellSpacing = .zero; favoritesTable.backgroundColor = .clear
        favoritesTable.selectionHighlightStyle = .regular; favoritesTable.allowsMultipleSelection = false
        favoritesTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        favoritesTable.setAccessibilityLabel("收藏位置列表")
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("favorite"))
        column.width = 310; column.minWidth = 285
        favoritesTable.addTableColumn(column)
        favoritesTable.dataSource = self; favoritesTable.delegate = self
        favoritesTable.registerForDraggedTypes([favoriteDragType])
        favoritesTable.setDraggingSourceOperationMask(.move, forLocal: true)
        favoritesTable.contextMenuForRow = { [weak self] row in self?.favoriteMenu(row: row) }
        let scroll = NSScrollView()
        scroll.drawsBackground = false; scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.documentView = favoritesTable
        stack.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        scroll.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        let editor = NSStackView()
        editor.orientation = .vertical; editor.alignment = .leading; editor.spacing = 6
        editor.addArrangedSubview(label("备注与分组", size: 11, color: .secondaryLabelColor))
        noteInput = NSTextField(string: "")
        noteInput.placeholderString = "给这个位置起个名字"
        noteInput.bezelStyle = .roundedBezel; noteInput.font = .systemFont(ofSize: 12)
        noteInput.target = self; noteInput.action = #selector(saveFavorite)
        noteInput.setAccessibilityLabel("收藏备注"); noteInput.setAccessibilityIdentifier("favoriteNote")
        noteInput.heightAnchor.constraint(equalToConstant: 30).isActive = true
        editor.addArrangedSubview(noteInput)
        noteInput.widthAnchor.constraint(equalTo: editor.widthAnchor).isActive = true
        groupInput = NSComboBox()
        groupInput.font = .systemFont(ofSize: 11.5); groupInput.completes = true
        groupInput.setAccessibilityLabel("收藏所属分组，可输入新名称")
        groupInput.stringValue = "未分组"
        groupInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        saveButton = ActionButton("收藏当前位置", target: self, action: #selector(saveFavorite))
        saveButton.widthAnchor.constraint(equalToConstant: 120).isActive = true
        saveButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
        let saveRow = NSStackView(views: [groupInput, saveButton])
        saveRow.orientation = .horizontal; saveRow.spacing = 8
        editor.addArrangedSubview(saveRow)
        saveRow.widthAnchor.constraint(equalTo: editor.widthAnchor).isActive = true
        stack.addArrangedSubview(editor)
        editor.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        updateButton = NSButton(title: "更新所选", target: self, action: #selector(updateFavorite))
        updateButton.bezelStyle = .inline; updateButton.font = .systemFont(ofSize: 10.5)
        upButton = NSButton(image: NSImage(systemSymbolName: "arrow.up", accessibilityDescription: "上移收藏")!, target: self, action: #selector(moveUp))
        downButton = NSButton(image: NSImage(systemSymbolName: "arrow.down", accessibilityDescription: "下移收藏")!, target: self, action: #selector(moveDown))
        for button in [upButton!, downButton!] { button.bezelStyle = .rounded; button.controlSize = .small }
        let deleted = NSButton(title: "最近删除", target: self, action: #selector(showDeleted))
        deleted.bezelStyle = .inline; deleted.font = .systemFont(ofSize: 10.5)
        let controls = NSStackView(views: [updateButton, upButton, downButton, deleted])
        controls.orientation = .horizontal; controls.spacing = 8
        stack.addArrangedSubview(controls)
        rebuildGroups(); refreshFavoriteButtons()
    }
    @objc private func filterGroup() {
        guard !running else { return }
        favoritesTable.deselectAll(nil); favoritesTable.reloadData()
        if let group = groupFilter.titleOfSelectedItem, group != "全部分组" { groupInput.stringValue = group }
        refreshFavoriteButtons()
    }
    @objc private func createGroup() {
        guard !running, favoritesReadable else { return }
        let alert = NSAlert(); alert.messageText = "新建收藏分组"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 26))
        input.placeholderString = "例如：旅行、工作、家"
        alert.accessoryView = input; alert.addButton(withTitle: "创建"); alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = Favorite.normalizedGroup(input.stringValue)
        guard name != "全部分组" else { setStatus("请换个分组名称", detail: "全部分组是筛选入口。", color: .systemOrange); return }
        var names = groupNames
        if !names.contains(name) { names.append(name) }
        UserDefaults.standard.set(names, forKey: "favoriteGroups")
        rebuildGroups(); groupFilter.selectItem(withTitle: name); groupInput.stringValue = name
        filterGroup()
    }
    @objc private func manageGroups() {
        guard !running, favoritesReadable, window.attachedSheet == nil else { return }
        undoGroupChange = nil
        let manager = GroupManager(names: { [weak self] in self?.groupNames ?? [] },
            count: { [weak self] name in self?.favorites.filter { $0.group == name }.count ?? 0 },
            rename: { [weak self] source, target in try self?.changeGroup(source, to: target) },
            remove: { [weak self] source in try self?.changeGroup(source, to: nil) },
            undo: { [weak self] in
                guard let self = self, let action = self.undoGroupChange else { return }
                try action(); self.undoGroupChange = nil
                self.setStatus("分组操作已撤销", detail: "分组与收藏已恢复到操作前。", color: .systemGreen)
            }, canUndo: { [weak self] in self?.undoGroupChange != nil },
            completion: { [weak self] in self?.groupManager = nil; self?.undoGroupChange = nil })
        groupManager = manager; manager.show(on: window)
    }
    private func changeGroup(_ source: String, to proposed: String?) throws {
        guard source != "未分组" else { throw GroupFailure.reserved }
        let target = try proposed.map { try GroupOperations.name($0) }
        if let target = target, target != source, groupNames.contains(target) { throw GroupFailure.duplicate }
        if target == source { return }
        let before = favorites
        let deletedBefore = try favoritesStore.trash.load()
        let namesBefore = groupNames
        let editorBefore = groupInput.stringValue
        let destination = target ?? "未分组"
        let after = GroupOperations.rename(source, to: destination, in: before)
        let deletedAfter = GroupOperations.rename(source, to: destination, in: deletedBefore)
        let namesAfter = namesBefore.compactMap { name -> String? in name == source ? target : name }
        try saveGroupState(after, deleted: deletedAfter, names: namesAfter)
        if editorBefore == source { groupInput.stringValue = destination }
        undoGroupChange = { [weak self] in
            guard let self = self else { return }
            try self.saveGroupState(before, deleted: deletedBefore, names: namesBefore)
            self.groupInput.stringValue = editorBefore
        }
        setStatus(target == nil ? "分组已删除" : "分组已重命名", detail: "收藏坐标与备注均保留。", color: .systemGreen)
    }
    private func saveGroupState(_ active: [Favorite], deleted: [Favorite], names: [String]) throws {
        let before = favorites
        let deletedBefore = try favoritesStore.trash.load()
        do {
            try favoritesStore.save(active)
            try favoritesStore.trash.save(deleted)
        } catch {
            try? favoritesStore.save(before); try? favoritesStore.trash.save(deletedBefore)
            throw error
        }
        UserDefaults.standard.set(names, forKey: "favoriteGroups")
        favorites = active
        rebuildGroups(); favoritesTable.deselectAll(nil); favoritesTable.reloadData(); refreshFavoriteButtons()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { visibleFavorites.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let visible = visibleFavorites
        guard visible.indices.contains(row) else { return nil }
        let favorite = visible[row]
        let identifier = NSUserInterfaceItemIdentifier("FavoriteCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? FavoriteCell ?? FavoriteCell(frame: .zero)
        cell.identifier = identifier
        cell.configure(favorite, ready: helperReady && !running, editable: favoritesReadable && !running)
        cell.onApply = { [weak self] in self?.applyFavorite(favorite.id) }
        cell.onDelete = { [weak self] in self?.deleteFavorite(favorite.id) }
        return cell
    }
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { FavoriteRow(frame: .zero) }
    func tableViewSelectionDidChange(_ notification: Notification) {
        if let item = selectedFavorite, !running {
            coordinatesInput.stringValue = item.coordinates.text; noteInput.stringValue = item.note; groupInput.stringValue = item.group
            mapCanvas.show(item.coordinates)
            setStatus("已选中收藏", detail: "卡片上点击应用可立即切换定位。")
        }
        refreshFavoriteButtons()
    }
    private func refreshFavoriteButtons() {
        let selected = selectedFavorite != nil
        saveButton.isEnabled = !running && favoritesReadable
        updateButton.isEnabled = !running && favoritesReadable && selected
        groupFilter.isEnabled = !running; groupInput.isEnabled = !running
        let row = favoritesTable.selectedRow
        upButton.isEnabled = !running && favoritesReadable && row > 0
        downButton.isEnabled = !running && favoritesReadable && row >= 0 && row + 1 < visibleFavorites.count
        countLabel.stringValue = String(visibleFavorites.count)
        for index in visibleFavorites.indices {
            if let cell = favoritesTable.view(atColumn: 0, row: index, makeIfNecessary: false) as? FavoriteCell {
                cell.configure(visibleFavorites[index], ready: helperReady && !running, editable: favoritesReadable && !running)
            }
        }
    }
    private func applyFavorite(_ id: UUID) {
        guard !running, let item = favorites.first(where: { $0.id == id }) else { return }
        coordinatesInput.stringValue = item.coordinates.text; noteInput.stringValue = item.note; groupInput.stringValue = item.group
        mapCanvas.show(item.coordinates)
        perform(command: "set", arguments: ["--latitude", String(item.coordinates.latitude), "--longitude", String(item.coordinates.longitude)])
    }
    private func favoriteMenu(row: Int) -> NSMenu? {
        let visible = visibleFavorites
        guard visible.indices.contains(row) else { return nil }
        let menu = NSMenu(); menu.autoenablesItems = false
        for (title, selector, enabled) in [("应用此位置", #selector(contextApply(_:)), helperReady && !running),
            ("删除收藏", #selector(contextDelete(_:)), favoritesReadable && !running)] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; item.representedObject = visible[row].id.uuidString; item.isEnabled = enabled
            menu.addItem(item)
        }
        return menu
    }
    @objc private func contextApply(_ sender: NSMenuItem) { if let text = sender.representedObject as? String, let id = UUID(uuidString: text) { applyFavorite(id) } }
    @objc private func contextDelete(_ sender: NSMenuItem) { if let text = sender.representedObject as? String, let id = UUID(uuidString: text) { deleteFavorite(id) } }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let visible = visibleFavorites
        guard !running, favoritesReadable, visible.count > 1, visible.indices.contains(row) else { return nil }
        let item = NSPasteboardItem(); item.setString(visible[row].id.uuidString, forType: favoriteDragType); return item
    }
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard !running, favoritesReadable, (info.draggingSource as? NSTableView) === tableView else { return [] }
        tableView.setDropRow(row, dropOperation: .above); return .move
    }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard !running, favoritesReadable, (info.draggingSource as? NSTableView) === tableView,
              let text = info.draggingPasteboard.string(forType: favoriteDragType), let id = UUID(uuidString: text) else { return false }
        let visible = visibleFavorites
        let target = visible.indices.contains(row) ? visible[row].id : nil
        let last = visible.last(where: { $0.id != id })?.id
        persistFavorites(FavoriteOrdering.moving(favorites, id: id, before: target, after: target == nil ? last : nil), selectedID: id, message: "收藏顺序已保存")
        return true
    }
    @objc private func moveUp() { moveSelected(by: -1) }
    @objc private func moveDown() { moveSelected(by: 1) }
    private func moveSelected(by offset: Int) {
        let visible = visibleFavorites; let row = favoritesTable.selectedRow; let target = row + offset
        guard !running, favoritesReadable, visible.indices.contains(row), visible.indices.contains(target) else { return }
        let id = visible[row].id
        let result = FavoriteOrdering.moving(favorites, id: id, before: offset < 0 ? visible[target].id : nil, after: offset > 0 ? visible[target].id : nil)
        persistFavorites(result, selectedID: id, message: "收藏顺序已保存")
    }
    @objc private func focusFavoriteNote() { if !running { window.makeFirstResponder(noteInput) } }
    @objc private func previewCoordinates() {
        guard !running, !coordinatesInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let coordinates = enteredCoordinates() else { return }
        mapCanvas.show(coordinates)
        setStatus("已预览位置", detail: "点击修改定位应用，也可备注后收藏。")
    }
    private func enteredCoordinates() -> Coordinates? {
        guard let value = Coordinates.parse(coordinatesInput.stringValue) else {
            setStatus("请检查经纬度", detail: "格式：纬度, 经度。纬度 −90～90，经度 −180～180。", color: .systemRed)
            window.makeFirstResponder(coordinatesInput)
            return nil
        }
        return value
    }
    private func enteredFavorite() -> (String, Coordinates)? {
        guard let coordinates = enteredCoordinates() else { return nil }
        let note = noteInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !note.isEmpty else {
            setStatus("请填写收藏备注", detail: "给这个位置起个名字，方便下次选用。", color: .systemRed)
            window.makeFirstResponder(noteInput)
            return nil
        }
        if groupInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == "全部分组" {
            setStatus("请换个分组名称", detail: "全部分组是筛选入口。", color: .systemOrange); return nil
        }
        return (note, coordinates)
    }
    private func persistFavorites(_ proposed: [Favorite], selectedID: UUID?, message: String) {
        do {
            try favoritesStore.save(proposed)
            favorites = proposed
            UserDefaults.standard.set(groupNames, forKey: "favoriteGroups")
            rebuildGroups()
            if let id = selectedID, let item = favorites.first(where: { $0.id == id }), !visibleFavorites.contains(where: { $0.id == id }) {
                groupFilter.selectItem(withTitle: item.group)
            }
            favoritesTable.reloadData()
            if let id = selectedID, let row = visibleFavorites.firstIndex(where: { $0.id == id }) {
                favoritesTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                favoritesTable.scrollRowToVisible(row)
            } else { favoritesTable.deselectAll(nil) }
            refreshFavoriteButtons()
            setStatus(message, detail: "收藏已保存在本机。点击收藏可填入坐标。", color: .systemGreen)
        } catch {
            diagnostics = "收藏保存失败：" + error.localizedDescription
            setStatus("收藏保存失败", detail: "之前的收藏仍保留，可查看诊断后重试。", color: .systemRed)
        }
    }
    @objc private func saveFavorite() {
        guard !running, favoritesReadable, let (note, coordinates) = enteredFavorite() else { return }
        let item = Favorite(id: UUID(), note: note, coordinates: coordinates, group: groupInput.stringValue)
        persistFavorites(favorites + [item], selectedID: item.id, message: "已收藏")
    }
    @objc private func updateFavorite() {
        guard !running, favoritesReadable, let selected = selectedFavorite,
              let index = favorites.firstIndex(where: { $0.id == selected.id }), let (note, coordinates) = enteredFavorite() else { return }
        var proposed = favorites
        proposed[index].note = note; proposed[index].coordinates = coordinates
        proposed[index].group = Favorite.normalizedGroup(groupInput.stringValue)
        persistFavorites(proposed, selectedID: selected.id, message: "收藏已更新")
    }
    private func deleteFavorite(_ id: UUID) {
        guard !running, favoritesReadable, let item = favorites.first(where: { $0.id == id }) else { return }
        let alert = NSAlert(); alert.messageText = "删除这条收藏？"
        alert.informativeText = item.note + "\n可从最近删除恢复。当前定位不会改变。"
        alert.addButton(withTitle: "取消"); alert.addButton(withTitle: "删除")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            let remaining = try favoritesStore.moveToTrash(item, from: favorites)
            favorites = remaining; rebuildGroups(); favoritesTable.deselectAll(nil); favoritesTable.reloadData(); refreshFavoriteButtons()
            setStatus("收藏已删除", detail: "可在最近删除中恢复。", color: .systemGreen)
        } catch { setStatus("删除未完成", detail: "原收藏仍保留，请稍后重试。", color: .systemRed) }
    }
    @objc private func showDeleted() {
        guard !running, window.attachedSheet == nil else { return }
        do {
            let deleted = try favoritesStore.trash.load().filter { item in !favorites.contains(where: { $0.id == item.id }) }
            let alert = NSAlert(); alert.messageText = "最近删除"
            guard !deleted.isEmpty else { alert.informativeText = "这里还没有已删除的收藏。"; alert.runModal(); return }
            alert.informativeText = "选一个收藏恢复；备注、坐标和分组都会保留。"
            let chooser = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 330, height: 28))
            chooser.addItems(withTitles: deleted.map { $0.note + " · " + $0.group })
            alert.accessoryView = chooser; alert.addButton(withTitle: "恢复收藏"); alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn, deleted.indices.contains(chooser.indexOfSelectedItem) else { return }
            let item = deleted[chooser.indexOfSelectedItem]
            let restored = try favoritesStore.restoring(item, into: favorites)
            persistFavorites(restored, selectedID: item.id, message: "收藏已恢复")
        } catch { setStatus("恢复未完成", detail: "请稍后再试，原文件已保留。", color: .systemRed) }
    }
    @objc private func showCreator() { if !running, window.attachedSheet == nil { creatorPanel.show(on: window) } }
    @objc private func openCreatorX() { NSWorkspace.shared.open(CreatorPanel.xURL) }
    @objc private func openCreatorGitHub() { NSWorkspace.shared.open(CreatorPanel.githubURL) }
    @objc private func showFeedback() {
        guard !running, window.attachedSheet == nil else { return }
        FeedbackPanel().show(on: window)
    }
    @objc private func checkUpdates() {
        guard !running, window.attachedSheet == nil else { return }
        UpdatePanel().show(on: window)
    }
    @objc private func openRepository() { NSWorkspace.shared.open(ProjectChannel.repository) }
    private func showIPLookup() {
        guard !running, window.attachedSheet == nil else { return }
        let panel = IPLocationPanel { [weak self] location in
            guard let self = self else { return }
            self.favoritesTable.deselectAll(nil)
            self.coordinatesInput.stringValue = location.coordinates.text
            self.noteInput.stringValue = location.city.map { $0 + " · IP" } ?? "IP 估计位置"
            self.mapCanvas.show(location.coordinates)
            self.setStatus("已填入 IP 估计坐标", detail: "" + location.place + "。点击修改定位才会应用。")
        }
        panel.show(on: window)
    }
    @objc private func applyLocation() {
        guard !running, let value = enteredCoordinates() else { return }
        mapCanvas.show(value)
        perform(command: "set", arguments: ["--latitude", String(value.latitude), "--longitude", String(value.longitude)])
    }

    @objc private func restoreLocation() { perform(command: "reset", arguments: []) }

    private func setStatus(_ title: String, detail: String, color: NSColor = .labelColor) {
        statusLabel.stringValue = title
        statusLabel.textColor = color
        statusDot.contentTintColor = color == .labelColor ? .systemBlue : color
        detailLabel.stringValue = detail
    }

    private func setRunning(_ value: Bool) {
        running = value
        [applyButton, restoreButton].forEach { $0?.isEnabled = !value && helperReady }
        diagnosticsButton.isEnabled = !value
        coordinatesInput.isEnabled = !value
        noteInput.isEnabled = !value
        favoritesTable.isEnabled = !value
        mapCanvas.setBusy(value)
        refreshFavoriteButtons()
    }

    private func shellQuote(_ text: String) -> String { "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    private func appleQuote(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n") + "\""
    }

    private func perform(command: String, arguments: [String]) {
        guard !running else { return }
        guard helperReady else { showStartupGuide(); return }
        let latitude = command == "set" ? Double(arguments[1]) ?? .nan : 0
        let longitude = command == "set" ? Double(arguments[3]) ?? .nan : 0
        setRunning(true)
        setStatus(command == "set" ? "正在修改定位…" : "正在恢复原定位…", detail: "正在核对参数并刷新定位服务。")
        helperClient.perform(command, latitude: latitude, longitude: longitude) { [weak self] captured in
            guard let self = self else { return }
            self.setRunning(false)
            self.diagnostics = captured
            var finalResult: [String: Any]?
            for line in captured.components(separatedBy: .newlines) where line.hasPrefix("RESULT_JSON ") {
                if let data = String(line.dropFirst(12)).data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] { finalResult = json }
            }
                switch finalResult?["status"] as? String {
                case "applied":
                    self.setStatus("定位已修改", detail: "可在地图核对。若仍显示旧位置，请关闭再打开地图。结束时点击恢复原定位。", color: .systemGreen)
                case "restored":
                    self.setStatus("原定位已恢复", detail: "原参数已核对，定位服务已刷新。若地图未更新，请关闭再打开地图。", color: .systemGreen)
                case "preferences_restored_service_refresh_unconfirmed":
                    self.setStatus("参数已恢复，刷新待确认", detail: "请在地图检查当前位置，详细结果可查看诊断。", color: .systemOrange)
                case "set_failed_parameters_rolled_back":
                    self.setStatus("修改未完成，参数已回退", detail: "本次修改未成功，之前的参数已恢复。详细结果可查看诊断。", color: .systemOrange)
                case "refresh_blocked":
                    self.setStatus("系统未允许更新定位", detail: "未写入新的坐标，详细结果可查看诊断。", color: .systemRed)
                case "helper_unavailable":
                    self.helperReady = false
                    self.setRunning(false)
                    self.setStatus("定位组件需要启用", detail: "点击「使用引导」启用或更新组件。", color: .systemOrange)
                case "busy":
                    self.setStatus("另一项定位操作正在进行", detail: "请稍后再试。", color: .systemOrange)
                default:
                    self.setStatus("操作未完成", detail: "请查看诊断了解原因，未将此次操作视为成功。", color: .systemRed)
                }
        }
    }

    @objc private func showStartupGuide() {
        guard startupGuide == nil, !running else { return }
        let guide = StartupGuide { [weak self] in self?.installHelper() }
        startupGuide = guide
        guide.show(on: window) { [weak self] in self?.startupGuide = nil }
        helperClient.check { [weak self, weak guide] ready in
            guard let self = self else { return }
            self.helperReady = ready
            self.setRunning(false)
            guide?.update(ready: ready)
            if !ready { self.setStatus("定位组件未启用", detail: "打开使用引导，完成一次管理员授权。", color: .systemOrange) }
        }
    }

    private func installHelper() { manageHelper(operation: "install") }

    @objc private func removeHelper() {
        guard !running else { return }
        let alert = NSAlert()
        alert.messageText = "移除后台定位组件？"
        alert.informativeText = "收藏和原定位备份会保留。如需恢复位置，请先点击恢复原定位。移除后需重新启用组件才能修改定位。"
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "移除组件")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        manageHelper(operation: "uninstall")
    }

    private func manageHelper(operation: String) {
        guard !running else { return }
        guard Bundle.main.bundlePath == "/Applications/OldLocal.app" else {
            setStatus("请先放入应用程序", detail: "从应用程序文件夹打开 OldLocal 后，再启用定位组件。", color: .systemOrange)
            return
        }
        helperClient.invalidate()
        helperReady = false
        let executable = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/HelperTools/OldLocalInstaller").path
        let shell = [executable, operation, String(getuid())].map(shellQuote).joined(separator: " ")
        let source = "do shell script " + appleQuote(shell + " 2>&1; /usr/bin/true") + " with administrator privileges"
        setRunning(true)
        setStatus("等待系统授权…", detail: "首次启用或更新定位组件需要管理员批准。")
        worker.async { [weak self] in
            var error: NSDictionary?
            let output = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue ?? ""
            let cancelled = (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue == -128
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.diagnostics = output
                self.setRunning(false)
                if operation == "uninstall", output.contains("OLDLOCAL_HELPER_REMOVED") {
                    self.setStatus("定位组件已移除", detail: "收藏和原定位备份仍保留。", color: .secondaryLabelColor)
                } else if output.contains("OLDLOCAL_HELPER_INSTALLED") {
                    self.helperClient.check { [weak self] ready in
                        guard let self = self else { return }
                        self.helperReady = ready
                        self.setRunning(false)
                        self.setStatus(ready ? "定位组件已就绪" : "组件尚未连接", detail: ready ? "之后修改和恢复定位无需重复输入密码。" : "请检查系统是否允许 OldLocal 在后台运行。", color: ready ? .systemGreen : .systemOrange)
                    }
                } else {
                    self.setStatus(cancelled ? "启用已取消" : "组件安装未完成", detail: "可再次打开使用引导，定位参数未改变。", color: .systemOrange)
                }
            }
        }
    }

    @objc private func openMaps() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Maps") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
        }
    }

    @objc private func showDiagnostics() {
        let alert = NSAlert()
        alert.messageText = "本次操作诊断"
        alert.informativeText = "诊断不包含密码或目标经纬度。"
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 500, height: 230))
        scroll.hasVerticalScroller = true
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.string = diagnostics
        scroll.documentView = text
        alert.accessoryView = scroll
        alert.addButton(withTitle: "关闭")
        alert.runModal()
    }

    private func buildMenu() {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 OldLocal", action: #selector(showCreator), keyEquivalent: "")
        appMenu.addItem(withTitle: "检查更新…", action: #selector(checkUpdates), keyEquivalent: "")
        appMenu.addItem(withTitle: "管理收藏分组…", action: #selector(manageGroups), keyEquivalent: "")
        appMenu.addItem(withTitle: "最近删除的收藏", action: #selector(showDeleted), keyEquivalent: "")
        appMenu.addItem(withTitle: "使用引导", action: #selector(showStartupGuide), keyEquivalent: "")
        appMenu.addItem(withTitle: "移除定位组件…", action: #selector(removeHelper), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 OldLocal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        let editItem = NSMenuItem()
        editItem.title = "编辑"
        let edit = NSMenu(title: "编辑")
        edit.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        menu.addItem(editItem)
        let helpItem = NSMenuItem()
        helpItem.title = "帮助"
        let help = NSMenu(title: "帮助")
        help.addItem(withTitle: "意见反馈…", action: #selector(showFeedback), keyEquivalent: "")
        help.addItem(withTitle: "检查更新…", action: #selector(checkUpdates), keyEquivalent: "")
        help.addItem(withTitle: "OldLocal 开源仓库", action: #selector(openRepository), keyEquivalent: "")
        helpItem.submenu = help; menu.addItem(helpItem)
        NSApp.mainMenu = menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        UserDefaults.standard.set(coordinatesInput.stringValue, forKey: "lastCoordinate")
        UserDefaults.standard.set(noteInput.stringValue, forKey: "lastNote")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if running {
            setStatus("正在处理，请稍候…", detail: "更新完成后再关闭软件，以便确认设置或恢复结果。")
            return .terminateCancel
        }
        return .terminateNow
    }
}

@main
struct Launcher {
    static func main() {
        let app = NSApplication.shared
        let delegate = LocationApp()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        app.run()
    }
}
