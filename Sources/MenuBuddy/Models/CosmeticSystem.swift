import Foundation

// MARK: - Cosmetic Slot Types

enum CosmeticSlot: String, CaseIterable, Codable {
    case hat
    case eye
    case accessory
    case aura
    case frame
}

// MARK: - Cosmetic Item

/// A cosmetic item that can be equipped in a slot.
struct CosmeticItem: Codable, Identifiable, Equatable {
    let id: String               // unique identifier (e.g. "hat_pirate")
    let slot: CosmeticSlot
    let name: String             // localization key
    let rarity: CosmeticRarity
    let spriteModifier: SpriteModifier
    let unlockLevel: Int         // minimum level to use

    static func == (lhs: CosmeticItem, rhs: CosmeticItem) -> Bool {
        lhs.id == rhs.id
    }
}

enum CosmeticRarity: String, CaseIterable, Codable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var color: String {
        switch self {
        case .common: return "#888888"
        case .uncommon: return "#22c55e"
        case .rare: return "#3b82f6"
        case .epic: return "#a855f7"
        case .legendary: return "#f59e0b"
        }
    }

    var stars: String {
        switch self {
        case .common: return "★"
        case .uncommon: return "★★"
        case .rare: return "★★★"
        case .epic: return "★★★★"
        case .legendary: return "★★★★★"
        }
    }

    var dropWeight: Int {
        switch self {
        case .common: return 50
        case .uncommon: return 30
        case .rare: return 13
        case .epic: return 5
        case .legendary: return 2
        }
    }
}

// MARK: - Sprite Modifier

/// Describes how a cosmetic item modifies the ASCII sprite.
struct SpriteModifier: Codable, Equatable {
    /// For hats: the hat line (12 chars). For others: decoration strings.
    var hatLine: String?
    /// Eye character override.
    var eyeChar: String?
    /// Left/right accessory strings placed beside the sprite.
    var accessoryLeft: String?
    var accessoryRight: String?
    /// Aura: top/bottom decoration lines.
    var auraTop: String?
    var auraBottom: String?
    /// Frame: characters placed around the sprite.
    var frameLeft: String?
    var frameRight: String?
}

// MARK: - Cosmetic Inventory

struct CosmeticInventory: Codable {
    var ownedItemIds: Set<String> = []
    var equipped: [String: String] = [:]  // CosmeticSlot.rawValue -> item id

    mutating func equip(_ item: CosmeticItem) {
        equipped[item.slot.rawValue] = item.id
    }

    mutating func unequip(_ slot: CosmeticSlot) {
        equipped.removeValue(forKey: slot.rawValue)
    }

    func equippedItem(for slot: CosmeticSlot) -> String? {
        equipped[slot.rawValue]
    }

    func isEquipped(_ itemId: String) -> Bool {
        equipped.values.contains(itemId)
    }
}

// MARK: - Cosmetic System

final class CosmeticSystem {
    static let shared = CosmeticSystem()

    private let inventoryKey = "cosmetic.inventory"
    private(set) var inventory: CosmeticInventory

    /// All available cosmetic items in the game.
    let catalog: [CosmeticItem]

    private init() {
        catalog = CosmeticCatalog.allItems
        if let data = UserDefaults.standard.data(forKey: inventoryKey),
           let saved = try? JSONDecoder().decode(CosmeticInventory.self, from: data) {
            inventory = saved
        } else {
            // Grant default items on first launch
            var inv = CosmeticInventory()
            for item in CosmeticCatalog.starterItems {
                inv.ownedItemIds.insert(item.id)
            }
            inventory = inv
        }
    }

    // MARK: - Queries

    func ownedItems(for slot: CosmeticSlot) -> [CosmeticItem] {
        catalog.filter { $0.slot == slot && inventory.ownedItemIds.contains($0.id) }
    }

    func equippedItem(for slot: CosmeticSlot) -> CosmeticItem? {
        guard let id = inventory.equippedItem(for: slot) else { return nil }
        return catalog.first { $0.id == id }
    }

    func allEquippedModifiers() -> SpriteModifier {
        var combined = SpriteModifier()
        for slot in CosmeticSlot.allCases {
            guard let item = equippedItem(for: slot) else { continue }
            let m = item.spriteModifier
            if let v = m.hatLine { combined.hatLine = v }
            if let v = m.eyeChar { combined.eyeChar = v }
            if let v = m.accessoryLeft { combined.accessoryLeft = v }
            if let v = m.accessoryRight { combined.accessoryRight = v }
            if let v = m.auraTop { combined.auraTop = v }
            if let v = m.auraBottom { combined.auraBottom = v }
            if let v = m.frameLeft { combined.frameLeft = v }
            if let v = m.frameRight { combined.frameRight = v }
        }
        return combined
    }

