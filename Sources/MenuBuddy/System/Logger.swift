import Foundation

// MARK: - MenuBuddy Logger

/// Simple file-based logger. Writes to ~/.menubuddy/logs/.
/// Keeps the last N days of logs, auto-rotates daily.
final class BuddyLogger {
    static let shared = BuddyLogger()

    enum Level: String {
        case debug = "DEBUG"
        case info  = "INFO"
        case warn  = "WARN"
        case error = "ERROR"
    }

    private let logDir: String
    private let maxDays = 7
    private var fileHandle: FileHandle?
    private var currentDate: String = ""
    private let queue = DispatchQueue(label: "com.menubuddy.logger", qos: .utility)
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private init() {
        logDir = NSHomeDirectory() + "/.menubuddy/logs"
        let fm = FileManager.default
        if !fm.fileExists(atPath: logDir) {
            try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        }
        cleanOldLogs()
    }

    // MARK: - Public API

    func debug(_ message: String, source: String = "app") {
        log(.debug, message, source: source)
    }

    func info(_ message: String, source: String = "app") {
        log(.info, message, source: source)
    }

    func warn(_ message: String, source: String = "app") {
        log(.warn, message, source: source)
    }

    func error(_ message: String, source: String = "app") {
        log(.error, message, source: source)
    }

    /// Returns the path to today's log file.
    var todayLogPath: String {
        let date = dateFormatter.string(from: Date())
        return (logDir as NSString).appendingPathComponent("menubuddy-\(date).log")
    }

    /// Returns the log directory path.
    var logsDirectory: String { logDir }

    // MARK: - Private

    private func log(_ level: Level, _ message: String, source: String) {
        queue.async { [self] in
            let now = Date()
            let date = dateFormatter.string(from: now)
            let time = timeFormatter.string(from: now)

            // Rotate if day changed
            if date != currentDate {
                fileHandle?.closeFile()
                fileHandle = nil
                currentDate = date
                cleanOldLogs()
            }

            // Open file handle if needed
            if fileHandle == nil {
                let path = (logDir as NSString).appendingPathComponent("menubuddy-\(date).log")
                if !FileManager.default.fileExists(atPath: path) {
                    FileManager.default.createFile(atPath: path, contents: nil)
                }
                fileHandle = FileHandle(forWritingAtPath: path)
                fileHandle?.seekToEndOfFile()
            }

            let line = "[\(time)] [\(level.rawValue)] [\(source)] \(message)\n"
            if let data = line.data(using: .utf8) {
                fileHandle?.write(data)
            }
        }
    }

    private func cleanOldLogs() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: logDir) else { return }
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxDays, to: Date()) ?? Date()
        let cutoffStr = dateFormatter.string(from: cutoff)

        for file in files where file.hasPrefix("menubuddy-") && file.hasSuffix(".log") {
            // Extract date from filename: menubuddy-2026-04-01.log
            let dateStr = file.replacingOccurrences(of: "menubuddy-", with: "")
                              .replacingOccurrences(of: ".log", with: "")
            if dateStr < cutoffStr {
                try? fm.removeItem(atPath: (logDir as NSString).appendingPathComponent(file))
            }
        }
    }
}

// MARK: - Convenience global

let logger = BuddyLogger.shared
