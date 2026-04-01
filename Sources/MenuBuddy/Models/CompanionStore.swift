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

    /// Current indicator shown in the menu bar (e.g. "🔥" when CPU is high).
    @Published private(set) var systemIndicator: String = ""

    /// Current eye override from the active trigger (e.g. "x" for stress).
    @Published private(set) var triggerEyeOverride: String?

    /// Current mood override from triggers (nil = use default mood logic).
    @Published private(set) var triggerMood: String?

    /// Called (on main thread) whenever a trigger event fires. PopoverView wires this to the engine.
    var onTriggerEvent: ((TriggerEvent) -> Void)?

    /// The trigger manager — holds all registered plugin sources.
    let triggerManager = TriggerManager()

    /// The built-in system trigger source (exposed for snapshot access).
    let systemSource = SystemTriggerSource()

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

    /// Set to true by resetCompanion() so the next popover open shows a welcome quip.
    private(set) var pendingResetWelcome = false

    func consumeResetWelcome() -> Bool {
        defer { pendingResetWelcome = false }
        return pendingResetWelcome
    }

    /// Emoji reflecting the companion's current mood.
    /// Trigger-sourced mood takes priority; falls back to system snapshot heuristic.
    var mood: String {
        if let m = triggerMood { return m }
        guard let s = systemSnapshot else { return "😊" }
        if s.memFree < 0.15 { return "😵" }
        if s.cpuUsage > 0.70 { return "😰" }
        if let bat = s.batteryPct, bat < 0.20, !s.isCharging { return "🪫" }
        if s.netBytesPerSec > 5_000_000 { return "🚀" }
        if s.cpuUsage < 0.10 && s.netBytesPerSec < 1024 { return "😴" }
        return "😊"
    }

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

        // Wire system source snapshots
        systemSource.onSnapshot = { [weak self] snapshot in
            guard let self else { return }
            self.prevSystemSnapshot = self.systemSnapshot
            self.systemSnapshot = snapshot
        }

        // Wire trigger manager events
        triggerManager.onEvent = { [weak self] event in
            self?.handleTriggerEvent(event)
        }

        // Register built-in system trigger source
        triggerManager.register(systemSource)
        scheduleMenuBarQuip(delay: Double.random(in: 15...30))
    }

    private func scheduleMenuBarQuip(delay: TimeInterval? = nil) {
        menuBarQuipTimer?.invalidate()
        let interval = delay ?? Double.random(in: 120...300)
        menuBarQuipTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
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

    /// Handles a standardized trigger event from any source.
    private func handleTriggerEvent(_ event: TriggerEvent) {
        // Update menu bar indicator
        systemIndicator = event.indicator
        triggerEyeOverride = event.eyeOverride
        triggerMood = event.mood

        // Notify UI (speech bubble in popover)
        onTriggerEvent?(event)

        // Show a quip in the menu bar
        if let q = event.quips.randomElement() {
            showMenuBarQuip(q)
        }

        // Clear indicator after duration
        let indicator = event.indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + event.duration) { [weak self] in
            guard let self else { return }
            // Only clear if it hasn't been replaced by a newer event
            if self.systemIndicator == indicator {
                self.systemIndicator = ""
                self.triggerEyeOverride = nil
                self.triggerMood = nil
            }
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