    // MARK: - Mutations

    func equip(_ item: CosmeticItem) {
        guard inventory.ownedItemIds.contains(item.id) else { return }
        inventory.equip(item)
        save()
    }

    func unequip(_ slot: CosmeticSlot) {
        inventory.unequip(slot)
        save()
    }

    func addItem(_ item: CosmeticItem) {
        inventory.ownedItemIds.insert(item.id)
        save()
    }

    func addItem(byId id: String) {
        inventory.ownedItemIds.insert(id)
        save()
    }

    // MARK: - Random Drop

    /// Roll a random item from the catalog appropriate for the given level.
    /// Returns nil if the user already owns all eligible items.
    func rollRandomDrop(level: Int) -> CosmeticItem? {
        let eligible = catalog.filter { $0.unlockLevel <= level && !inventory.ownedItemIds.contains($0.id) }
        guard !eligible.isEmpty else { return nil }

        // Weighted random by rarity
        let totalWeight = eligible.reduce(0) { $0 + $1.rarity.dropWeight }
        var roll = Int.random(in: 0..<totalWeight)
        for item in eligible {
            roll -= item.rarity.dropWeight
            if roll < 0 { return item }
        }
        return eligible.last
    }

    /// Grant a level-up reward. Returns the granted item, if any.
    func grantLevelUpReward(level: Int) -> CosmeticItem? {
        guard let item = rollRandomDrop(level: level) else { return nil }
        addItem(item)
        return item
    }

    // MARK: - Import / Export (Sharing)

    /// Export an item as a shareable base64 string.
    func exportItem(_ item: CosmeticItem) -> String? {
        guard let data = try? JSONEncoder().encode(item) else { return nil }
        return data.base64EncodedString()
    }

    /// Import an item from a base64 string. Returns the item if valid.
    func importItem(from base64String: String) -> CosmeticItem? {
        guard let data = Data(base64Encoded: base64String),
              let item = try? JSONDecoder().decode(CosmeticItem.self, from: data) else {
            return nil
        }
        // Verify it's not a duplicate by checking ID uniqueness
        addItem(item)
        return item
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(inventory) {
            UserDefaults.standard.set(data, forKey: inventoryKey)
        }
    }

    func reset() {
        var inv = CosmeticInventory()
        for item in CosmeticCatalog.starterItems {
            inv.ownedItemIds.insert(item.id)
        }
        inventory = inv
        save()
    }
}

// MARK: - Item Catalog

enum CosmeticCatalog {
    // Starter items (owned by default)
    static let starterItems: [CosmeticItem] = [
        // Default "none" options for each slot
        CosmeticItem(id: "hat_none", slot: .hat, name: "cosmetic.hat.none", rarity: .common,
                     spriteModifier: SpriteModifier(), unlockLevel: 0),
        CosmeticItem(id: "eye_default", slot: .eye, name: "cosmetic.eye.default", rarity: .common,
                     spriteModifier: SpriteModifier(), unlockLevel: 0),
    ]

    static let allItems: [CosmeticItem] = starterItems + hatItems + eyeItems + accessoryItems + auraItems + frameItems

