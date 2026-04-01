import Foundation
import IOKit.ps

// MARK: - System State

enum SystemEvent {
    case cpuHigh       // CPU > 70%
    case memHigh       // Memory pressure high
    case netFast       // Network throughput > 5 MB/s
    case netSlow       // No network activity when expected
    case batteryLow    // Battery < 20% and not charging
    case batteryCharging
}

// MARK: - System Monitor

/// Polls CPU, network, and battery state on a background queue.
/// Publishes events via the `onEvent` callback on the main thread.
final class SystemMonitor {
    var onEvent: ((SystemEvent) -> Void)?

    private var timer: Timer?

    // CPU tracking
    private var prevCPUInfo: processor_info_array_t?
    private var prevCPUInfoCount: mach_msg_type_number_t = 0

    // Network tracking
    private var prevNetBytes: UInt64 = 0
    private var prevNetTimestamp: Date = Date()

    func start() {
        guard timer == nil else { return }
        // Sample immediately once, then every 10s
        sample()
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
        let net = networkBytesPerSec()
        let bat = batteryState()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if cpu > 0.70 { self.onEvent?(.cpuHigh) }
            if net > 5_000_000 { self.onEvent?(.netFast) }   // > 5 MB/s
            else if net == 0 && self.prevNetBytes > 0 { self.onEvent?(.netSlow) }
            switch bat {
            case .low: self.onEvent?(.batteryLow)
            case .charging: self.onEvent?(.batteryCharging)
            case .normal, .notPresent: break
            }
        }
        prevNetBytes = net > 0 ? net : prevNetBytes
    }

    // MARK: - CPU

    /// Returns total CPU utilization as a value in [0, 1].
    private func cpuUsage() -> Double {
        var numCPUs: natural_t = 0
        var newInfo: processor_info_array_t?
        var newCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs, &newInfo, &newCount)
        guard result == KERN_SUCCESS, let info = newInfo else { return 0 }

        defer {
            // Free previous info
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
            let user    = Double(info[base + Int(CPU_STATE_USER)]    - prev[base + Int(CPU_STATE_USER)])
            let sys     = Double(info[base + Int(CPU_STATE_SYSTEM)]  - prev[base + Int(CPU_STATE_SYSTEM)])
            let idle    = Double(info[base + Int(CPU_STATE_IDLE)]    - prev[base + Int(CPU_STATE_IDLE)])
            let nice    = Double(info[base + Int(CPU_STATE_NICE)]    - prev[base + Int(CPU_STATE_NICE)])
            let used = user + sys + nice
            let all  = used + idle
            totalUsed += used
            totalAll  += all
        }
        return totalAll > 0 ? totalUsed / totalAll : 0
    }

    // MARK: - Network

    /// Returns total bytes-per-second across all interfaces since last call.
    private func networkBytesPerSec() -> UInt64 {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return 0 }
        defer { freeifaddrs(first) }

        var totalBytes: UInt64 = 0
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = cursor {
            if ifa.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let data = unsafeBitCast(ifa.pointee.ifa_data,
                                         to: UnsafeMutablePointer<if_data>.self)
                totalBytes += UInt64(data.pointee.ifi_ibytes) + UInt64(data.pointee.ifi_obytes)
            }
            cursor = ifa.pointee.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(prevNetTimestamp)
        let delta = totalBytes > prevNetBytes ? totalBytes - prevNetBytes : 0
        prevNetTimestamp = now
        prevNetBytes = totalBytes

        guard elapsed > 0 else { return 0 }
        return UInt64(Double(delta) / elapsed)
    }

    // MARK: - Battery

    private enum BatteryStatus { case normal, low, charging, notPresent }

    private func batteryState() -> BatteryStatus {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []

        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?
                    .takeUnretainedValue() as? [String: Any] else { continue }

            let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let capacity   = desc[kIOPSCurrentCapacityKey] as? Int ?? 100
            let maxCap     = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let pct = maxCap > 0 ? Double(capacity) / Double(maxCap) : 1.0

            if isCharging { return .charging }
            if pct < 0.20 { return .low }
            return .normal
        }
        return .notPresent
    }
}
