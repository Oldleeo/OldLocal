import AppKit

final class FavoriteTable: NSTableView {
    var contextMenuForRow: ((Int) -> NSMenu?)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let index = row(at: convert(event.locationInWindow, from: nil))
        guard index >= 0 else { return nil }
        selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        return contextMenuForRow?(index)
    }
}