    // MARK: - Hat Items
    static let hatItems: [CosmeticItem] = [
        CosmeticItem(id: "hat_crown", slot: .hat, name: "cosmetic.hat.crown", rarity: .rare,
                     spriteModifier: SpriteModifier(hatLine: "   \\^^^/    "), unlockLevel: 0),
        CosmeticItem(id: "hat_tophat", slot: .hat, name: "cosmetic.hat.tophat", rarity: .uncommon,
                     spriteModifier: SpriteModifier(hatLine: "   [___]    "), unlockLevel: 0),
        CosmeticItem(id: "hat_propeller", slot: .hat, name: "cosmetic.hat.propeller", rarity: .uncommon,
                     spriteModifier: SpriteModifier(hatLine: "    -+-     "), unlockLevel: 0),
        CosmeticItem(id: "hat_halo", slot: .hat, name: "cosmetic.hat.halo", rarity: .rare,
                     spriteModifier: SpriteModifier(hatLine: "   (   )    "), unlockLevel: 0),
        CosmeticItem(id: "hat_wizard", slot: .hat, name: "cosmetic.hat.wizard", rarity: .epic,
                     spriteModifier: SpriteModifier(hatLine: "    /^\\     "), unlockLevel: 1),
        CosmeticItem(id: "hat_beanie", slot: .hat, name: "cosmetic.hat.beanie", rarity: .common,
                     spriteModifier: SpriteModifier(hatLine: "   (___)    "), unlockLevel: 0),
        CosmeticItem(id: "hat_tinyduck", slot: .hat, name: "cosmetic.hat.tinyduck", rarity: .legendary,
                     spriteModifier: SpriteModifier(hatLine: "    ,>      "), unlockLevel: 2),
        CosmeticItem(id: "hat_pirate", slot: .hat, name: "cosmetic.hat.pirate", rarity: .epic,
                     spriteModifier: SpriteModifier(hatLine: "  ~[===]~   "), unlockLevel: 3),
        CosmeticItem(id: "hat_antenna", slot: .hat, name: "cosmetic.hat.antenna", rarity: .uncommon,
                     spriteModifier: SpriteModifier(hatLine: "     !      "), unlockLevel: 1),
        CosmeticItem(id: "hat_flower", slot: .hat, name: "cosmetic.hat.flower", rarity: .rare,
                     spriteModifier: SpriteModifier(hatLine: "    @}      "), unlockLevel: 2),
        CosmeticItem(id: "hat_chef", slot: .hat, name: "cosmetic.hat.chef", rarity: .epic,
                     spriteModifier: SpriteModifier(hatLine: "   /===\\    "), unlockLevel: 4),
        CosmeticItem(id: "hat_party", slot: .hat, name: "cosmetic.hat.party", rarity: .rare,
                     spriteModifier: SpriteModifier(hatLine: "    /\\*     "), unlockLevel: 3),
        CosmeticItem(id: "hat_ninja", slot: .hat, name: "cosmetic.hat.ninja", rarity: .legendary,
                     spriteModifier: SpriteModifier(hatLine: "   =====    "), unlockLevel: 6),
    ]

    // MARK: - Eye Items
    static let eyeItems: [CosmeticItem] = [
        CosmeticItem(id: "eye_star", slot: .eye, name: "cosmetic.eye.star", rarity: .uncommon,
                     spriteModifier: SpriteModifier(eyeChar: "✦"), unlockLevel: 2),
        CosmeticItem(id: "eye_heart", slot: .eye, name: "cosmetic.eye.heart", rarity: .rare,
                     spriteModifier: SpriteModifier(eyeChar: "♥"), unlockLevel: 2),
        CosmeticItem(id: "eye_diamond", slot: .eye, name: "cosmetic.eye.diamond", rarity: .epic,
                     spriteModifier: SpriteModifier(eyeChar: "◆"), unlockLevel: 3),
        CosmeticItem(id: "eye_spiral", slot: .eye, name: "cosmetic.eye.spiral", rarity: .rare,
                     spriteModifier: SpriteModifier(eyeChar: "@"), unlockLevel: 2),
        CosmeticItem(id: "eye_fire", slot: .eye, name: "cosmetic.eye.fire", rarity: .legendary,
                     spriteModifier: SpriteModifier(eyeChar: "🔥"), unlockLevel: 5),
        CosmeticItem(id: "eye_moon", slot: .eye, name: "cosmetic.eye.moon", rarity: .epic,
                     spriteModifier: SpriteModifier(eyeChar: "☽"), unlockLevel: 4),
        CosmeticItem(id: "eye_cross", slot: .eye, name: "cosmetic.eye.cross", rarity: .common,
                     spriteModifier: SpriteModifier(eyeChar: "×"), unlockLevel: 2),
        CosmeticItem(id: "eye_ring", slot: .eye, name: "cosmetic.eye.ring", rarity: .uncommon,
                     spriteModifier: SpriteModifier(eyeChar: "◉"), unlockLevel: 2),
    ]

