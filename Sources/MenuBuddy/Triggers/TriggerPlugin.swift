import Foundation

// MARK: - Trigger Event

/// A standardized reaction event produced by any trigger source.
/// This is the universal output format — all plugins speak this language.
struct TriggerEvent {
    /// Which plugin produced this event.
    let sourceId: String
    /// Emoji shown in the menu bar next to the companion face (e.g. "🔥", "📈").
    let indicator: String
    /// Possible quips for speech bubble / menu bar text. One is picked at random.
    let quips: [String]
    /// Override the companion mood emoji (nil = don't change).
    let mood: String?
    /// Override the menu bar face's eye character (nil = normal eyes).
    let eyeOverride: String?
    /// How long the indicator stays in the menu bar (seconds).
    let duration: TimeInterval

    init(sourceId: String,
         indicator: String,
         quips: [String],
         mood: String? = nil,
         eyeOverride: String? = nil,
         duration: TimeInterval = 30) {
        self.sourceId = sourceId
        self.indicator = indicator
        self.quips = quips
        self.mood = mood
        self.eyeOverride = eyeOverride
        self.duration = duration
    }
}

// MARK: - Trigger Metric

/// A live metric a plugin can provide for the status strip.
struct TriggerMetric {
    /// Short label (e.g. "CPU", "AAPL").
    let label: String
    /// Formatted value (e.g. "72%", "$189.50").
    let value: String
    /// When true, the pill highlights in orange.
    let alert: Bool
    /// Change indicator: "↑", "↓", or "".
    let trend: String

    init(label: String, value: String, alert: Bool = false, trend: String = "") {
        self.label = label
        self.value = value
        self.alert = alert
        self.trend = trend
    }
}

// MARK: - Trigger Source Protocol

/// Protocol for pluggable trigger sources.
///
/// Implement this to create a new data source that drives companion reactions.
/// Each source runs independently and calls `onTrigger` when something happens.
///
/// Example sources: system monitor, stock prices, weather, CI/CD status, etc.
protocol TriggerSource: AnyObject {
    /// Unique identifier (e.g. "system", "stock", "weather").
    var id: String { get }

    /// Localized display name shown in Settings.
    var displayName: String { get }

    /// Whether this source is active. Toggled by the user in Settings.
    var isEnabled: Bool { get set }

    /// Start monitoring. Implementations should call `onTrigger` on the main
    /// thread whenever an event fires.
    func start()

    /// Stop monitoring and release resources.
    func stop()

    /// Callback invoked when an event fires. Set by TriggerManager.
    var onTrigger: ((TriggerEvent) -> Void)? { get set }

    /// Optional: live metrics for the status strip. Return empty array if none.
    var currentMetrics: [TriggerMetric] { get }
}

/// Default implementation for sources that don't provide metrics.
extension TriggerSource {
    var currentMetrics: [TriggerMetric] { [] }
}
