import AppKit

// MARK: - Menu Bar Controller

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let detector = ProcessDetector()
    private let sysMonitor = SystemMonitor()
    private lazy var menuBuilder = MenuBuilder(
        target: self,
        toggleLoginSelector: #selector(toggleLaunchAtLogin),
        showDetailsSelector: #selector(openDetailWindow)
    )
    private var timer: Timer?
    private var detailWindowController: DetailWindowController?
    private var lastResult: PollResult?
    private let touchBarManager = TouchBarManager()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            updateButtonTitle(cpu: 0, mem: "0G", status: .stopped)
        }

        statusItem.menu = menuBuilder.build(result: PollResult(
            sessions: [], systemStats: SystemStats(cpuPercent: 0, memUsed: 0, memTotal: 0),
            overallStatus: .stopped
        ))
        touchBarManager.setup()
    }

    func start() {
        let t = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        t.tolerance = 0.5
        RunLoop.current.add(t, forMode: .common)
        timer = t
        refresh()
    }

    // MARK: - Poll cycle

    private func refresh() {
        let sessions = detector.poll()
        let stats = sysMonitor.sample()

        let overallStatus: ClaudeStatus
        if sessions.isEmpty {
            overallStatus = .stopped
        } else {
            let statuses = sessions.map(\.status)
            if statuses.contains(.working) { overallStatus = .working }
            else if statuses.contains(.thinking) { overallStatus = .thinking }
            else { overallStatus = .idle }
        }

        let totalCPU = sessions.map(\.cpu).reduce(0, +)
        let result = PollResult(
            sessions: sessions, systemStats: stats, overallStatus: overallStatus
        )
        lastResult = result

        DispatchQueue.main.async {
            if self.statusItem.button != nil {
                self.updateButtonTitle(cpu: totalCPU, mem: stats.memUsedString, status: overallStatus)
            }
            self.statusItem.menu = self.menuBuilder.build(result: result)
            self.detailWindowController?.update(result: result)
            self.touchBarManager.update(result: result)
        }
    }

    private func updateButtonTitle(cpu: Double, mem: String, status: ClaudeStatus) {
        guard let button = statusItem.button else { return }
        let title = String(format: "C %4.1f%%  %@", cpu, mem)
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: status.color
            ]
        )
        button.toolTip = "Claude: \(status.label)"
    }

    // MARK: - Detail window

    @objc private func openDetailWindow() {
        if detailWindowController == nil {
            detailWindowController = DetailWindowController()
        }
        if let result = lastResult {
            detailWindowController?.update(result: result)
        }
        detailWindowController?.showWindow(nil)
        detailWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Login item

    @objc private func toggleLaunchAtLogin() {
        if isLoginItemEnabled() {
            removeLoginItem()
        } else {
            addLoginItem()
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

    private func addLoginItem() {
        let appPath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application \"System Events\" to make login item at end with properties {path:\"\(appPath)\", hidden:false}"]
        task.launch()
        task.waitUntilExit()
    }

    private func removeLoginItem() {
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", "tell application \"System Events\" to delete every login item whose name is \"ClaudeMonitor\""]
        task.launch()
        task.waitUntilExit()
    }
}
