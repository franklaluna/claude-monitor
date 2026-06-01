import Foundation

// MARK: - Process Detector

final class ProcessDetector {
    private let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    private var lastKnownTool: String = ""

    func poll() -> [ClaudeSession] {
        let processes = runPS()
        guard !processes.isEmpty else { return [] }

        let claudePIDs = processes.map(\.pid)
        let sessionData = readSessionFiles(pids: claudePIDs)
        let caffeinateParents = findCaffeinateParents(pids: claudePIDs)
        let (hasRecentActivity, lastTool) = checkRecentToolActivity()

        if !lastTool.isEmpty { lastKnownTool = lastTool }

        let maxCPU = processes.map(\.cpu).max() ?? 0

        return processes.map { p in
            let session = sessionData[p.pid]
            let isWorking = caffeinateParents.contains(p.pid) || hasRecentActivity
            let status = determineStatus(
                psCPU: p.cpu, sessionStatus: session?.status,
                isWorking: isWorking
            )
            let activity = describeActivity(
                status: status, isWorking: isWorking,
                sessionStatus: session?.status, lastTool: lastKnownTool
            )
            let projectName = session?.cwd.flatMap { extractProjectName($0) } ?? "unknown"
            let isMain = p.cpu == maxCPU && maxCPU > 0

            return ClaudeSession(
                pid: p.pid, status: status, cpu: p.cpu, mem: p.mem,
                uptime: p.uptime, projectName: projectName,
                sessionId: session?.sessionId ?? "",
                activity: activity, isMainSession: isMain
            )
        }
    }

    // MARK: - ps aux

    private struct RawProcess {
        let pid: String; let cpu: Double; let mem: String
        let uptime: String; let command: String
    }

    private func runPS() -> [RawProcess] {
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c",
            "ps aux 2>/dev/null | grep -iE '(^|[^/])claude[^/]|/claude( |$)' | grep -v grep | grep -v 'osascript' | grep -v 'ClaudeMonitor'"
        ]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8),
              !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let noisePatterns = ["hook", "plugin", "observe", "worker-service", "mcp-server",
                             "run-with-flags", "plugin-hook", "bun-runner", "bun "]

        var results: [RawProcess] = []
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard parts.count >= 11 else { continue }

            let cmd = parts[10...].joined(separator: " ")
            let isNoise = noisePatterns.contains { cmd.contains($0) }
            guard !isNoise else { continue }

            results.append(RawProcess(
                pid: parts[1], cpu: Double(parts[2]) ?? 0,
                mem: parts[3], uptime: parts[9], command: cmd
            ))
        }
        return results
    }

    // MARK: - Session files (~/.claude/sessions/<PID>.json)

    private struct SessionInfo {
        let status: String?
        let cwd: String?
        let sessionId: String?
    }

    private func readSessionFiles(pids: [String]) -> [String: SessionInfo] {
        var result: [String: SessionInfo] = [:]
        let sessionsDir = "\(homeDir)/.claude/sessions"

        for pid in pids {
            let path = "\(sessionsDir)/\(pid).json"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            result[pid] = SessionInfo(
                status: json["status"] as? String,
                cwd: json["cwd"] as? String,
                sessionId: json["sessionId"] as? String
            )
        }
        return result
    }

    // MARK: - Caffeinate detection (pgrep -P <claude_pid> caffeinate)

    private func findCaffeinateParents(pids: [String]) -> Set<String> {
        guard !pids.isEmpty else { return [] }

        // Batch check: for each claude pid, check if it has a caffeinate child
        var result = Set<String>()
        for pid in pids {
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-c", "pgrep -P \(pid) caffeinate 2>/dev/null || true"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.launch()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !output.isEmpty {
                result.insert(pid)
            }
        }
        return result
    }

    // MARK: - Tool activity via cost-tracker.log mtime

    private func checkRecentToolActivity() -> (active: Bool, lastTool: String) {
        let logPath = "\(homeDir)/.claude/cost-tracker.log"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: logPath),
              let modDate = attrs[.modificationDate] as? Date else {
            return (false, "")
        }

        let ago = Date().timeIntervalSince(modDate)
        guard ago < 3 else { return (false, "") }

        if let data = try? Data(contentsOf: URL(fileURLWithPath: logPath)),
           let content = String(data: data, encoding: .utf8) {
            let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            if let lastLine = lines.last,
               let toolRange = lastLine.range(of: "tool=") {
                let toolPart = String(lastLine[toolRange.upperBound...])
                let tool = toolPart.components(separatedBy: " ").first ?? ""
                return (true, tool)
            }
        }
        return (true, "")
    }

    // MARK: - Status determination

    private func determineStatus(psCPU: Double, sessionStatus: String?, isWorking: Bool) -> ClaudeStatus {
        if isWorking { return .working }
        if sessionStatus == "busy" { return .thinking }
        if sessionStatus == "idle" { return .idle }
        // CPU fallback
        if psCPU > 10 { return .thinking }
        return .idle
    }

    private func describeActivity(status: ClaudeStatus, isWorking: Bool, sessionStatus: String?, lastTool: String) -> String {
        switch status {
        case .stopped:  return "Not running"
        case .idle:     return "Idle"
        case .thinking: return "Thinking..."
        case .working:
            if !lastTool.isEmpty { return "Running: \(lastTool)" }
            return "Working..."
        }
    }

    private func extractProjectName(_ cwd: String) -> String {
        return cwd.components(separatedBy: "/").last ?? cwd
    }
}
