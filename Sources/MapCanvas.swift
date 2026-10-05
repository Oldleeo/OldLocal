import AppKit
import MapKit

final class MapCanvas: NSView, MKMapViewDelegate, NSGestureRecognizerDelegate, MKLocalSearchCompleterDelegate, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    private let map = MKMapView()
    private let searchInput = NSSearchField()
    private var searchButton: NSButton!
    private let results = NSPopUpButton()
    private let coordinateLabel = textLabel("点击地图选择位置", size: 16, weight: .medium)
    private let hint = textLabel("选点后点击左侧「修改定位」", size: 11, color: .secondaryLabelColor)
    private var copyButton: NSButton!
    private var focusButton: NSButton!
    private var annotation: MKPointAnnotation?
    private var selected: Coordinates?
    private var search: MKLocalSearch?
    private var requestID = UUID()
    private var items: [MKMapItem] = []
    private let completer = MKLocalSearchCompleter()
    private let suggestionsPanel = NSView()
    private var suggestionsHeight: NSLayoutConstraint!
    private let suggestionsTable = NSTableView()
    private var completions: [MKLocalSearchCompletion] = []
    private var completionQuery = ""
    private var ipButton: NSButton!
    private var busy = false
    var onIPLookup: (() -> Void)?
    var onSelection: ((Coordinates) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
                                        span: MKCoordinateSpan(latitudeDelta: 110, longitudeDelta: 300)), animated: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func panel() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.96).cgColor
        view.layer?.cornerRadius = 13
        view.layer?.borderWidth = 0.5
        view.layer?.borderColor = NSColor.black.withAlphaComponent(0.06).cgColor
        view.layer?.shadowColor = NSColor.black.cgColor
        view.layer?.shadowOpacity = 0.12
        view.layer?.shadowRadius = 14
        view.layer?.shadowOffset = NSSize(width: 0, height: -2)
        return view
    }

    private func build() {
        map.translatesAutoresizingMaskIntoConstraints = false
        map.delegate = self
        map.showsUserLocation = false
        map.showsZoomControls = true
        map.isRotateEnabled = false
        map.isPitchEnabled = false
        map.setAccessibilityLabel("选点地图，点击选择位置")
        addSubview(map)
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: leadingAnchor), map.trailingAnchor.constraint(equalTo: trailingAnchor),
            map.topAnchor.constraint(equalTo: topAnchor), map.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        let click = NSClickGestureRecognizer(target: self, action: #selector(clickMap(_:)))
        click.numberOfClicksRequired = 1
        click.buttonMask = 1
        click.delaysPrimaryMouseButtonEvents = false
        click.delegate = self
        map.addGestureRecognizer(click)

        let searchPanel = panel()
        searchPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(searchPanel)
        searchInput.placeholderString = "搜索城市、地址、地标或坐标"
        searchInput.setAccessibilityLabel("地图搜索")
        searchInput.setAccessibilityIdentifier("mapSearch")
        searchInput.cell?.sendsActionOnEndEditing = false
        searchInput.delegate = self
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        configureSuggestions()
        searchInput.target = self
        searchInput.action = #selector(searchPlace)
        searchInput.sendsWholeSearchString = true
        searchInput.sendsSearchStringImmediately = false
        searchInput.bezelStyle = .roundedBezel
        searchButton = ActionButton("搜索", target: self, action: #selector(searchPlace))
        let row = NSStackView(views: [searchInput, searchButton])
        row.orientation = .horizontal
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        searchPanel.addSubview(row)
        NSLayoutConstraint.activate([
            searchPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            searchPanel.topAnchor.constraint(equalTo: topAnchor, constant: 22),
            searchPanel.widthAnchor.constraint(equalToConstant: 410),
            searchPanel.heightAnchor.constraint(equalToConstant: 48),
            row.leadingAnchor.constraint(equalTo: searchPanel.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: searchPanel.trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: searchPanel.centerYAnchor),
            searchButton.widthAnchor.constraint(equalToConstant: 48),
            searchButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        searchInput.setContentHuggingPriority(.defaultLow, for: .horizontal)
        suggestionsPanel.translatesAutoresizingMaskIntoConstraints = false
        suggestionsPanel.wantsLayer = true
        suggestionsPanel.layer?.backgroundColor = NSColor.white.cgColor
        suggestionsPanel.layer?.cornerRadius = 12
        suggestionsPanel.layer?.borderWidth = 0.5
        suggestionsPanel.layer?.borderColor = NSColor.black.withAlphaComponent(0.1).cgColor
        suggestionsPanel.layer?.shadowColor = NSColor.black.cgColor
        suggestionsPanel.layer?.shadowOpacity = 0.13
        suggestionsPanel.layer?.shadowRadius = 12
        suggestionsPanel.isHidden = true
        addSubview(suggestionsPanel)
        suggestionsHeight = suggestionsPanel.heightAnchor.constraint(equalToConstant: 44)
        NSLayoutConstraint.activate([
            suggestionsPanel.leadingAnchor.constraint(equalTo: searchPanel.leadingAnchor),
            suggestionsPanel.trailingAnchor.constraint(equalTo: searchPanel.trailingAnchor),
            suggestionsPanel.topAnchor.constraint(equalTo: searchPanel.bottomAnchor, constant: 8),
            suggestionsHeight
        ])
        results.target = self
        results.action = #selector(selectResult)
        results.setAccessibilityLabel("地图搜索结果")
        results.isHidden = true
        results.translatesAutoresizingMaskIntoConstraints = false
        addSubview(results)
        NSLayoutConstraint.activate([
            results.leadingAnchor.constraint(equalTo: searchPanel.leadingAnchor),
            results.trailingAnchor.constraint(equalTo: searchPanel.trailingAnchor),
            results.topAnchor.constraint(equalTo: searchPanel.bottomAnchor, constant: 8)
        ])

        focusButton = MapToolButton("回到选点", symbol: "scope", target: self, action: #selector(focusSelected))
        focusButton.toolTip = "把地图视野拉回选中的位置"
        focusButton.isEnabled = false
        ipButton = MapToolButton("IP 定位", symbol: "network", target: self, action: #selector(openIPLookup))
        ipButton.toolTip = "根据当前出口或指定 IP 识别区域坐标"
        let tools = NSStackView(views: [ipButton, focusButton])
        tools.orientation = .vertical; tools.spacing = 9
        tools.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tools)
        NSLayoutConstraint.activate([
            tools.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            tools.topAnchor.constraint(equalTo: topAnchor, constant: 84)
        ])
        for button in [ipButton!, focusButton!] {
            button.widthAnchor.constraint(equalToConstant: 142).isActive = true
            button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        }
        let locationPanel = panel()
        locationPanel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(locationPanel)
        let pin = NSImageView(image: NSImage(systemSymbolName: "mappin.circle.fill", accessibilityDescription: nil)!)
        pin.contentTintColor = .systemBlue
        pin.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 29, weight: .regular)
        pin.widthAnchor.constraint(equalToConstant: 31).isActive = true
        let texts = NSStackView(views: [textLabel("选中位置", size: 11, color: .secondaryLabelColor), coordinateLabel, hint])
        texts.orientation = .vertical
        texts.alignment = .leading
        texts.spacing = 5
        coordinateLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        coordinateLabel.setAccessibilityIdentifier("mapSelectedCoordinates")
        copyButton = NSButton(image: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "复制坐标")!, target: self, action: #selector(copyCoordinates))
        copyButton.isBordered = false
        copyButton.setAccessibilityLabel("复制坐标")
        copyButton.isEnabled = false
        copyButton.widthAnchor.constraint(equalToConstant: 26).isActive = true
        let selectionRow = NSStackView(views: [pin, texts, copyButton])
        selectionRow.orientation = .horizontal
        selectionRow.spacing = 12
        selectionRow.translatesAutoresizingMaskIntoConstraints = false
        locationPanel.addSubview(selectionRow)
        NSLayoutConstraint.activate([
            locationPanel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            locationPanel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
            selectionRow.leadingAnchor.constraint(equalTo: locationPanel.leadingAnchor, constant: 16),
            selectionRow.trailingAnchor.constraint(equalTo: locationPanel.trailingAnchor, constant: -16),
            selectionRow.topAnchor.constraint(equalTo: locationPanel.topAnchor, constant: 14),
            selectionRow.bottomAnchor.constraint(equalTo: locationPanel.bottomAnchor, constant: -14)
        ])
        coordinateLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
    }

    func show(_ coordinates: Coordinates, recenter: Bool = true, animated: Bool = true) {
        selected = coordinates
        coordinateLabel.stringValue = coordinates.text
        copyButton.isEnabled = true
        focusButton.isEnabled = !busy
        if let annotation = annotation { map.removeAnnotation(annotation) }
        let pin = MKPointAnnotation()
        pin.coordinate = CLLocationCoordinate2D(latitude: coordinates.latitude, longitude: coordinates.longitude)
        pin.title = "选中位置"
        annotation = pin
        map.addAnnotation(pin)
        if recenter {
            map.setRegion(MKCoordinateRegion(center: pin.coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000), animated: animated)
        }
    }

    func setBusy(_ value: Bool) {
        busy = value
        searchInput.isEnabled = !value
        searchButton.isEnabled = !value
        results.isEnabled = !value
        ipButton.isEnabled = !value
        focusButton.isEnabled = !value && selected != nil
        map.isScrollEnabled = !value
        map.isZoomEnabled = !value
        if value { cancelSearch() }
    }
    private func cancelSearch() {
        requestID = UUID(); search?.cancel(); search = nil
        completer.cancel(); completionQuery = ""; suggestionsPanel.isHidden = true
    }
    @objc private func openIPLookup() { if !busy { onIPLookup?() } }
    private func configureSuggestions() {
        suggestionsTable.refusesFirstResponder = true
        suggestionsTable.headerView = nil; suggestionsTable.rowHeight = 44; suggestionsTable.style = .plain
        suggestionsTable.setAccessibilityLabel("地点搜索建议")
        suggestionsTable.dataSource = self; suggestionsTable.delegate = self
        suggestionsTable.target = self; suggestionsTable.action = #selector(selectSuggestion)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("suggestion"))
        column.width = 395; suggestionsTable.addTableColumn(column)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 410, height: 280))
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true; scroll.documentView = suggestionsTable
        scroll.autoresizingMask = [.width, .height]
        scroll.translatesAutoresizingMaskIntoConstraints = false
        suggestionsPanel.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: suggestionsPanel.leadingAnchor, constant: 3),
            scroll.trailingAnchor.constraint(equalTo: suggestionsPanel.trailingAnchor, constant: -3),
            scroll.topAnchor.constraint(equalTo: suggestionsPanel.topAnchor, constant: 2),
            scroll.bottomAnchor.constraint(equalTo: suggestionsPanel.bottomAnchor, constant: -2)
        ])
    }
    func controlTextDidChange(_ notification: Notification) {
        guard !busy, (notification.object as? NSSearchField) === searchInput else { return }
        let query = searchInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        cancelSearch(); results.isHidden = true
        guard query.count >= 2, Coordinates.parse(query) == nil else { return }
        completionQuery = query; completer.region = map.region; completer.queryFragment = query
    }
    func controlTextDidEndEditing(_ notification: Notification) {
        guard (notification.object as? NSSearchField) === searchInput else { return }
        DispatchQueue.main.async { [weak self] in
            self?.suggestionsPanel.isHidden = true
            self?.completer.cancel()
            self?.completionQuery = ""
        }
    }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !busy, !completionQuery.isEmpty,
              searchInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) == completionQuery else { return }
        completions = Array(completer.results.prefix(7))
        suggestionsTable.reloadData(); suggestionsTable.deselectAll(nil)
        guard !completions.isEmpty else { suggestionsPanel.isHidden = true; return }
        suggestionsHeight.constant = CGFloat(completions.count * 44 + 4)
        suggestionsPanel.isHidden = false
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) { suggestionsPanel.isHidden = true }
    func numberOfRows(in tableView: NSTableView) -> Int { completions.count }
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard completions.indices.contains(row) else { return nil }
        let result = completions[row]
        let title = textLabel(result.title, size: 12.5)
        let subtitle = textLabel(result.subtitle, size: 10.5, color: .secondaryLabelColor)
        title.lineBreakMode = .byTruncatingTail; subtitle.lineBreakMode = .byTruncatingTail
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 3
        let cell = NSTableCellView(); cell.textField = title
        cell.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
            stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor), subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        return cell
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard control === searchInput, !suggestionsPanel.isHidden, !completions.isEmpty else { return false }
        if commandSelector == #selector(NSResponder.moveDown(_:)) || commandSelector == #selector(NSResponder.moveUp(_:)) {
            let delta = commandSelector == #selector(NSResponder.moveDown(_:)) ? 1 : -1
            let row = min(max(suggestionsTable.selectedRow + delta, 0), completions.count - 1)
            suggestionsTable.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            suggestionsTable.scrollRowToVisible(row); return true
        }
        if commandSelector == #selector(NSResponder.insertNewline(_:)), suggestionsTable.selectedRow >= 0 { selectSuggestion(); return true }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) { suggestionsPanel.isHidden = true; return true }
        return false
    }
    @objc private func selectSuggestion() {
        let row = suggestionsTable.selectedRow
        guard !busy, completions.indices.contains(row) else { return }
        let result = completions[row]
        searchInput.stringValue = result.title
        let request = MKLocalSearch.Request(completion: result)
        request.region = map.region
        executeSearch(request)
    }

    @objc private func clickMap(_ recognizer: NSClickGestureRecognizer) {
        guard !busy, recognizer.state == .ended else { return }
        cancelSearch()
        let location = map.convert(recognizer.location(in: map), toCoordinateFrom: map)
        guard CLLocationCoordinate2DIsValid(location) else { return }
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        show(coordinates, recenter: false)
        hint.stringValue = "已选点，点击左侧「修改定位」应用"
        onSelection?(coordinates)
    }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool { true }

    @objc private func focusSelected() { if let selected = selected { show(selected) } }
    @objc private func copyCoordinates() {
        guard let selected = selected else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selected.text, forType: .string)
    }

    @objc private func searchPlace() {
        let query = searchInput.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !query.isEmpty else { return }
        cancelSearch()
        results.isHidden = true
        items = []
        if let coordinates = Coordinates.parse(query) {
            show(coordinates)
            onSelection?(coordinates)
            hint.stringValue = "已跳到坐标，可点击地图微调"
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = map.region
        executeSearch(request)
    }
    private func executeSearch(_ request: MKLocalSearch.Request) {
        cancelSearch(); results.isHidden = true
        let operation = MKLocalSearch(request: request)
        search = operation
        let id = requestID
        hint.stringValue = "正在搜索…"
        operation.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self, !self.busy, id == self.requestID else { return }
                self.search = nil
                guard error == nil, let response = response, !response.mapItems.isEmpty else {
                    self.hint.stringValue = "未找到地点，可换个名称或直接在地图选点"
                    return
                }
                self.items = Array(response.mapItems.prefix(12))
                self.results.removeAllItems()
                for (index, item) in self.items.enumerated() {
                    self.results.addItem(withTitle: "\(index + 1). \(item.name ?? "地点") · \(item.placemark.title ?? "")")
                }
                self.results.isHidden = false
                self.results.selectItem(at: 0)
                self.selectResult()
            }
        }
    }

    @objc private func selectResult() {
        guard !busy, items.indices.contains(results.indexOfSelectedItem) else { return }
        let item = items[results.indexOfSelectedItem]
        let location = item.placemark.coordinate
        let coordinates = Coordinates(latitude: location.latitude, longitude: location.longitude)
        show(coordinates)
        onSelection?(coordinates)
        hint.stringValue = "选中地点，可点击地图微调"
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard annotation is MKPointAnnotation else { return nil }
        let identifier = "SelectedLocation"
        let marker = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        marker.annotation = annotation
        marker.markerTintColor = .systemBlue
        marker.glyphTintColor = .white
        marker.glyphImage = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        marker.titleVisibility = .hidden
        marker.subtitleVisibility = .hidden
        marker.canShowCallout = false
        marker.displayPriority = .required
        return marker
    }

    func mapView(_ mapView: MKMapView, didFailLoadingMapWithError error: Error) {
        hint.stringValue = "地图暂未加载，请检查网络"
    }
}
