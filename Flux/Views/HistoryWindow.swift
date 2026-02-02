import AppKit

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var events: [TimerEvent] = []

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.center()
        window.minSize = NSSize(width: 350, height: 200)

        self.init(window: window)
        setupUI()
        loadEvents()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 120
        timeColumn.minWidth = 100
        tableView.addTableColumn(timeColumn)

        let changeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("change"))
        changeColumn.title = "Change"
        changeColumn.width = 140
        changeColumn.minWidth = 100
        tableView.addTableColumn(changeColumn)

        let eventColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("event"))
        eventColumn.title = "Event"
        eventColumn.width = 100
        eventColumn.minWidth = 80
        tableView.addTableColumn(eventColumn)

        scrollView.documentView = tableView
    }

    private func loadEvents() {
        events = EventLogger.shared.events
        tableView.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return events.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < events.count else { return nil }
        let event = events[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let cellIdentifier = NSUserInterfaceItemIdentifier("Cell_\(identifier.rawValue)")

        var textField = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTextField
        if textField == nil {
            textField = NSTextField(labelWithString: "")
            textField?.identifier = cellIdentifier
        }

        switch identifier.rawValue {
        case "time":
            textField?.stringValue = event.formattedTimestamp
        case "change":
            textField?.stringValue = event.formattedChange
        case "event":
            textField?.stringValue = event.eventType.rawValue
        default:
            textField?.stringValue = ""
        }

        return textField
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
