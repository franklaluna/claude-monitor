import AppKit

// MARK: - Menu Builder

final class MenuBuilder {
    private weak var target: NSObject?
    private let selector: Selector
    private let showDetailsSelector: Selector

    init(target: NSObject, toggleLoginSelector: Selector, showDetailsSelector: Selector) {
        self.target = target
        self.selector = toggleLoginSelector
        self.showDetailsSelector = showDetailsSelector
    }

    func build(result: PollResult) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        buildSystemHeader(menu: menu, stats: result.systemStats)
        menu.addItem(.separator())

        if result.sessions.isEmpty {
            let item = NSMenuItem(title: "No Claude processes", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            buildSessionList(menu: menu, sessions: result.sessions)
        }

        menu.addItem(.separator())
        buildFooter(menu: menu)
        return menu
    }

    // MARK: - System header

    private func buildSystemHeader(menu: NSMenu, stats: SystemStats) {
        let title = String(format: "System  CPU: %.0f%%  MEM: %@ / %@ (%.0f%%)",
                           stats.cpuPercent, stats.memUsedString,
                           stats.memTotalString, stats.memPercent)
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        menu.addItem(item)
    }

    // MARK: - Session list

    private func buildSessionList(menu: NSMenu, sessions: [ClaudeSession]) {
        let sorted = sessions.sorted { $0.cpu > $1.cpu }

        for session in sorted {
            let mainLabel = session.isMainSession
                ? "\(session.projectName) (main)"
                : session.projectName
            let title = String(format: "%@  %@  %.1f%%",
                               mainLabel, session.status.emoji, session.cpu)

            let sessionItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            sessionItem.isEnabled = false
            sessionItem.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                    .foregroundColor: session.status.color
                ]
            )
            menu.addItem(sessionItem)

            let details = [
                "PID \(session.pid)  MEM \(session.mem)%  Uptime \(session.uptime)",
                session.activity
            ]
            for detail in details {
                let detailItem = NSMenuItem(title: "    \(detail)", action: nil, keyEquivalent: "")
                detailItem.isEnabled = false
                detailItem.attributedTitle = NSAttributedString(
                    string: "    \(detail)",
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
                        .foregroundColor: NSColor.tertiaryLabelColor
                    ]
                )
                menu.addItem(detailItem)
            }

            if session.pid != sorted.last?.pid {
                menu.addItem(.separator())
            }
        }
    }

    // MARK: - Footer

    private func buildFooter(menu: NSMenu) {
        let detailItem = NSMenuItem(
            title: "Show Details…",
            action: showDetailsSelector,
            keyEquivalent: ""
        )
        detailItem.target = target
        menu.addItem(detailItem)
        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: selector,
            keyEquivalent: ""
        )
        launchItem.target = target
        launchItem.state = isLoginItemEnabled() ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(NSMenuItem(
            title: "Quit ClaudeMonitor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
    }
}

private func isLoginItemEnabled() -> Bool {
    let task = Process()
    task.launchPath = "/bin/bash"
    task.arguments = ["-c", "osascript -e 'tell application \"System Events\" to get the name of every login item' 2>/dev/null | grep -q ClaudeMonitor && echo 1 || echo 0"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()
    task.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
}
