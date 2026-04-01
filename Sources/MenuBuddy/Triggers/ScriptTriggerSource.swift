import Foundation

// MARK: - Script Trigger Source

/// Runs executable scripts from ~/.menubuddy/triggers/ and parses their JSON
/// output into TriggerEvents and TriggerMetrics.
///
/// Drop any executable file into the triggers directory. The script should
/// print JSON to stdout in this format:
///
/// ```json
/// {
///   "name": "Stock Monitor",
///   "interval": 60,
///   "trigger": {
///     "indicator": "📈",
///     "quips": ["AAPL up 5%!", "stonks!"],
///     "mood": "🤑",
///     "eyeOverride": "$",
///     "duration": 30
///   },
///   "metrics": [
///     { "label": "AAPL", "value": "$189", "alert": false, "trend": "↑" }
///   ]
/// }
/// ```
///
/// - `name`: display name (optional, defaults to filename)
/// - `interval`: polling interval in seconds (optional, default 60)
/// - `trigger`: if present, fires a TriggerEvent (all fields optional except indicator)
/// - `metrics`: if present, shown in the status strip
///
/// Scripts can be written in any language (bash, python, node, etc.).
final class ScriptTriggerSource: TriggerSource {
    let id: String
    private(set) var displayName: String
    var isEnabled: Bool = true
    var onTrigger: ((TriggerEvent) -> Void)?

    private let scriptPath: String
    private var timer: Timer?
    private var pollInterval: TimeInterval = 60
    private(set) var latestMetrics: [TriggerMetric] = []

    var currentMetrics: [TriggerMetric] { latestMetrics }

    init(scriptPath: String) {
        self.scriptPath = scriptPath
        let filename = (scriptPath as NSString).lastPathComponent
        self.id = "script.\(filename)"
        self.displayName = (filename as NSString).deletingPathExtension
    }

    func start() {
        // Run once immediately, then schedule polling
        poll()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Polling

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    private func poll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            guard let output = self.runScript() else { return }
            guard let data = output.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return }

            DispatchQueue.main.async {
                self.processOutput(json)
            }
        }
    }

    private func runScript() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: scriptPath)
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())

        // Pass useful environment variables
        var env = ProcessInfo.processInfo.environment
        env["MENUBUDDY_TRIGGERS_DIR"] = ScriptTriggerSource.triggersDirectory
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }

    private func processOutput(_ json: [String: Any]) {
        // Update display name if provided
        if let name = json["name"] as? String, !name.isEmpty {
            displayName = name
        }

        // Update poll interval if changed
        if let interval = json["interval"] as? Double, interval >= 5 {
            let changed = interval != pollInterval
            pollInterval = interval
            if changed { scheduleTimer() }
        }

        // Parse metrics
        if let metricsArray = json["metrics"] as? [[String: Any]] {
            latestMetrics = metricsArray.compactMap { m in
                guard let label = m["label"] as? String,
                      let value = m["value"] as? String else { return nil }
                return TriggerMetric(
                    label: label,
                    value: value,
                    alert: m["alert"] as? Bool ?? false,
                    trend: m["trend"] as? String ?? ""
                )
            }
        }

        // Parse and fire trigger event
        if let trigger = json["trigger"] as? [String: Any],
           let indicator = trigger["indicator"] as? String {
            let event = TriggerEvent(
                sourceId: id,
                indicator: indicator,
                quips: trigger["quips"] as? [String] ?? [],
                mood: trigger["mood"] as? String,
                eyeOverride: trigger["eyeOverride"] as? String,
                duration: trigger["duration"] as? TimeInterval ?? 30
            )
            onTrigger?(event)
        }
    }

    // MARK: - Directory Management

    static var triggersDirectory: String {
        let dir = NSHomeDirectory() + "/.menubuddy/triggers"
        return dir
    }

    /// Scans the triggers directory and returns a ScriptTriggerSource for each
    /// executable file found.
    static func discoverScripts() -> [ScriptTriggerSource] {
        let dir = triggersDirectory
        let fm = FileManager.default

        // Create directory if it doesn't exist
        if !fm.fileExists(atPath: dir) {
            try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }

        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return [] }

        return files.compactMap { filename in
            // Skip hidden files and non-executables
            guard !filename.hasPrefix(".") else { return nil }
            let path = (dir as NSString).appendingPathComponent(filename)
            guard fm.isExecutableFile(atPath: path) else { return nil }
            return ScriptTriggerSource(scriptPath: path)
        }
    }
}
