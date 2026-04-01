import Foundation

// MARK: - Companion Store

class CompanionStore: ObservableObject {
    static let shared = CompanionStore()

    @Published private(set) var companion: Companion

    private let soulKey = "companion.soul"
    private let mutedKey = "companion.muted"
    private let petCountKey = "companion.petCount"
    private let userId: String

    @Published var muted: Bool {
        didSet {
            UserDefaults.standard.set(muted, forKey: mutedKey)
        }
    }

    /// Show quips in the menu bar alongside the companion face.
    @Published var menuBarQuips: Bool {
        didSet { UserDefaults.standard.set(menuBarQuips, forKey: "companion.menuBarQuips") }
    }

    /// Do Not Disturb — suppresses menu bar quips during specified hours.
    @Published var dndEnabled: Bool {
        didSet { UserDefaults.standard.set(dndEnabled, forKey: "companion.dndEnabled") }
    }
    @Published var dndFrom: Int {
        didSet { UserDefaults.standard.set(dndFrom, forKey: "companion.dndFrom") }
    }
    @Published var dndTo: Int {
        didSet { UserDefaults.standard.set(dndTo, forKey: "companion.dndTo") }
    }

    /// The quip currently displayed in the menu bar (nil = none).
    @Published private(set) var menuBarQuip: String?

    /// Whether we're currently in the DND window.
    var isDND: Bool {
        guard dndEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if dndFrom <= dndTo {
            return hour >= dndFrom && hour < dndTo
        } else {
            // Wraps past midnight (e.g., 22:00 → 08:00)
            return hour >= dndFrom || hour < dndTo
        }
    }

