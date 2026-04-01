import Foundation

// MARK: - Trigger Manager

/// Manages all trigger sources and routes their events to the companion.
///
/// This is the central hub of the plugin system. It:
/// - Holds all registered `TriggerSource` instances
/// - Routes `TriggerEvent`s to the UI layer via callbacks
/// - Aggregates metrics from all sources for the status strip
/// - Persists per-source enabled/disabled state
final class TriggerManager {
    /// All registered trigger sources.
    private(set) var sources: [TriggerSource] = []

    /// Fired on the main thread when any source produces an event.
    var onEvent: ((TriggerEvent) -> Void)?

    /// Fired on the main thread when any source's metrics may have changed.
    /// The argument is the combined metrics from all enabled sources.
    var onMetricsUpdate: (([TriggerMetric]) -> Void)?

    /// Register a new trigger source. If a source with the same id already
    /// exists, the old one is stopped and replaced.
    func register(_ source: TriggerSource) {
        if let idx = sources.firstIndex(where: { $0.id == source.id }) {
            sources[idx].stop()
            sources[idx] = source
        } else {
            sources.append(source)
        }

        // Restore persisted enabled state
        let key = "trigger.\(source.id).enabled"
        if let saved = UserDefaults.standard.object(forKey: key) as? Bool {
            source.isEnabled = saved
        }

        // Wire up the event callback
        source.onTrigger = { [weak self] event in
            self?.handleEvent(event)
        }

        if source.isEnabled {
            source.start()
        }
    }

    /// Unregister and stop a source by id.
    func unregister(id: String) {
        if let idx = sources.firstIndex(where: { $0.id == id }) {
            sources[idx].stop()
            sources.remove(at: idx)
        }
    }

    /// Enable or disable a source. Persists the choice.
    func setEnabled(_ enabled: Bool, for sourceId: String) {
        guard let source = sources.first(where: { $0.id == sourceId }) else { return }
        source.isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "trigger.\(sourceId).enabled")
        if enabled {
            source.start()
        } else {
            source.stop()
        }
    }

    /// Returns combined metrics from all enabled sources.
    var allMetrics: [TriggerMetric] {
        sources.filter(\.isEnabled).flatMap(\.currentMetrics)
    }

    /// Stop all sources.
    func stopAll() {
        sources.forEach { $0.stop() }
    }

    // MARK: - Private

    private func handleEvent(_ event: TriggerEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
