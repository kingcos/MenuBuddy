import Foundation
import Combine

// MARK: - Trigger Manager

/// Manages all trigger sources and routes their events to the companion.
final class TriggerManager: ObservableObject {
    /// All registered trigger sources.
    @Published private(set) var sources: [TriggerSource] = []

    /// Fired on the main thread when any source produces an event.
    var onEvent: ((TriggerEvent) -> Void)?

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
        if enabled { source.start() } else { source.stop() }
        objectWillChange.send()
    }

    /// Rescan ~/.menubuddy/triggers/ for new or removed scripts.
    func rescanScripts() {
        let discovered = ScriptTriggerSource.discoverScripts()
        let existingScriptIds = Set(sources.compactMap { ($0 as? ScriptTriggerSource)?.id })
        let discoveredIds = Set(discovered.map(\.id))

        // Remove scripts that were deleted from disk
        for id in existingScriptIds where !discoveredIds.contains(id) {
            unregister(id: id)
        }
        // Add new scripts
        for script in discovered where !existingScriptIds.contains(script.id) {
            register(script)
        }
    }

    /// Returns combined metrics from all enabled sources.
    var allMetrics: [TriggerMetric] {
        sources.filter(\.isEnabled).flatMap(\.currentMetrics)
    }

    func stopAll() {
        sources.forEach { $0.stop() }
    }

    private func handleEvent(_ event: TriggerEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.onEvent?(event)
        }
    }
}
