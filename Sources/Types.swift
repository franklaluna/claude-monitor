import AppKit

// MARK: - Claude Status

enum ClaudeStatus: String {
    case stopped  // No Claude process running
    case idle     // Waiting for user input
    case thinking // Model is reasoning (status="busy" but no tool execution detected)
    case working  // Executing tools (caffeinate child or recent log writes)

    var color: NSColor {
        switch self {
        case .stopped:  return .systemRed
        case .idle:     return .systemGreen
        case .thinking: return .systemYellow
        case .working:  return .systemOrange
        }
    }

    var label: String {
        switch self {
        case .stopped:  return "Stopped"
        case .idle:     return "Idle"
        case .thinking: return "Thinking"
        case .working:  return "Working"
        }
    }

    var emoji: String {
        switch self {
        case .stopped:  return "\u{1F534}"
        case .idle:     return "\u{1F7E2}"
        case .thinking: return "\u{1F7E1}"
        case .working:  return "\u{1F7E0}"
        }
    }
}

// MARK: - Claude Session

struct ClaudeSession {
    let pid: String
    let status: ClaudeStatus
    let cpu: Double
    let mem: String
    let uptime: String
    let projectName: String
    let sessionId: String
    let activity: String
    let isMainSession: Bool
}

// MARK: - System Stats

struct SystemStats {
    let cpuPercent: Double
    let memUsed: UInt64
    let memTotal: UInt64

    var memPercent: Double {
        guard memTotal > 0 else { return 0 }
        return Double(memUsed) / Double(memTotal) * 100.0
    }

    var memUsedString: String {
        let gb = Double(memUsed) / (1024 * 1024 * 1024)
        if gb >= 10 {
            return String(format: "%.0fG", gb)
        } else {
            return String(format: "%.1fG", gb)
        }
    }

    var memTotalString: String {
        let gb = Double(memTotal) / (1024 * 1024 * 1024)
        return String(format: "%.0fG", gb)
    }
}

// MARK: - Poll Result

struct PollResult {
    let sessions: [ClaudeSession]
    let systemStats: SystemStats
    let overallStatus: ClaudeStatus
}
