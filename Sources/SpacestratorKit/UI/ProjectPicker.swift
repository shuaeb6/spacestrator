import Foundation
import AppKit

/// Searchable project chooser, the AppKit equivalent of hs.chooser in ui/projectPicker.lua.
/// A borderless panel with a search field over a table; type to filter, Return to load,
/// Escape to dismiss.
final class ProjectPicker: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    static let shared = ProjectPicker()

    private var panel: NSPanel?
    private var searchField: NSSearchField!
    private var tableView: NSTableView!

    private struct Row { let slug: String; let label: String }
    private var allRows: [Row] = []
    private var filtered: [Row] = []

    func show() {
        loadRows()
        guard !allRows.isEmpty else {
            Notify.send(title: "Spacestrator", body: "No .json configs in \(WorkspaceStore.configDir())")
            return
        }
        filtered = allRows

        if panel == nil { buildPanel() }
        searchField.stringValue = ""
        tableView.reloadData()
        selectFirst()

        NSApp.activate(ignoringOtherApps: true)
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        panel?.makeFirstResponder(searchField)
    }

    // MARK: - Data

    private func loadRows() {
        allRows = WorkspaceStore.listProjectSlugs().map { slug in
            let cfg = WorkspaceStore.loadProjectConfig(slug)
            return Row(slug: slug, label: cfg?.name ?? slug)
        }
    }

    private func applyFilter(_ query: String) {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty {
            filtered = allRows
        } else {
            filtered = allRows
                .filter { $0.label.lowercased().contains(q) || $0.slug.lowercased().contains(q) }
                .sorted { lhs, rhs in
                    // Earlier match position ranks higher.
                    let l = lhs.label.lowercased().range(of: q)?.lowerBound
                    let r = rhs.label.lowercased().range(of: q)?.lowerBound
                    let li = l.map { lhs.label.distance(from: lhs.label.startIndex, to: $0) } ?? Int.max
                    let ri = r.map { rhs.label.distance(from: rhs.label.startIndex, to: $0) } ?? Int.max
                    return li < ri
                }
        }
        tableView.reloadData()
        selectFirst()
    }

    private func selectFirst() {
        if !filtered.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: - UI

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        panel.title = "Spacestrator — Project Picker"
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false

        let container = NSView(frame: panel.contentView!.bounds)
        container.autoresizingMask = [.width, .height]

        searchField = NSSearchField(frame: NSRect(x: 12, y: 280, width: 436, height: 28))
        searchField.autoresizingMask = [.width, .minYMargin]
        searchField.placeholderString = "Search projects…"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchChanged)
        container.addSubview(searchField)

        let scroll = NSScrollView(frame: NSRect(x: 12, y: 12, width: 436, height: 256))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(commitSelection)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("project"))
        column.width = 420
        tableView.addTableColumn(column)
        scroll.documentView = tableView
        container.addSubview(scroll)

        panel.contentView = container
        self.panel = panel
    }

    @objc private func searchChanged() {
        applyFilter(searchField.stringValue)
    }

    // Intercept Return/Escape/Arrows from the search field.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            commitSelection()
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            panel?.close()
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1); return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1); return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let current = tableView.selectedRow
        let next = max(0, min(filtered.count - 1, current + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    @objc private func commitSelection() {
        let row = tableView.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let slug = filtered[row].slug
        panel?.close()
        WorkspaceLoader.loadProject(slug)
    }

    // MARK: - Table

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView)
            ?? makeCell(id: id)
        let entry = filtered[row]
        cell.textField?.stringValue = entry.label
        return cell
    }

    private func makeCell(id: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = id
        let title = NSTextField(labelWithString: "")
        title.font = .systemFont(ofSize: 13)
        title.frame = NSRect(x: 8, y: 8, width: 400, height: 20)
        title.autoresizingMask = [.width]
        cell.addSubview(title)
        cell.textField = title
        return cell
    }
}
