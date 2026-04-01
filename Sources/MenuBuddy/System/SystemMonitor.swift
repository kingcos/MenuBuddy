import Foundation
import IOKit.ps

// MARK: - System State

enum SystemEvent {
    case cpuHigh        // CPU > 70%
    case memHigh        // Free memory < 15% of physical RAM
    case netFast        // Network throughput > 5 MB/s
    case netSlow        // Network dropped to 0 after sustained activity
    case batteryLow     // Battery < 20% and not charging
    case batteryCharging
}

/// Point-in-time snapshot of system metrics, delivered alongside events.
struct SystemSnapshot {
    let cpuUsage: Double        // [0, 1]
    let memFree: Double         // [0, 1] fraction of RAM that is free
    let netBytesPerSec: UInt64  // combined in+out bytes/sec (non-loopback)
    let batteryPct: Double?     // nil on desktops/VMs with no battery
    let isCharging: Bool
}

// MARK: - System Monitor

/// Polls CPU, network, battery, and memory on the main run loop.
/// Delivers SystemEvent callbacks on the main thread.
final class SystemMonitor {
    var onEvent: ((SystemEvent) -> Void)?
    /// Fired after every poll with the latest raw metrics.
    var onSnapshot: ((SystemSnapshot) -> Void)?

    private var timer: Timer?

    // CPU tracking
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0

    // Network tracking (cumulative bytes; updated by networkBytesPerSec only)
    private var prevNetCumulative: UInt64 = 0
    private var prevNetTimestamp: Date = .distantPast
    private var prevNetWasActive = false   // was throughput > 0 last sample?

    func start() {
        guard timer == nil else { return }
        // First sample after 5s so CPU delta is meaningful
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.sample()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Sampling

    private func sample() {
        let cpu = cpuUsage()
        let net = networkBytesPerSec()   // also updates prevNetCumulative/prevNetTimestamp
        let mem = memoryPressure()
        let (bat, batteryPct, isCharging) = batteryStateDetailed()

        // Detect slow-net: had traffic last sample, none now
        let isNetSlow = (net == 0 && prevNetWasActive)
        prevNetWasActive = net > 1024   // >1 KB/s counts as active

        if cpu > 0.70        { onEvent?(.cpuHigh) }
        if mem < 0.15        { onEvent?(.memHigh) }
        if net > 5_000_000   { onEvent?(.netFast) }
        else if isNetSlow    { onEvent?(.netSlow) }
        switch bat {
        case .low:           onEvent?(.batteryLow)
        case .charging:      onEvent?(.batteryCharging)
        case .normal, .notPresent: break
        }

        onSnapshot?(SystemSnapshot(
            cpuUsage: cpu,
            memFree: mem,
            netBytesPerSec: net,
            batteryPct: batteryPct,
            isCharging: isCharging
        ))
    }

    // MARK: - CPU

    /// Returns total CPU utilization in [0, 1] across all cores.
    private func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var newInfo: processor_info_array_t?
        var newCount: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                   &numCPUs, &newInfo, &newCount) == KERN_SUCCESS,
              let info = newInfo else { return 0 }

        defer {
            if let prev = prevCPUInfo {
                vm_deallocate(mach_task_self_,
                              vm_address_t(bitPattern: prev),
                              vm_size_t(Int(prevCPUInfoCount) * MemoryLayout<integer_t>.stride))
            }
            prevCPUInfo = info
            prevCPUInfoCount = newCount
        }

        guard let prev = prevCPUInfo else { return 0 }

        var totalUsed: Double = 0
        var totalAll: Double = 0
        for i in 0..<Int(numCPUs) {
            let base = Int(CPU_STATE_MAX) * i
            let user = Double(info[base + Int(CPU_STATE_USER)]   - prev[base + Int(CPU_STATE_USER)])
            let sys  = Double(info[base + Int(CPU_STATE_SYSTEM)] - prev[base + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[base + Int(CPU_STATE_IDLE)]   - prev[base + Int(CPU_STATE_IDLE)])
            let nice = Double(info[base + Int(CPU_STATE_NICE)]   - prev[base + Int(CPU_STATE_NICE)])
            totalUsed += user + sys + nice
            totalAll  += user + sys + nice + idle
        }
        return totalAll > 0 ? totalUsed / totalAll : 0
    }

    // MARK: - Memory

    /// Returns ratio of free memory to total physical RAM in [0, 1].
    private func memoryPressure() -> Double {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 1.0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let free = UInt64(vmStats.free_count) * pageSize
        let total = UInt64(ProcessInfo.processInfo.physicalMemory)
        return total > 0 ? Double(free) / Double(total) : 1.0
    }

    // MARK: - Network

    /// Returns bytes-per-second across all non-loopback interfaces since last call.
    /// Updates `prevNetCumulative` and `prevNetTimestamp`.
    private func networkBytesPerSec() -> UInt64 {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return 0 }
        defer { freeifaddrs(first) }

        var totalBytes: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            let name = String(cString: ifa.pointee.ifa_name)
            // Skip loopback
            if !name.hasPrefix("lo"),
               ifa.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(ifa.pointee.ifa_data,
                                         to: UnsafeMutablePointer<if_data>.self)
                totalBytes += UInt64(data.pointee.ifi_ibytes) + UInt64(data.pointee.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(prevNetTimestamp)
        let delta = totalBytes > prevNetCumulative ? totalBytes - prevNetCumulative : 0
        // Update cumulative trackers (only modified here)
        prevNetCumulative = totalBytes
        prevNetTimestamp = now

        guard elapsed > 0 else { return 0 }
        return UInt64(Double(delta) / elapsed)
    }

    // MARK: - Battery

    private enum BatteryStatus { case normal, low, charging, notPresent }

    /// Returns (status, batteryPct or nil, isCharging).
    private func batteryStateDetailed() -> (BatteryStatus, Double?, Bool) {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?
                    .takeUnretainedValue() as? [String: Any] else { continue }

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let capacity   = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let maxCap     = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let pct = maxCap > 0 ? Double(capacity) / Double(maxCap) : 1.0

            if isCharging { return (.charging, pct, true) }
            if pct < 0.20 { return (.low, pct, false) }
            return (.normal, pct, false)
        }
        return (.notPresent, nil, false)
    }
}
