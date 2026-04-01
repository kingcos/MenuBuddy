import Foundation

// MARK: - Enums

enum Rarity: String, CaseIterable, Codable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var weight: Int {
        switch self {
        case .common: return 60
        case .uncommon: return 25
        case .rare: return 10
        case .epic: return 4
        case .legendary: return 1
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

    var color: String {
        switch self {
        case .common: return "#888888"
        case .uncommon: return "#22c55e"
        case .rare: return "#3b82f6"
        case .epic: return "#a855f7"
        case .legendary: return "#f59e0b"
        }
    }

    var statFloor: Int {
        switch self {
        case .common: return 5
        case .uncommon: return 15
        case .rare: return 25
        case .epic: return 35
        case .legendary: return 50
        }
    }

    /// Localized display name (e.g. "普通" in Chinese, "Common" in English)
    var localizedName: String {
        NSLocalizedString("rarity.\(rawValue)", bundle: .main, comment: "")
    }
}

enum Species: String, CaseIterable, Codable {
    case duck
    case goose
    case blob
    case cat
    case dragon
    case octopus
    case owl
    case penguin
    case turtle
    case snail
    case ghost
    case axolotl
    case capybara
    case cactus
    case robot
    case rabbit
    case mushroom
    case chonk

    /// Localized display name (e.g. "鸭子" in Chinese, "Duck" in English)
    var localizedName: String {
        NSLocalizedString("species.\(rawValue)", bundle: .main, comment: "")
    }
}

enum Eye: String, CaseIterable, Codable {
    case dot = "·"
    case star = "✦"
    case cross = "×"
    case circle = "◉"
    case at = "@"
    case degree = "°"

    var character: String { rawValue }
}

enum Hat: String, CaseIterable, Codable {
    case none
    case crown
    case tophat
    case propeller
    case halo
    case wizard
    case beanie
    case tinyduck

    var line: String {
        switch self {
        case .none: return ""
        case .crown: return "   \\^^^/    "
        case .tophat: return "   [___]    "
        case .propeller: return "    -+-     "
        case .halo: return "   (   )    "
        case .wizard: return "    /^\\     "
        case .beanie: return "   (___)    "
        case .tinyduck: return "    ,>      "
        }
    }
}

enum StatName: String, CaseIterable, Codable {
    case debugging = "DEBUGGING"
    case patience = "PATIENCE"
    case chaos = "CHAOS"
    case wisdom = "WISDOM"
    case snark = "SNARK"
}

// MARK: - Models

struct CompanionBones {
    let rarity: Rarity
    let species: Species
    let eye: Eye
    let hat: Hat
    let shiny: Bool
    let stats: [StatName: Int]
}

struct CompanionSoul: Codable {
    var name: String
    var hatchedAt: TimeInterval

    // Legacy key ignored on decode — was stored in older builds, never displayed
    private enum CodingKeys: String, CodingKey { case name, hatchedAt }
}

struct Companion {
    let bones: CompanionBones
    let soul: CompanionSoul

    var rarity: Rarity { bones.rarity }
    var species: Species { bones.species }
    var eye: Eye { bones.eye }
    var hat: Hat { bones.hat }
    var shiny: Bool { bones.shiny }
    var stats: [StatName: Int] { bones.stats }
    var name: String { soul.name }
}
