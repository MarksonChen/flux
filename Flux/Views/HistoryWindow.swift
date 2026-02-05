import AppKit

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var tableView: NSTableView!
    private var events: [TimerEvent] = []
    private var escapeMonitor: Any?

    convenience init() {
        let window = GlassWindow(
            contentRect: NSRect(origin: .zero, size: Design.WindowSize.history),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Event History"
        window.center()
        window.minSize = Design.WindowSize.historyMin

        self.init(window: window)
        setupUI()
        loadEvents()
        setupEscapeMonitor()
    }

    deinit {
        if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func setupEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let window = self.window,
                  window.isKeyWindow,
                  event.keyCode == 53 else {
                return event
            }
            self.close()
            return nil
        }
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        // Scroll view with table
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = Design.CornerRadius.medium
        scrollView.layer?.masksToBounds = true
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 40),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Design.Spacing.md),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Design.Spacing.md),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Design.Spacing.md)
        ])

        // Table background container for glass effect
        let tableContainer = NSVisualEffectView()
        tableContainer.material = .sidebar
        tableContainer.blendingMode = .withinWindow
        tableContainer.state = .active
        tableContainer.wantsLayer = true
        tableContainer.layer?.cornerRadius = Design.CornerRadius.medium
        tableContainer.translatesAutoresizingMaskIntoConstraints = false

        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.style = .plain
        tableView.rowHeight = Design.Size.tableRowHeight
        tableView.intercellSpacing = NSSize(width: 10, height: Design.Spacing.xs)
        tableView.headerView = nil
        tableView.gridStyleMask = []

        let timeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeColumn.title = "Time"
        timeColumn.width = 100
        timeColumn.minWidth = 80
        tableView.addTableColumn(timeColumn)

        let changeColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("change"))
        changeColumn.title = "Change"
        changeColumn.width = 180
        changeColumn.minWidth = 120
        tableView.addTableColumn(changeColumn)

        let eventColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("event"))
        eventColumn.title = "Event"
        eventColumn.width = 100
        eventColumn.minWidth = 70
        tableView.addTableColumn(eventColumn)

        scrollView.documentView = tableView
    }

    private func loadEvents() {
        events = EventLogger.shared.events
        tableView.reloadData()
    }

    func refreshEvents() {
        loadEvents()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return events.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < events.count else { return nil }
        let event = events[row]

        let identifier = tableColumn?.identifier ?? NSUserInterfaceItemIdentifier("")
        let cellIdentifier = NSUserInterfaceItemIdentifier("Cell_\(identifier.rawValue)")

        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.font = NSFont.systemFont(ofSize: Design.FontSize.sm)
            textField.lineBreakMode = .byTruncatingTail
            textField.alignment = .center
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView?.addSubview(textField)
            cellView?.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor)
            ])
        }

        switch identifier.rawValue {
        case "time":
            cellView?.textField?.stringValue = event.formattedTimestamp
            cellView?.textField?.textColor = .secondaryLabelColor
        case "change":
            cellView?.textField?.stringValue = event.formattedChange
            cellView?.textField?.textColor = .labelColor
            cellView?.textField?.font = NSFont.monospacedDigitSystemFont(ofSize: Design.FontSize.sm, weight: .medium)
        case "event":
            cellView?.textField?.stringValue = event.eventType.rawValue
            cellView?.textField?.textColor = eventColor(for: event.eventType)
            cellView?.textField?.font = NSFont.systemFont(ofSize: Design.FontSize.xs, weight: .medium)
        default:
            cellView?.textField?.stringValue = ""
        }

        return cellView
    }

    private func eventColor(for eventType: TimerEventType) -> NSColor {
        switch eventType {
        case .started:
            return NSColor.systemGreen
        case .paused:
            return NSColor.systemOrange
        case .restarted:
            return NSColor.systemRed
        case .set:
            return NSColor.systemBlue
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView()
        rowView.isEmphasized = false
        return rowView
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
