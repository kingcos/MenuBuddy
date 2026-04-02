import Foundation

// MARK: - Progression System
// XP-based leveling with attribute bonuses and cosmetic slot unlocks.

/// XP rewards for various actions.
enum XPReward: Int {
    case pet = 5
    case dailyLogin = 20
    case triggerEvent = 3
    case appContext = 1
    case llmReaction = 8
    case milestone = 15
    case levelUpBonus = 50
}

/// A single XP gain event for history tracking.
struct XPEvent: Codable {
    let amount: Int
    let source: String
    let timestamp: TimeInterval
}

/// Persisted progression state for a companion.
struct ProgressionState: Codable {
    var totalXP: Int = 0
    var attributeBonuses: [String: Int] = [:]  // StatName.rawValue -> bonus points
    var unlockedSlots: [String] = []           // CosmeticSlot.rawValue values
    var lastDailyXPDate: String?               // "yyyy-MM-dd" of last daily XP claim
    var levelUpsSeen: Int = 0                  // highest level the user has been notified about

    // Recent XP events (keep last 50 for display)
    var recentEvents: [XPEvent] = []
}

/// Core progression engine — pure logic, no UI dependencies.
final class ProgressionSystem {
    static let shared = ProgressionSystem()

    private let stateKey = "progression.state"
    private(set) var state: ProgressionState

    private init() {
        if let data = UserDefaults.standard.data(forKey: stateKey),
           let saved = try? JSONDecoder().decode(ProgressionState.self, from: data) {
            state = saved
        } else {
            state = ProgressionState()
        }
    }

    // MARK: - Level Calculation

    /// Level from total XP.  Level = floor(sqrt(totalXP / 10)).
    /// Level 0 = 0 XP, Level 1 = 10 XP, Level 2 = 40 XP, Level 3 = 90 XP, etc.
    var level: Int {
        Self.level(for: state.totalXP)
    }

    static func level(for xp: Int) -> Int {
        guard xp > 0 else { return 0 }
        return Int(floor(sqrt(Double(xp) / 10.0)))
    }

    /// XP required to reach a given level.
    static func xpRequired(for level: Int) -> Int {
        level * level * 10
    }

    /// XP needed to go from current level to next.
    var xpForCurrentLevel: Int {
        Self.xpRequired(for: level)
    }

    var xpForNextLevel: Int {
        Self.xpRequired(for: level + 1)
    }

    /// Progress within current level (0.0 to 1.0).
    var levelProgress: Double {
        let floor = xpForCurrentLevel
        let ceiling = xpForNextLevel
        let range = ceiling - floor
        guard range > 0 else { return 0 }
        return Double(state.totalXP - floor) / Double(range)
    }

    /// Total attribute bonus points available (2 per level).
    var totalAttributePoints: Int {
        level * 2
    }

    /// Points already allocated.
    var allocatedAttributePoints: Int {
        state.attributeBonuses.values.reduce(0, +)
    }

    /// Unallocated points available.
    var availableAttributePoints: Int {
        max(0, totalAttributePoints - allocatedAttributePoints)
    }

    // MARK: - XP Granting

    /// Grants XP and returns a level-up message if the level changed.
    @discardableResult
    func grantXP(_ reward: XPReward, source: String) -> LevelUpInfo? {
        return grantXP(reward.rawValue, source: source)
    }

    /// Grants arbitrary XP amount.
    @discardableResult
    func grantXP(_ amount: Int, source: String) -> LevelUpInfo? {
        let oldLevel = level
        state.totalXP += amount

        // Track event
        let event = XPEvent(amount: amount, source: source, timestamp: Date().timeIntervalSince1970)
        state.recentEvents.append(event)
        if state.recentEvents.count > 50 {
            state.recentEvents.removeFirst(state.recentEvents.count - 50)
        }

        let newLevel = level
        save()

        if newLevel > oldLevel {
            let info = LevelUpInfo(
                oldLevel: oldLevel,
                newLevel: newLevel,
                newSlots: slotsUnlockedAt(level: newLevel),
                attributePointsGained: (newLevel - oldLevel) * 2
            )
            state.levelUpsSeen = newLevel
            save()
            return info
        }
        return nil
    }

    /// Claim daily login XP. Returns nil if already claimed today.
    func claimDailyXP() -> LevelUpInfo? {
        let today = Self.dateString(Date())
        guard state.lastDailyXPDate != today else { return nil }
        state.lastDailyXPDate = today
        return grantXP(.dailyLogin, source: "daily")
    }

    private static func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    // MARK: - Attribute Bonuses

    /// Allocate a bonus point to a stat. Returns false if no points available.
    @discardableResult
    func allocatePoint(to stat: StatName) -> Bool {
        guard availableAttributePoints > 0 else { return false }
        let key = stat.rawValue
        state.attributeBonuses[key, default: 0] += 1
        save()
        return true
    }

    /// Get bonus for a specific stat.
    func bonus(for stat: StatName) -> Int {
        state.attributeBonuses[stat.rawValue, default: 0]
    }

    /// Get effective stat value (base + bonus), capped at 100.
    func effectiveStat(_ stat: StatName, base: Int) -> Int {
        min(100, base + bonus(for: stat))
    }

    // MARK: - Slot Unlocking

    /// Cosmetic slots unlock at specific levels.
    static let slotUnlockLevels: [(slot: CosmeticSlot, level: Int)] = [
        (.hat, 0),         // hat available from start (existing feature)
        (.eye, 2),         // eye style changes at level 2
        (.accessory, 3),   // accessories at level 3
        (.aura, 5),        // auras at level 5
        (.frame, 8),       // frames at level 8
    ]

    func isSlotUnlocked(_ slot: CosmeticSlot) -> Bool {
        guard let entry = Self.slotUnlockLevels.first(where: { $0.slot == slot }) else { return false }
        return level >= entry.level
    }

    func unlockLevel(for slot: CosmeticSlot) -> Int {
        Self.slotUnlockLevels.first(where: { $0.slot == slot })?.level ?? 0
    }

    private func slotsUnlockedAt(level: Int) -> [CosmeticSlot] {
        Self.slotUnlockLevels
            .filter { $0.level == level }
            .map { $0.slot }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    /// Reset all progression (used when companion is reset).
    func reset() {
        state = ProgressionState()
        save()
    }
}

// MARK: - Level Up Info

struct LevelUpInfo {
    let oldLevel: Int
    let newLevel: Int
    let newSlots: [CosmeticSlot]
    let attributePointsGained: Int
}