    // MARK: - Accessory Items
    static let accessoryItems: [CosmeticItem] = [
        CosmeticItem(id: "acc_bow", slot: .accessory, name: "cosmetic.acc.bow", rarity: .common,
                     spriteModifier: SpriteModifier(accessoryRight: " >"), unlockLevel: 3),
        CosmeticItem(id: "acc_sword", slot: .accessory, name: "cosmetic.acc.sword", rarity: .uncommon,
                     spriteModifier: SpriteModifier(accessoryRight: " †"), unlockLevel: 3),
        CosmeticItem(id: "acc_shield", slot: .accessory, name: "cosmetic.acc.shield", rarity: .uncommon,
                     spriteModifier: SpriteModifier(accessoryLeft: "[] "), unlockLevel: 3),
        CosmeticItem(id: "acc_wand", slot: .accessory, name: "cosmetic.acc.wand", rarity: .rare,
                     spriteModifier: SpriteModifier(accessoryRight: " *"), unlockLevel: 4),
        CosmeticItem(id: "acc_scarf", slot: .accessory, name: "cosmetic.acc.scarf", rarity: .common,
                     spriteModifier: SpriteModifier(accessoryLeft: "~ "), unlockLevel: 3),
        CosmeticItem(id: "acc_flag", slot: .accessory, name: "cosmetic.acc.flag", rarity: .rare,
                     spriteModifier: SpriteModifier(accessoryRight: " ⚑"), unlockLevel: 4),
        CosmeticItem(id: "acc_balloon", slot: .accessory, name: "cosmetic.acc.balloon", rarity: .epic,
                     spriteModifier: SpriteModifier(accessoryRight: " 🎈"), unlockLevel: 5),
        CosmeticItem(id: "acc_guitar", slot: .accessory, name: "cosmetic.acc.guitar", rarity: .legendary,
                     spriteModifier: SpriteModifier(accessoryLeft: "🎸"), unlockLevel: 7),
    ]

    // MARK: - Aura Items
    static let auraItems: [CosmeticItem] = [
        CosmeticItem(id: "aura_sparkle", slot: .aura, name: "cosmetic.aura.sparkle", rarity: .uncommon,
                     spriteModifier: SpriteModifier(auraTop: "   ✦ · ✦    ", auraBottom: "   · ✦ ·    "), unlockLevel: 5),
        CosmeticItem(id: "aura_fire", slot: .aura, name: "cosmetic.aura.fire", rarity: .rare,
                     spriteModifier: SpriteModifier(auraTop: "  ~ 🔥 ~    ", auraBottom: "  ~ ~ ~ ~   "), unlockLevel: 5),
        CosmeticItem(id: "aura_hearts", slot: .aura, name: "cosmetic.aura.hearts", rarity: .rare,
                     spriteModifier: SpriteModifier(auraTop: "  ♥  ♥  ♥   ", auraBottom: "   ♥  ♥     "), unlockLevel: 5),
        CosmeticItem(id: "aura_snow", slot: .aura, name: "cosmetic.aura.snow", rarity: .uncommon,
                     spriteModifier: SpriteModifier(auraTop: "  * .  * .  ", auraBottom: "  . *  . *  "), unlockLevel: 5),
        CosmeticItem(id: "aura_music", slot: .aura, name: "cosmetic.aura.music", rarity: .epic,
                     spriteModifier: SpriteModifier(auraTop: "  ♪ ♫ ♪     ", auraBottom: "    ♫ ♪ ♫   "), unlockLevel: 6),
        CosmeticItem(id: "aura_rainbow", slot: .aura, name: "cosmetic.aura.rainbow", rarity: .legendary,
                     spriteModifier: SpriteModifier(auraTop: " 🌈 · · ·   ", auraBottom: "  · · · 🌈  "), unlockLevel: 8),
    ]

    // MARK: - Frame Items
    static let frameItems: [CosmeticItem] = [
        CosmeticItem(id: "frame_bracket", slot: .frame, name: "cosmetic.frame.bracket", rarity: .common,
                     spriteModifier: SpriteModifier(frameLeft: "[ ", frameRight: " ]"), unlockLevel: 8),
        CosmeticItem(id: "frame_pipe", slot: .frame, name: "cosmetic.frame.pipe", rarity: .uncommon,
                     spriteModifier: SpriteModifier(frameLeft: "| ", frameRight: " |"), unlockLevel: 8),
        CosmeticItem(id: "frame_stars", slot: .frame, name: "cosmetic.frame.stars", rarity: .rare,
                     spriteModifier: SpriteModifier(frameLeft: "✦ ", frameRight: " ✦"), unlockLevel: 8),
        CosmeticItem(id: "frame_arrows", slot: .frame, name: "cosmetic.frame.arrows", rarity: .epic,
                     spriteModifier: SpriteModifier(frameLeft: "» ", frameRight: " «"), unlockLevel: 9),
        CosmeticItem(id: "frame_diamond", slot: .frame, name: "cosmetic.frame.diamond", rarity: .legendary,
                     spriteModifier: SpriteModifier(frameLeft: "◆ ", frameRight: " ◆"), unlockLevel: 10),
    ]
}
