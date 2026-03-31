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

    private init() {
        userId = getMachineId()
        muted = UserDefaults.standard.bool(forKey: "companion.muted")
        petCount = UserDefaults.standard.integer(forKey: "companion.petCount")

        let bones = rollCompanion(userId: userId)
        let (soul, isNew) = CompanionStore.loadOrCreateSoul()
        isFirstLaunch = isNew

        companion = Companion(bones: bones, soul: soul)
    }

    /// Increments pet count, persists it, and returns any milestone message.
    @discardableResult
    func recordPet() -> String? {
        petCount += 1
        UserDefaults.standard.set(petCount, forKey: petCountKey)
        return milestoneMessage(for: petCount)
    }

    private func milestoneMessage(for count: Int) -> String? {
        switch count {
        case 1:   return "first pet ever! ♥"
        case 5:   return "5 pets! you care!"
        case 10:  return "10 pets. we're bonded."
        case 25:  return "25 pets. best friends."
        case 50:  return "50 pets. legendary friendship."
        case 100: return "100 pets. i am eternal."
        default:  return nil
        }
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
