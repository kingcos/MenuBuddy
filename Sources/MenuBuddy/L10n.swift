import Foundation

// MARK: - Localization Helper

/// Convenience wrapper for NSLocalizedString using Bundle.main.
/// All user-visible strings go through here so they're discoverable.
func L(_ key: String, _ args: CVarArg...) -> String {
    let format = NSLocalizedString(key, bundle: .main, comment: "")
    if args.isEmpty { return format }
    return String(format: format, locale: .current, arguments: args)
}

// MARK: - Typed Keys (prevents typos)

enum Strings {
    // Menu
    static func menuPet(_ name: String)    -> String { L("menu.pet", name) }
    static func menuRename(_ name: String) -> String { L("menu.rename", name) }
    static var menuMute:          String   { L("menu.mute") }
    static var menuUnmute:        String   { L("menu.unmute") }
    static var menuLaunchAtLogin: String   { L("menu.launchAtLogin") }
    static var menuAbout:         String   { L("menu.about") }
    static var menuQuit:          String   { L("menu.quit") }

    // About
    static var aboutTitle:                  String { L("about.title") }
    static func aboutCompanion(_ n: String) -> String { L("about.companion", n) }
    static func aboutSpecies(_ s: String)   -> String { L("about.species", s) }
    static func aboutRarity(_ r: String, _ stars: String) -> String { L("about.rarity", r, stars) }
    static func aboutHatched(_ d: String)   -> String { L("about.hatched", d) }
    static var aboutOK: String              { L("about.ok") }

    // Rename
    static var renameTitle:       String { L("rename.title") }
    static var renamePlaceholder: String { L("rename.placeholder") }
    static var renameCancel:      String { L("rename.cancel") }
    static var renameConfirm:     String { L("rename.confirm") }

    // Footer
    static func footerHatched(_ d: String) -> String { L("footer.hatched", d) }
    static func footerPets(_ n: Int)       -> String { L("footer.pets", n) }

    // Tooltip
    static func tooltip(_ name: String, _ species: String) -> String { L("tooltip.companion", name, species) }

    // Stats
    static func statName(_ stat: StatName) -> String {
        switch stat {
        case .debugging: return L("stat.debugging")
        case .patience:  return L("stat.patience")
        case .chaos:     return L("stat.chaos")
        case .wisdom:    return L("stat.wisdom")
        case .snark:     return L("stat.snark")
        }
    }

    // Milestone messages
    static func milestone(_ count: Int) -> String? {
        switch count {
        case 1:   return L("milestone.1")
        case 5:   return L("milestone.5")
        case 10:  return L("milestone.10")
        case 25:  return L("milestone.25")
        case 50:  return L("milestone.50")
        case 100: return L("milestone.100")
        default:  return nil
        }
    }

    // Welcome
    static func welcome(_ name: String) -> String { L("welcome", name) }

    // System quips
    static var cpuHighQuips: [String] {
        [L("quip.cpu.high1"), L("quip.cpu.high2"), L("quip.cpu.high3"), L("quip.cpu.high4")]
    }
    static var memHighQuips: [String] {
        [L("quip.mem.high1"), L("quip.mem.high2"), L("quip.mem.high3")]
    }
    static var netFastQuips: [String] {
        [L("quip.net.fast1"), L("quip.net.fast2")]
    }
    static var netSlowQuips: [String] {
        [L("quip.net.slow1"), L("quip.net.slow2")]
    }
    static var batteryLowQuips: [String] {
        [L("quip.battery.low1"), L("quip.battery.low2")]
    }
    static var batteryChargingQuip: String { L("quip.battery.charging") }

    // Accessibility
    static func a11ySpriteLabel(_ name: String, _ species: String) -> String {
        L("a11y.sprite.label", name, species)
    }
    static var a11ySpriteHint: String { L("a11y.sprite.hint") }
    static func a11ySpeechLabel(_ text: String) -> String { L("a11y.speech.label", text) }
    static func a11yStatLabel(_ stat: String, _ value: Int) -> String {
        L("a11y.stat.label", stat, value)
    }
}