    func showMenuBarQuip(_ text: String) {
        guard menuBarQuips, !isDND else { return }
        menuBarQuip = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            if self?.menuBarQuip == text { self?.menuBarQuip = nil }
        }
    }

    /// Total lifetime pet count — @Published so the footer updates live.
    @Published private(set) var petCount: Int

    /// True if this is the very first launch (soul was just created now).
    let isFirstLaunch: Bool

    /// Current system state indicator shown in the menu bar (e.g. "🔥" when CPU is high).
    @Published private(set) var systemIndicator: String = ""

    /// Called (on main thread) whenever a system event fires. PopoverView wires this to the engine.
    var onSystemEvent: ((SystemEvent) -> Void)?

    /// A wake quip to show next time the popover opens (cleared after use).
    private(set) var pendingWakeQuip: String?

    /// Returns a time-of-day greeting if the popover hasn't been opened today yet, nil otherwise.
    func consumeDailyGreeting() -> String? {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "companion.lastGreetedDay"
        let lastDay = UserDefaults.standard.object(forKey: key) as? Date
        guard lastDay == nil || lastDay! < today else { return nil }
        UserDefaults.standard.set(today, forKey: key)
        return Strings.timeOfDayQuip
    }

    func setWakeQuip(_ quip: String) {
        pendingWakeQuip = quip
        NotificationCenter.default.post(name: .companionWoke, object: quip)
    }

    func consumeWakeQuip() -> String? {
        defer { pendingWakeQuip = nil }
        return pendingWakeQuip
    }

    /// Latest system metrics snapshot; nil until first poll fires.
    @Published private(set) var systemSnapshot: SystemSnapshot?
    /// The snapshot before the current one — used to compute trends.
    private(set) var prevSystemSnapshot: SystemSnapshot?

    /// Rolling CPU usage history (up to 8 values); used to render a sparkline.
    @Published private(set) var cpuHistory: [Double] = []

    /// Set to true by resetCompanion() so the next popover open shows a welcome quip.
    private(set) var pendingResetWelcome = false

    func consumeResetWelcome() -> Bool {
        defer { pendingResetWelcome = false }
        return pendingResetWelcome
    }

    /// Emoji reflecting the companion's current mood based on system state.
    var mood: String {
        guard let s = systemSnapshot else { return "😊" }
        if s.memFree < 0.15 { return "😵" }
        if s.cpuUsage > 0.70 { return "😰" }
        if let bat = s.batteryPct, bat < 0.20, !s.isCharging { return "🪫" }
        if s.diskBytesPerSec > 50_000_000 { return "💾" }
        if s.netBytesPerSec > 5_000_000 { return "🚀" }
        if s.cpuUsage < 0.10 && s.netBytesPerSec < 1024 { return "😴" }
        return "😊"
    }

    private let systemMonitor = SystemMonitor()
    private var menuBarQuipTimer: Timer?

    private init() {
        userId = getMachineId()
        muted = UserDefaults.standard.bool(forKey: "companion.muted")
        petCount = UserDefaults.standard.integer(forKey: "companion.petCount")
        menuBarQuips = UserDefaults.standard.object(forKey: "companion.menuBarQuips") as? Bool ?? true
        dndEnabled = UserDefaults.standard.bool(forKey: "companion.dndEnabled")
        dndFrom = UserDefaults.standard.object(forKey: "companion.dndFrom") as? Int ?? 22
        dndTo = UserDefaults.standard.object(forKey: "companion.dndTo") as? Int ?? 8

        let bones = rollCompanion(userId: userId)
        let (soul, isNew) = CompanionStore.loadOrCreateSoul()
        isFirstLaunch = isNew

        companion = Companion(bones: bones, soul: soul)

        systemMonitor.onEvent = { [weak self] event in
            DispatchQueue.main.async {
                self?.updateSystemIndicator(event)
            }
        }
        systemMonitor.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self else { return }
                self.prevSystemSnapshot = self.systemSnapshot
                self.systemSnapshot = snapshot
                if self.cpuHistory.count >= 8 { self.cpuHistory.removeFirst() }
                self.cpuHistory.append(snapshot.cpuUsage)
            }
        }
        systemMonitor.start()
        scheduleMenuBarQuip()
    }

    private func scheduleMenuBarQuip() {
        menuBarQuipTimer?.invalidate()
        menuBarQuipTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 120...300), repeats: false) { [weak self] _ in
            guard let self else { return }
            if !self.muted {
                let quips = Strings.speciesQuips(for: self.companion.species) + Strings.genericQuips
                if let q = quips.randomElement() {
                    self.showMenuBarQuip(q)
                }
            }
            self.scheduleMenuBarQuip()
        }
    }

    private func updateSystemIndicator(_ event: SystemEvent) {
        switch event {
        case .cpuHigh:         systemIndicator = "🔥"
        case .memHigh:         systemIndicator = "🧠"
        case .netFast:         systemIndicator = "⚡"
        case .netSlow:         systemIndicator = "🐌"
        case .batteryLow:      systemIndicator = "🪫"
        case .batteryCharging: systemIndicator = "⚡"
        case .diskBusy:        systemIndicator = "💾"
        }
        onSystemEvent?(event)

        // Show a short quip in the menu bar
        let quip: String? = {
            switch event {
            case .cpuHigh:         return Strings.cpuHighQuips.randomElement()
            case .memHigh:         return Strings.memHighQuips.randomElement()
            case .netFast:         return Strings.netFastQuips.randomElement()
            case .netSlow:         return Strings.netSlowQuips.randomElement()
            case .batteryLow:      return Strings.batteryLowQuips.randomElement()
            case .batteryCharging: return Strings.batteryChargingQuip
            case .diskBusy:        return Strings.diskBusyQuips.randomElement()
            }
        }()
        if let q = quip { showMenuBarQuip(q) }

        // Clear indicator after 30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.systemIndicator = ""
        }
    }

    /// Increments pet count, persists it, and returns any milestone message.
    @discardableResult
    func recordPet() -> String? {
        petCount += 1
        UserDefaults.standard.set(petCount, forKey: petCountKey)
        return milestoneMessage(for: petCount)
    }

    private func milestoneMessage(for count: Int) -> String? {
        Strings.milestone(count)
    }

    private static func loadOrCreateSoul() -> (CompanionSoul, isNew: Bool) {
        if let data = UserDefaults.standard.data(forKey: "companion.soul"),
           let soul = try? JSONDecoder().decode(CompanionSoul.self, from: data) {
            return (soul, false)
        }
        let soul = CompanionSoul(
            name: Strings.defaultNames.randomElement() ?? "Buddy",
            hatchedAt: Date().timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(soul) {
            UserDefaults.standard.set(data, forKey: "companion.soul")
        }
        return (soul, true)
    }

    func rename(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let newSoul = CompanionSoul(
            name: trimmed,
            hatchedAt: companion.soul.hatchedAt
        )
        saveSoul(newSoul)
        companion = Companion(bones: companion.bones, soul: newSoul)
    }

    /// Wipes the current soul and creates a fresh one. Companion bones stay the same (machine-tied).
    func resetCompanion() {
        UserDefaults.standard.removeObject(forKey: soulKey)
        UserDefaults.standard.removeObject(forKey: petCountKey)
        UserDefaults.standard.removeObject(forKey: "companion.lastGreetedDay")
        petCount = 0
        let (soul, _) = CompanionStore.loadOrCreateSoul()
        companion = Companion(bones: companion.bones, soul: soul)
        pendingResetWelcome = true
    }

    private func saveSoul(_ soul: CompanionSoul) {
        if let data = try? JSONEncoder().encode(soul) {
            UserDefaults.standard.set(data, forKey: soulKey)
        }
    }
}

