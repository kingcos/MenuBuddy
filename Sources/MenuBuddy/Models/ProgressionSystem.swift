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

    // Anti-cheat: daily XP tracking
    var dailyXPDate: String?                   // "yyyy-MM-dd" of current daily tracking
    var dailyXPEarned: Int = 0                 // XP earned today (resets at midnight)

    // Recent XP events (keep last 50 for display)
    var recentEvents: [XPEvent] = []
}

// MARK: - Anti-Cheat Configuration

enum AntiCheat {
    /// Maximum XP earnable per calendar day (excludes daily login bonus).
    static let dailyXPCap: Int = 200

    /// Minimum seconds between XP grants from the same source.
    static let cooldowns: [String: TimeInterval] = [
        "pet": 2,           // can't spam-pet faster than 2s
        "trigger": 10,      // system events at most every 10s
        "appContext": 30,    // app switch XP at most every 30s
        "llm": 15,          // LLM reactions at most every 15s
    ]
}

/// Core progression engine — pure logic, no UI dependencies.
/// All access goes through CompanionStore which is main-thread-only (ObservableObject).
final class ProgressionSystem {
    static let shared = ProgressionSystem()

    private let stateKey = "progression.state"
    internal private(set) var state: ProgressionState

    /// Last grant timestamp per source (in-memory only, resets on app launch).
    private var lastGrantTime: [String: Date] = [:]

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
    /// Enforces per-source cooldown and daily cap.
    @discardableResult
    func grantXP(_ reward: XPReward, source: String) -> LevelUpInfo? {
        return grantXP(reward.rawValue, source: source)
    }

    /// Grants arbitrary XP amount with anti-cheat enforcement.
    @discardableResult
    func grantXP(_ amount: Int, source: String) -> LevelUpInfo? {
        let now = Date()

        // Per-source cooldown check
        if let cooldown = AntiCheat.cooldowns[source],
           let lastTime = lastGrantTime[source],
           now.timeIntervalSince(lastTime) < cooldown {
            return nil  // too soon, reject
        }

        // Reset daily tracking at midnight
        let today = Self.dateString(now)
        if state.dailyXPDate != today {
            state.dailyXPDate = today
            state.dailyXPEarned = 0
        }

        // Daily cap check (daily login bonus is exempt)
        if source != "daily" && state.dailyXPEarned >= AntiCheat.dailyXPCap {
            return nil  // daily cap reached
        }

        // Clamp amount to remaining daily allowance (daily login exempt)
        let effectiveAmount: Int
        if source == "daily" {
            effectiveAmount = amount
        } else {
            effectiveAmount = min(amount, AntiCheat.dailyXPCap - state.dailyXPEarned)
        }
        guard effectiveAmount > 0 else { return nil }

        // Record cooldown
        lastGrantTime[source] = now

        let oldLevel = level
        state.totalXP += effectiveAmount
        state.dailyXPEarned += effectiveAmount

        // Track event
        let event = XPEvent(amount: effectiveAmount, source: source, timestamp: now.timeIntervalSince1970)
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

    /// How much daily XP remains before hitting the cap.
    var dailyXPRemaining: Int {
        let today = Self.dateString(Date())
        guard state.dailyXPDate == today else { return AntiCheat.dailyXPCap }
        return max(0, AntiCheat.dailyXPCap - state.dailyXPEarned)
    }

    /// Claim daily login XP. Returns nil if already claimed today.
    func claimDailyXP() -> LevelUpInfo? {
        let today = Self.dateString(Date())
        guard state.lastDailyXPDate != today else { return nil }
        state.lastDailyXPDate = today
        return grantXP(.dailyLogin, source: "daily")
    }

    private static let dateFmt: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    private static func dateString(_ date: Date) -> String {
        dateFmt.string(from: date)
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

    /// Deduct XP (used for species change cost). Returns false if insufficient XP.
    @discardableResult
    func deductXP(_ amount: Int) -> Bool {
        guard state.totalXP >= amount else { return false }
        state.totalXP -= amount
        save()
        return true
    }

    /// Reset all allocated attribute points (refunds them).
    func resetAttributePoints() {
        state.attributeBonuses = [:]
        save()
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

    func save() {
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
