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
    static var aboutAuthor: String           { L("about.author") }
    static var aboutHomepage: String         { L("about.homepage") }
    static var aboutOK: String               { L("about.ok") }

    // Rename
    static var renameTitle:       String { L("rename.title") }
    static var renamePlaceholder: String { L("rename.placeholder") }
    static var renameCancel:      String { L("rename.cancel") }
    static var renameConfirm:     String { L("rename.confirm") }

    // Footer
    static func footerHatched(_ d: String) -> String { L("footer.hatched", d) }
    static func footerPets(_ n: Int)       -> String { L("footer.pets", n) }
    static func footerAgeDays(_ n: Int)    -> String { L("footer.age.days", n) }
    static var footerAgeToday: String      { L("footer.age.today") }

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

    // Generic idle quips
    static var genericQuips: [String] {
        (1...19).map { L("quip.generic.\($0)") }
    }

    // Pet response quips
    static var petResponses: [String] {
        (1...7).map { L("quip.pet.\($0)") }
    }

    // Species-specific quips
    static func speciesQuips(for species: Species) -> [String] {
        let counts: [Species: Int] = [
            .duck: 5, .goose: 5, .blob: 5, .cat: 5, .dragon: 5,
            .octopus: 5, .owl: 5, .penguin: 5, .turtle: 5, .snail: 4,
            .ghost: 5, .axolotl: 5, .capybara: 5, .cactus: 5, .robot: 5,
            .rabbit: 5, .mushroom: 4, .chonk: 5,
        ]
        let n = counts[species] ?? 0
        guard n > 0 else { return [] }
        return (1...n).map { L("quip.species.\(species.rawValue).\($0)") }
    }

    // Time-of-day greeting (call once per day on first open)
    static var timeOfDayQuip: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<12:  return L("quip.tod.morning")
        case 12..<18: return L("quip.tod.afternoon")
        case 18..<22: return L("quip.tod.evening")
        default:      return L("quip.tod.night")
        }
    }

    // Error strings
    static var errorLaunchAtLoginTitle: String         { L("error.launchAtLogin.title") }
    static func errorLaunchAtLoginBody(_ e: String) -> String { L("error.launchAtLogin.body", e) }
    static var errorOK: String                         { L("error.ok") }

    // Default companion names
    static var defaultNames: [String] {
        L("default.names").components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    // LLM settings
    static var settingsSectionLLM: String         { L("settings.section.llm") }
    static var settingsLLMEnable: String          { L("settings.llm.enable") }
    static var settingsLLMEnableDesc: String      { L("settings.llm.enable.desc") }
    static var settingsLLMEndpoint: String        { L("settings.llm.endpoint") }
    static var settingsLLMApiKey: String          { L("settings.llm.apikey") }
    static var settingsLLMModel: String           { L("settings.llm.model") }
    static var settingsLLMMaxTokens: String       { L("settings.llm.maxtokens") }
    static func settingsLLMUsage(_ r: Int, _ t: Int) -> String { L("settings.llm.usage", r, t) }
    static var settingsLLMUsageReset: String      { L("settings.llm.usage.reset") }
    static var settingsLLMEnhanceTriggers: String   { L("settings.llm.enhance.triggers") }
    static var settingsLLMEnhanceTriggersDesc: String { L("settings.llm.enhance.triggers.desc") }
    static var settingsLLMTest: String            { L("settings.llm.test") }
    static var settingsLLMTesting: String         { L("settings.llm.testing") }
    static func settingsLLMTestOK(_ s: String) -> String { L("settings.llm.test.ok", s) }
    static func settingsLLMTestFail(_ s: String) -> String { L("settings.llm.test.fail", s) }

    // Startup greetings
    static var startupQuips: [String] {
        (1...6).map { L("quip.startup.\($0)") }
    }

    // Sleep/wake quips
    static func wakeQuip(sleepSeconds: TimeInterval) -> String {
        switch sleepSeconds {
        case ..<1800:   return L("quip.wake.short")     // < 30 min
        case ..<14400:  return L("quip.wake.medium")    // < 4 h
        case ..<57600:  return L("quip.wake.long")      // < 16 h
        default:        return L("quip.wake.overnight") // >= 16 h
        }
    }

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
    static var diskBusyQuips: [String] {
        [L("quip.disk.busy1"), L("quip.disk.busy2")]
    }
    static var sysstatDisk: String { L("sysstat.disk") }

    // Reset companion
    static var settingsReset: String              { L("settings.reset") }
    static var resetConfirmTitle: String          { L("settings.reset.confirm.title") }
    static var resetConfirmBody: String           { L("settings.reset.confirm.body") }
    static var resetConfirmOK: String             { L("settings.reset.confirm.ok") }
    static func resetConfirmCancel(_ n: String) -> String { L("settings.reset.confirm.cancel", n) }

    // Workspace app-context quips
    static var appCodingQuip: String   { L("quip.app.coding") }
    static var appTerminalQuip: String { L("quip.app.terminal") }
    static var appBrowsingQuip: String { L("quip.app.browsing") }
    static var appChattingQuip: String { L("quip.app.chatting") }
    static var appDesignQuip: String   { L("quip.app.design") }
    static var appMusicQuip: String    { L("quip.app.music") }

    // Settings & Help
    static var menuSettings: String        { L("menu.settings") }
    static var settingsTitle: String       { L("settings.title") }
    static var settingsSectionGeneral: String  { L("settings.section.general") }
    static var settingsLaunchAtLogin: String   { L("settings.launchAtLogin") }
    static var settingsMute: String            { L("settings.mute") }
    static var settingsMuteDesc: String        { L("settings.mute.desc") }
    static var settingsSectionMonitor: String  { L("settings.section.monitor") }
    static var settingsMonitorDesc: String     { L("settings.monitor.desc") }
    static var settingsSectionHelp: String     { L("settings.section.help") }
    static var settingsHelpPet: String         { L("settings.help.pet") }
    static var settingsHelpRename: String      { L("settings.help.rename") }
    static var settingsHelpShiny: String       { L("settings.help.shiny") }
    static var settingsDone: String            { L("settings.done") }

    // System status strip
    static var sysstatCPU: String { L("sysstat.cpu") }
    static var sysstatMEM: String { L("sysstat.mem") }
    static var sysstatNET: String { L("sysstat.net") }
    static var sysstatBAT: String { L("sysstat.bat") }
    static var sysstatCharging: String { L("sysstat.charging") }
    static func sysstatNetKB(_ v: Double) -> String { L("sysstat.net.unit.kb", v) }
    static func sysstatNetMB(_ v: Double) -> String { L("sysstat.net.unit.mb", v) }

    // Language settings
    static var settingsSectionLanguage: String   { L("settings.section.language") }
    static var settingsLanguageSystem: String    { L("settings.language.system") }
    static var settingsLanguageEN: String        { L("settings.language.en") }
    static var settingsLanguageZHHans: String    { L("settings.language.zhHans") }
    static var settingsLanguageRestart: String   { L("settings.language.restart") }
    static var settingsLanguageRestartOK: String { L("settings.language.restart.ok") }
    static var settingsLanguageRestartLater: String { L("settings.language.restart.later") }

    // Stat descriptions
    static func statDesc(_ stat: StatName) -> String {
        switch stat {
        case .debugging: return L("stat.debugging.desc")
        case .patience:  return L("stat.patience.desc")
        case .chaos:     return L("stat.chaos.desc")
        case .wisdom:    return L("stat.wisdom.desc")
        case .snark:     return L("stat.snark.desc")
        }
    }
    static var settingsHelpStats: String { L("settings.help.stats") }

    // Repeat triggers
    static var settingsRepeatTriggers: String      { L("settings.repeat.triggers") }
    static var settingsRepeatTriggersDesc: String   { L("settings.repeat.triggers.desc") }

    // Do Not Disturb
    static var settingsSectionDND: String   { L("settings.section.dnd") }
    static var settingsDNDDesc: String      { L("settings.dnd.desc") }
    static var settingsDNDEnable: String    { L("settings.dnd.enable") }
    static var settingsDNDFrom: String      { L("settings.dnd.from") }
    static var settingsDNDTo: String        { L("settings.dnd.to") }

    // Menu bar quips
    static var settingsSectionMenuBar: String    { L("settings.section.menubar") }
    static var settingsChattyMode: String          { L("settings.chatty") }
    static var settingsChattyModeDesc: String     { L("settings.chatty.desc") }
    static var settingsMenuBarTwoLine: String     { L("settings.menubar.twoline") }
    static var settingsMenuBarTwoLineDesc: String { L("settings.menubar.twoline.desc") }
    static var settingsMenuBarQuips: String      { L("settings.menubar.quips") }
    static var settingsMenuBarQuipsDesc: String  { L("settings.menubar.quips.desc") }

    // Trigger sources
    static var triggerSystemName: String     { L("trigger.system.name") }
    static var triggerSectionTitle: String   { L("trigger.section.title") }
    static var triggerSectionDesc: String    { L("trigger.section.desc") }
    static var triggerScriptsHint: String    { L("trigger.scripts.hint") }
    static var triggerScriptsOpen: String    { L("trigger.scripts.open") }
    static var triggerScriptsRescan: String  { L("trigger.scripts.rescan") }
    static var settingsLogsOpen: String        { L("settings.logs.open") }
    static var settingsLogsEnable: String      { L("settings.logs.enable") }
    static var settingsLogsEnableDesc: String   { L("settings.logs.enable.desc") }

    // Species Atlas
    static var atlasTitle: String  { L("atlas.title") }
    static var atlasYours: String  { L("atlas.yours") }
    static var atlasClose: String  { L("atlas.close") }

    // Help
    static var helpTitle: String        { L("help.title") }
    static var helpTipPet: String       { L("help.tip.pet") }
    static var helpTipClick: String     { L("help.tip.click") }
    static var helpTipRename: String    { L("help.tip.rename") }
    static var helpTipQuips: String     { L("help.tip.quips") }
    static var helpTipAI: String        { L("help.tip.ai") }
    static var helpTipTriggers: String  { L("help.tip.triggers") }
    static var helpTipDND: String       { L("help.tip.dnd") }
    static var helpTipShiny: String     { L("help.tip.shiny") }
    static var helpMore: String         { L("help.more") }

    // Accessibility
    static func a11ySpriteLabel(_ name: String, _ species: String) -> String {
        L("a11y.sprite.label", name, species)
    }
    static var a11ySpriteHint: String { L("a11y.sprite.hint") }
    static func a11ySpeechLabel(_ text: String) -> String { L("a11y.speech.label", text) }
    static func a11yStatLabel(_ stat: String, _ value: Int) -> String {
        L("a11y.stat.label", stat, value)
    }

    // Tooltip with level
    static func tooltipWithLevel(_ name: String, _ species: String, _ level: Int) -> String {
        L("tooltip.companion.level", name, species, level)
    }

    // About dialog — level
    static func aboutLevel(_ level: Int, _ xp: Int) -> String { L("about.level", level, xp) }

    // Species Atlas — change species
    static var atlasChangeSpecies: String { L("atlas.change.species") }
    static var atlasChangeConfirmTitle: String { L("atlas.change.confirm.title") }
    static func atlasChangeConfirmBody(_ species: String) -> String { L("atlas.change.confirm.body", species) }
    static var atlasChangeConfirmOK: String { L("atlas.change.confirm.ok") }
    static func atlasChangeLocked(_ level: Int) -> String { L("atlas.change.locked", level) }
    static var atlasChangeHint: String { L("atlas.change.hint") }
    static func atlasChangeConfirmCostBody(_ species: String, _ cost: Int) -> String { L("atlas.change.confirm.cost.body", species, cost) }
    static func atlasChangeCost(_ cost: Int) -> String { L("atlas.change.cost", cost) }
    static func atlasChangeCooldown(_ hours: Int) -> String { L("atlas.change.cooldown", hours) }
    static var resetPoints: String { L("progression.reset.points") }

    // Onboarding
    static var onboardingXP: String { L("onboarding.xp") }
    static var onboardingCosmetics: String { L("onboarding.cosmetics") }

    // Progression
    static func levelUpQuip(_ level: Int) -> String { L("progression.levelup", level) }
    static func levelUpTitle(_ level: Int) -> String { L("progression.levelup.title", level) }
    static func levelUpPoints(_ points: Int) -> String { L("progression.levelup.points", points) }
    static var levelUpOK: String { L("progression.levelup.ok") }
    static func slotUnlocked(_ slot: String) -> String { L("progression.slot.unlocked", slot) }
    static var allocatePoint: String { L("progression.allocate") }

    // Cosmetics
    static var cosmeticsTitle: String { L("cosmetics.title") }
    static var cosmeticsEmpty: String { L("cosmetics.empty") }
    static var cosmeticsImport: String { L("cosmetics.import") }
    static var cosmeticsExport: String { L("cosmetics.export") }
    static var cosmeticsImportTitle: String { L("cosmetics.import.title") }
    static var cosmeticsImportPlaceholder: String { L("cosmetics.import.placeholder") }
    static var cosmeticsImportConfirm: String { L("cosmetics.import.confirm") }
    static var cosmeticsImportFail: String { L("cosmetics.import.fail") }
    static var cosmeticsCreate: String { L("cosmetics.create") }
    static var cosmeticsCreateTitle: String { L("cosmetics.create.title") }
    static var cosmeticsCreateNameLabel: String { L("cosmetics.create.name.label") }
    static var cosmeticsCreateNamePlaceholder: String { L("cosmetics.create.name.placeholder") }
    static var cosmeticsCreateLineLabel: String { L("cosmetics.create.line.label") }
    static var cosmeticsCreateHint: String { L("cosmetics.create.hint") }
    static var cosmeticsCreatePreview: String { L("cosmetics.create.preview") }
    static var cosmeticsCreateConfirm: String { L("cosmetics.create.confirm") }
    static var cosmeticsDelete: String { L("cosmetics.delete") }
    static func cosmeticsOwned(_ owned: Int, _ total: Int) -> String { L("cosmetics.owned", owned, total) }
    static func cosmeticReward(_ name: String) -> String { L("cosmetics.reward", name) }
    static func cosmeticDropQuip(_ name: String) -> String { L("cosmetics.drop", name) }

    // Slot names
    static func slotName(_ slot: CosmeticSlot) -> String {
        L("slot.\(slot.rawValue)")
    }

    // Help — Progression & Cosmetics
    static var helpTipLevel: String { L("help.tip.level") }
    static var helpTipCosmetics: String { L("help.tip.cosmetics") }
    static var helpTipRarity: String { L("help.tip.rarity") }

    // Settings — Update
    static var settingsSectionUpdate: String { L("settings.section.update") }
    static var settingsUpdateBeta: String { L("settings.update.beta") }
    static var settingsUpdateBetaDesc: String { L("settings.update.beta.desc") }
    static func settingsUpdateCurrent(_ v: String) -> String { L("settings.update.current", v) }
    static var settingsUpdateCheck: String { L("settings.update.check") }
    static var settingsUpdateUpToDate: String { L("settings.update.uptodate") }
    static func settingsUpdateAvailable(_ v: String) -> String { L("settings.update.available", v) }
    static var settingsUpdateDownload: String { L("settings.update.download") }
    static var settingsUpdateViewRelease: String { L("settings.update.viewrelease") }
    static var menuCheckUpdate: String { L("menu.checkupdate") }

    // Settings — Progression
    static var settingsSectionProgression: String { L("settings.section.progression") }
    static var settingsProgressionEnable: String { L("settings.progression.enable") }
    static var settingsProgressionEnableDesc: String { L("settings.progression.enable.desc") }
    static var settingsProgressionPoints: String { L("settings.progression.points") }
    static var settingsProgressionSlots: String { L("settings.progression.slots") }
}
