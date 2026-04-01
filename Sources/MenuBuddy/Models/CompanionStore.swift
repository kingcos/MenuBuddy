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

    /// Emoji reflecting the companion's current mood based on system state.
    var mood: String {
        guard let s = systemSnapshot else { return "😊" }
        if s.memFree < 0.15 { return "😵" }
        if s.cpuUsage > 0.70 { return "😰" }
        if let bat = s.batteryPct, bat < 0.20, !s.isCharging { return "🪫" }
        if s.netBytesPerSec > 5_000_000 { return "🚀" }
        if s.cpuUsage < 0.10 && s.netBytesPerSec < 1024 { return "😴" }
        return "😊"
    }

    private let systemMonitor = SystemMonitor()

    private init() {
        userId = getMachineId()
        muted = UserDefaults.standard.bool(forKey: "companion.muted")
        petCount = UserDefaults.standard.integer(forKey: "companion.petCount")

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
                self?.systemSnapshot = snapshot
            }
        }
        systemMonitor.start()
    }

    private func updateSystemIndicator(_ event: SystemEvent) {
        switch event {
        case .cpuHigh:         systemIndicator = "🔥"
        case .memHigh:         systemIndicator = "🧠"
        case .netFast:         systemIndicator = "⚡"
        case .netSlow:         systemIndicator = "🐌"
        case .batteryLow:      systemIndicator = "🪫"
        case .batteryCharging: systemIndicator = "⚡"
        }
        onSystemEvent?(event)
        // Clear after 30 seconds
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
            name: defaultNames.randomElement() ?? "Buddy",
            personality: "curious and cheerful",
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
            personality: companion.soul.personality,
            hatchedAt: companion.soul.hatchedAt
        )
        saveSoul(newSoul)
        companion = Companion(bones: companion.bones, soul: newSoul)
    }

    private func saveSoul(_ soul: CompanionSoul) {
        if let data = try? JSONEncoder().encode(soul) {
            UserDefaults.standard.set(data, forKey: soulKey)
        }
    }
}

private let defaultNames = [
    "Pip", "Mochi", "Biscuit", "Noodle", "Dumpling",
    "Pebble", "Sprout", "Twig", "Acorn", "Button",
    "Wobble", "Fudge", "Nugget", "Pretzel", "Waffle"
]
