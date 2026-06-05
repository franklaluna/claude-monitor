import AppKit

// MARK: - Touch Bar Manager

final class TouchBarManager: NSObject, NSTouchBarDelegate {

    private var touchBarField: NSTextField?
    private var stripField: NSTextField?

    // MARK: - Setup

    func setup() {
        enableControlStrip()
        setupTouchBar()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func enableControlStrip() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DFRFoundation.framework", RTLD_LAZY) else {
            print("[ClaudeMonitor] Failed to load DFRFoundation")
            return
        }
        guard let fn = dlsym(handle, "DFRElementSetControlStripPresenceForIdentifier") else {
            print("[ClaudeMonitor] DFRElementSetControlStripPresenceForIdentifier not found")
            return
        }
        typealias SetFn = @convention(c) (CFString, Bool) -> Void
        let setControlStrip = unsafeBitCast(fn, to: SetFn.self)
        setControlStrip("com.claudemonitor.status" as CFString, true)
    }

    private func setupTouchBar() {
        let bar = NSTouchBar()
        bar.delegate = self
        bar.defaultItemIdentifiers = [.claudeMonitorSummary]
        bar.principalItemIdentifier = .claudeMonitorSummary
        bar.customizationIdentifier = "com.claudemonitor.touchbar"
        bar.customizationAllowedItemIdentifiers = [.claudeMonitorSummary, .controlStripStatus]
        NSApp.touchBar = bar
    }

    // MARK: - Update

    func update(result: PollResult) {
        let color = result.overallStatus.color

        touchBarField?.stringValue = formatSummary(result: result)
        touchBarField?.textColor = color

        stripField?.stringValue = formatStrip(result: result)
        stripField?.textColor = color
    }

    // MARK: - NSTouchBarDelegate

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case .claudeMonitorSummary:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 30))
            field.isBordered = false
            field.drawsBackground = false
            field.isEditable = false
            field.alignment = .center
            field.font = NSFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
            field.stringValue = "ClaudeMonitor"
            field.textColor = NSColor.secondaryLabelColor

            item.view = field
            self.touchBarField = field
            return item

        case .controlStripStatus:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "Claude Status"
            let view = NSView(frame: NSRect(x: 0, y: 0, width: 64, height: 30))
            let field = NSTextField(frame: view.bounds)
            field.isBordered = false
            field.drawsBackground = false
            field.isEditable = false
            field.alignment = .center
            field.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
            field.stringValue = "--%"
            field.textColor = NSColor.secondaryLabelColor
            field.autoresizingMask = [.width, .height]
            view.addSubview(field)
            item.view = view
            self.stripField = field
            return item

        default:
            return nil
        }
    }

    // MARK: - Formatting

    private func formatSummary(result: PollResult) -> String {
        let stats = result.systemStats
        let cpuStr = String(format: "%.0f%%", stats.cpuPercent)
        let memStr = stats.memUsedString
        let sessionCount = result.sessions.count
        let statusLabel = result.overallStatus.label

        let sessionInfo: String
        if sessionCount == 0 {
            sessionInfo = "No sessions"
        } else if sessionCount == 1 {
            let s = result.sessions[0]
            sessionInfo = "\(s.projectName) \(s.status.emoji) \(String(format: "%.1f%%", s.cpu))"
        } else {
            sessionInfo = "\(sessionCount) sessions"
        }

        return "C \(cpuStr)  \(memStr)  |  \(sessionInfo)  \(statusLabel)"
    }

    private func formatStrip(result: PollResult) -> String {
        let cpu = String(format: "%.0f%%", result.systemStats.cpuPercent)
        return "C \(cpu)"
    }
}

// MARK: - Touch Bar Identifiers

private extension NSTouchBarItem.Identifier {
    static let claudeMonitorSummary = NSTouchBarItem.Identifier("com.claudemonitor.summary")
    static let controlStripStatus = NSTouchBarItem.Identifier("com.claudemonitor.status")
}
