import AppKit

// MARK: - Detail Entry

private enum DetailEntry {
    case systemHeader(PollResult)
    case session(ClaudeSession)
}

// MARK: - Detail Window Controller

final class DetailWindowController: NSWindowController {
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private var entries: [DetailEntry] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 400),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Claude Monitor Details"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        setupTable()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupTable() {
        let columns: [(String, CGFloat)] = [
            ("Project", 140),
            ("PID", 60),
            ("Status", 80),
            ("CPU%", 60),
            ("MEM", 60),
            ("Uptime", 90),
            ("Activity", 230),
        ]

        for (title, width) in columns {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            col.title = title
            col.width = width
            col.minWidth = 40
            tableView.addTableColumn(col)
        }

        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 20
        tableView.headerView = NSTableHeaderView()
        tableView.allowsColumnResizing = true
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autoresizingMask = [.width, .height]
        scrollView.borderType = .noBorder

        guard let contentView = window?.contentView else { return }
        scrollView.frame = contentView.bounds
        contentView.addSubview(scrollView)
    }

    // MARK: - Update

    func update(result: PollResult) {
        entries.removeAll()
        entries.append(.systemHeader(result))
        entries.append(contentsOf: result.sessions.map { .session($0) })
        tableView.reloadData()
    }
}

// MARK: - NSTableViewDataSource

extension DetailWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return entries.count
    }
}

// MARK: - NSTableViewDelegate

extension DetailWindowController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        if case .systemHeader = entries[row] { return true }
        return false
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < entries.count else { return nil }

        let entry = entries[row]

        // Group row: tableColumn is nil, return a full-width header cell
        if tableColumn == nil {
            return makeGroupRowCell(for: entry, tableView: tableView)
        }

        // Regular column cell
        let columnID = tableColumn!.identifier
        return makeCell(for: entry, columnID: columnID, tableView: tableView)
    }

    // MARK: - Cell factories

    private func makeGroupRowCell(for entry: DetailEntry, tableView: NSTableView) -> NSView? {
        let id = "group_header"
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = NSUserInterfaceItemIdentifier(id)
            let tf = makeTextField()
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        cell.textField?.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        cell.textField?.textColor = NSColor.labelColor

        if case .systemHeader(let result) = entry {
            cell.textField?.stringValue = "System  (\(result.sessions.count) sessions)"
        }

        return cell
    }

    private func makeCell(for entry: DetailEntry, columnID: NSUserInterfaceItemIdentifier, tableView: NSTableView) -> NSTableCellView {
        let id = "cell_\(columnID.rawValue)"
        let cell: NSTableCellView

        if let existing = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(id), owner: nil) as? NSTableCellView {
            cell = existing
        } else {
            cell = NSTableCellView()
            cell.identifier = NSUserInterfaceItemIdentifier(id)
            let tf = makeTextField()
            cell.addSubview(tf)
            cell.textField = tf
            NSLayoutConstraint.activate([
                tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }

        let font: NSFont
        let color: NSColor
        let text: String

        switch entry {
        case .systemHeader(let result):
            font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold)
            color = NSColor.labelColor
            text = systemHeaderText(for: columnID, result: result)

        case .session(let session):
            font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            text = sessionText(for: columnID, session: session)
            if columnID.rawValue == "Status" {
                color = session.status.color
            } else {
                color = NSColor.labelColor
            }
        }

        cell.textField?.font = font
        cell.textField?.textColor = color
        cell.textField?.stringValue = text
        return cell
    }

    private func makeTextField() -> NSTextField {
        let tf = NSTextField()
        tf.isBordered = false
        tf.drawsBackground = false
        tf.isEditable = false
        tf.lineBreakMode = .byTruncatingTail
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    // MARK: - Cell text helpers

    private func systemHeaderText(for column: NSUserInterfaceItemIdentifier, result: PollResult) -> String {
        let stats = result.systemStats
        switch column.rawValue {
        case "CPU%":
            return String(format: "%.0f", stats.cpuPercent)
        case "MEM":
            return String(format: "%.1fG / %.0fG", Double(stats.memUsed) / (1024*1024*1024), Double(stats.memTotal) / (1024*1024*1024))
        default:
            return ""
        }
    }

    private func sessionText(for column: NSUserInterfaceItemIdentifier, session: ClaudeSession) -> String {
        switch column.rawValue {
        case "Project":
            return session.isMainSession ? "\(session.projectName) (main)" : session.projectName
        case "PID":
            return session.pid
        case "Status":
            return session.status.label
        case "CPU%":
            return String(format: "%.1f", session.cpu)
        case "MEM":
            return session.mem
        case "Uptime":
            return session.uptime
        case "Activity":
            return session.activity
        default:
            return ""
        }
    }
}
