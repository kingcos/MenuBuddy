import Foundation

// MARK: - Companion Store

class CompanionStore: ObservableObject {
    static let shared = CompanionStore()

    @Published private(set) var companion: Companion

    private let soulKey = "companion.soul"
    private let mutedKey = "companion.muted"
    private let userId: String

    @Published var muted: Bool {
        didSet {
            UserDefaults.standard.set(muted, forKey: mutedKey)
        }
    }

    private init() {
        userId = getMachineId()
        muted = UserDefaults.standard.bool(forKey: "companion.muted")

        let bones = rollCompanion(userId: userId)
        let soul = CompanionStore.loadOrCreateSoul()

        companion = Companion(bones: bones, soul: soul)
    }

    private static func loadOrCreateSoul() -> CompanionSoul {
        if let data = UserDefaults.standard.data(forKey: "companion.soul"),
           let soul = try? JSONDecoder().decode(CompanionSoul.self, from: data) {
            return soul
        }
        // Generate a new soul with a default name
        let soul = CompanionSoul(
            name: defaultNames.randomElement() ?? "Buddy",
            personality: "curious and cheerful",
            hatchedAt: Date().timeIntervalSince1970
        )
        if let data = try? JSONEncoder().encode(soul) {
            UserDefaults.standard.set(data, forKey: "companion.soul")
        }
        return soul
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
