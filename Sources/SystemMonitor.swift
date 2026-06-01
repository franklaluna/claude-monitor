import Foundation

// MARK: - System Monitor

final class SystemMonitor {
    private var prevUser: UInt64 = 0
    private var prevSystem: UInt64 = 0
    private var prevIdle: UInt64 = 0
    private var prevNice: UInt64 = 0
    private var hasPreviousSample = false

    func sample() -> SystemStats {
        let cpu = sampleCPU()
        let (used, total) = sampleMemory()
        return SystemStats(cpuPercent: cpu, memUsed: used, memTotal: total)
    }

    // MARK: - CPU via host_statistics

    private func sampleCPU() -> Double {
        var size = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        var cpuLoad = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let user   = UInt64(cpuLoad.cpu_ticks.0)
        let system = UInt64(cpuLoad.cpu_ticks.1)
        let idle   = UInt64(cpuLoad.cpu_ticks.2)
        let nice   = UInt64(cpuLoad.cpu_ticks.3)

        defer {
            prevUser = user
            prevSystem = system
            prevIdle = idle
            prevNice = nice
            hasPreviousSample = true
        }

        guard hasPreviousSample else { return 0 }

        let dUser   = Double(user - prevUser)
        let dSystem = Double(system - prevSystem)
        let dIdle   = Double(idle - prevIdle)
        let dNice   = Double(nice - prevNice)

        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return 0 }

        return (dUser + dSystem + dNice) / total * 100.0
    }

    // MARK: - Memory via host_statistics64

    private func sampleMemory() -> (used: UInt64, total: UInt64) {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return (0, 0) }

        let pageSize = UInt64(vm_kernel_page_size)
        let active     = UInt64(vmStats.active_count) * pageSize
        let wire       = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize

        let used  = active + wire + compressed
        let total = ProcessInfo.processInfo.physicalMemory

        return (used, total)
    }
}
