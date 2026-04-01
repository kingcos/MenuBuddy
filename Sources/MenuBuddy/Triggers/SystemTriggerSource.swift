import Foundation

// MARK: - System Trigger Source

/// Built-in trigger source that monitors CPU, memory, network, and battery.
/// Wraps the low-level SystemMonitor and emits standardized TriggerEvents.
final class SystemTriggerSource: TriggerSource {
    let id = "system"
    var displayName: String { Strings.triggerSystemName }
    var isEnabled: Bool = true

    var onTrigger: ((TriggerEvent) -> Void)?

    /// The raw SystemMonitor — also exposes snapshots for the status strip.
    let monitor = SystemMonitor()

    /// Latest snapshot, used by CompanionStore for mood and status strip.
    private(set) var snapshot: SystemSnapshot?
    private(set) var prevSnapshot: SystemSnapshot?

    /// Called on main thread after each poll with the latest snapshot.
    var onSnapshot: ((SystemSnapshot) -> Void)?

    var currentMetrics: [TriggerMetric] {
        guard let s = snapshot else { return [] }
        var metrics: [TriggerMetric] = [
            TriggerMetric(
                label: Strings.sysstatCPU,
                value: "\(Int(s.cpuUsage * 100))%\(metricTrend(s.cpuUsage, prevSnapshot?.cpuUsage))",
                alert: s.cpuUsage > 0.70
            ),
            TriggerMetric(
                label: Strings.sysstatMEM,
                value: "\(Int((1 - s.memFree) * 100))%\(metricTrend(1 - s.memFree, prevSnapshot.map { 1 - $0.memFree }))",
                alert: s.memFree < 0.15
            ),
            TriggerMetric(
                label: Strings.sysstatNET,
                value: formatBytes(s.netBytesPerSec),
                alert: false
            ),
        ]
        if let bat = s.batteryPct {
            metrics.append(TriggerMetric(
                label: s.isCharging ? Strings.sysstatCharging : Strings.sysstatBAT,
                value: "\(Int(bat * 100))%",
                alert: bat < 0.20 && !s.isCharging
            ))
        }
        return metrics
    }

    func start() {
        monitor.onEvent = { [weak self] event in
            guard let self else { return }
            let triggerEvent = self.mapEvent(event)
            DispatchQueue.main.async {
                self.onTrigger?(triggerEvent)
            }
        }
        monitor.onSnapshot = { [weak self] snap in
            DispatchQueue.main.async {
                guard let self else { return }
                self.prevSnapshot = self.snapshot
                self.snapshot = snap
                self.onSnapshot?(snap)
            }
        }
        monitor.start()
    }

    func stop() {
        monitor.stop()
    }

    // MARK: - Event Mapping

    private func mapEvent(_ event: SystemEvent) -> TriggerEvent {
        switch event {
        case .cpuHigh:
            return TriggerEvent(
                sourceId: id, indicator: "🔥",
                quips: Strings.cpuHighQuips,
                mood: "😰", eyeOverride: "x"
            )
        case .memHigh:
            return TriggerEvent(
                sourceId: id, indicator: "🧠",
                quips: Strings.memHighQuips,
                mood: "😵", eyeOverride: "~"
            )
        case .netFast:
            return TriggerEvent(
                sourceId: id, indicator: "⚡",
                quips: Strings.netFastQuips,
                mood: "🚀"
            )
        case .netSlow:
            return TriggerEvent(
                sourceId: id, indicator: "🐌",
                quips: Strings.netSlowQuips,
                eyeOverride: "_"
            )
        case .batteryLow:
            return TriggerEvent(
                sourceId: id, indicator: "🪫",
                quips: Strings.batteryLowQuips,
                mood: "🪫", eyeOverride: "."
            )
        case .batteryCharging:
            return TriggerEvent(
                sourceId: id, indicator: "⚡",
                quips: [Strings.batteryChargingQuip]
            )
        case .diskBusy:
            return TriggerEvent(
                sourceId: id, indicator: "💾",
                quips: Strings.diskBusyQuips,
                mood: "💾", eyeOverride: "o"
            )
        }
    }

    // MARK: - Helpers

    private func metricTrend(_ current: Double, _ previous: Double?) -> String {
        guard let previous else { return "" }
        let delta = current - previous
        if delta > 0.05 { return "↑" }
        if delta < -0.05 { return "↓" }
        return ""
    }

    private func formatBytes(_ bps: UInt64) -> String {
        if bps >= 1_000_000 {
            return Strings.sysstatNetMB(Double(bps) / 1_000_000)
        } else {
            return Strings.sysstatNetKB(Double(bps) / 1_000)
        }
    }
}
