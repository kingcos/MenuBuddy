import Foundation
import Combine

// MARK: - Companion Store

class CompanionStore: ObservableObject {
    static let shared = CompanionStore()

    @Published private(set) var companion: Companion

    private let soulKey = "companion.soul"
    private let mutedKey = "companion.muted"
    private let petCountKey = "companion.petCount"
    private let userId: String

    /// Progression system — tracks XP and level.
    let progression = ProgressionSystem.shared
    /// Cosmetic system — manages inventory and equipped items.
    let cosmetics = CosmeticSystem.shared

    /// Published so UI can react to progression changes.
    @Published private(set) var level: Int = 0
    @Published private(set) var levelProgress: Double = 0
    @Published private(set) var totalXP: Int = 0
    @Published private(set) var availablePoints: Int = 0

    /// Pending level-up info for the UI to consume.
    @Published private(set) var pendingLevelUp: LevelUpInfo?
    /// Pending cosmetic drops for the UI to consume (supports multiple simultaneous drops).
    @Published private(set) var pendingCosmeticDrops: [CosmeticItem] = []

    @Published var muted: Bool {
        didSet {
            UserDefaults.standard.set(muted, forKey: mutedKey)
        }
    }

    /// When true, menu bar shows face + quip on two lines instead of one line.
    @Published var menuBarTwoLine: Bool {
        didSet { UserDefaults.standard.set(menuBarTwoLine, forKey: "companion.menuBarTwoLine") }
    }

    /// Chatty mode — quips refresh every 15 seconds in both popover and menu bar.
    @Published var chattyMode: Bool {
        didSet {
            UserDefaults.standard.set(chattyMode, forKey: "companion.chattyMode")
            scheduleMenuBarQuip(delay: chattyMode ? 15 : nil)
        }
    }

    /// When true, system events fire every poll while condition holds.
    /// When false, events only fire once per state transition (edge-triggered).
    @Published var repeatTriggers: Bool {
        didSet {
            UserDefaults.standard.set(repeatTriggers, forKey: "companion.repeatTriggers")
            systemSource.monitor.repeatEvents = repeatTriggers
        }
    }

    /// Logging on/off — delegates to BuddyLogger.
    @Published var loggingEnabled: Bool {
        didSet { BuddyLogger.shared.enabled = loggingEnabled }
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
        guard !muted, !isDND else { return }
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
    private var triggerManagerSink: AnyCancellable?

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

    /// Startup greeting — consumed on first popover open each launch.
    private(set) var pendingStartupGreeting: String? = Strings.startupQuips.randomElement()

    /// Pending LLM reaction — shown next time popover opens if it was closed.
    @Published private(set) var pendingLLMReaction: String?

    func consumeLLMReaction() -> String? {
        defer { pendingLLMReaction = nil }
        return pendingLLMReaction
    }

    func consumeResetWelcome() -> Bool {
        defer { pendingResetWelcome = false }
        return pendingResetWelcome
    }

    func consumeStartupGreeting() -> String? {
        defer { pendingStartupGreeting = nil }
        return pendingStartupGreeting
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
    private var lastLLMTriggerTime: Date?
    private let llmTriggerCooldown: TimeInterval = 60

    private init() {
        userId = getMachineId()
        muted = UserDefaults.standard.bool(forKey: "companion.muted")
        petCount = UserDefaults.standard.integer(forKey: "companion.petCount")
        menuBarTwoLine = UserDefaults.standard.object(forKey: "companion.menuBarTwoLine") as? Bool ?? true
        chattyMode = UserDefaults.standard.bool(forKey: "companion.chattyMode")
        repeatTriggers = UserDefaults.standard.object(forKey: "companion.repeatTriggers") as? Bool ?? true
        loggingEnabled = UserDefaults.standard.bool(forKey: "companion.loggingEnabled")
        dndEnabled = UserDefaults.standard.bool(forKey: "companion.dndEnabled")
        dndFrom = UserDefaults.standard.object(forKey: "companion.dndFrom") as? Int ?? 22
        dndTo = UserDefaults.standard.object(forKey: "companion.dndTo") as? Int ?? 8

        var bones = rollCompanion(userId: userId)
        // Apply persisted species override (from species change feature)
        if let overrideRaw = UserDefaults.standard.string(forKey: "companion.speciesOverride"),
           let overrideSpecies = Species(rawValue: overrideRaw) {
            bones = CompanionBones(
                rarity: bones.rarity, species: overrideSpecies, eye: bones.eye,
                hat: bones.hat, shiny: bones.shiny, stats: bones.stats
            )
        }
        let (soul, isNew) = CompanionStore.loadOrCreateSoul()
        isFirstLaunch = isNew

        companion = Companion(bones: bones, soul: soul)

        logger.info("Companion: \(companion.name) (\(companion.species.rawValue), \(companion.rarity.rawValue)\(companion.shiny ? ", shiny" : ""))", source: "store")
        if isFirstLaunch { logger.info("First launch", source: "store") }

        // Sync repeat setting to system monitor
        systemSource.monitor.repeatEvents = repeatTriggers

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

        // Discover and register script-based triggers from ~/.menubuddy/triggers/
        for script in ScriptTriggerSource.discoverScripts() {
            triggerManager.register(script)
        }

        // Forward trigger manager changes to CompanionStore's objectWillChange
        triggerManagerSink = triggerManager.objectWillChange.sink { [weak self] in
            self?.objectWillChange.send()
        }

        scheduleMenuBarQuip(delay: Double.random(in: 15...30))

        // Sync progression state to published properties
        refreshProgressionState()

        // Claim daily XP on launch
        if let info = progression.claimDailyXP() {
            pendingLevelUp = info
        }
    }

    private func scheduleMenuBarQuip(delay: TimeInterval? = nil) {
        menuBarQuipTimer?.invalidate()
        let interval = delay ?? (chattyMode ? 15 : Double.random(in: 120...300))
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

    /// Generates an AI pet reaction if LLM is enabled.
    func requestLLMPetReaction(completion: @escaping (String) -> Void) {
        let llm = LLMService.shared
        guard llm.config.enabled else { return }
        llm.generateReaction(companion: companion, context: "The user just petted you! React with delight.") { [weak self] reaction in
            guard let reaction, !reaction.isEmpty else { return }
            self?.grantLLMXP()
            completion(reaction)
        }
    }

    /// Tries to generate an LLM reaction for the given context.
    /// Falls back to the provided quips if LLM is disabled or fails.
    func requestLLMReaction(context: String, fallbackQuips: [String]) {
        let llm = LLMService.shared
        guard llm.config.enabled else { return }

        llm.generateReaction(companion: companion, context: context) { [weak self] reaction in
            guard let self, let reaction, !reaction.isEmpty else { return }
            self.onTriggerEvent?(TriggerEvent(
                sourceId: "llm",
                indicator: "",
                quips: [reaction]
            ))
            self.showMenuBarQuip(reaction)
        }
    }

    /// Handles a standardized trigger event from any source.
    private func handleTriggerEvent(_ event: TriggerEvent) {
        logger.debug("Trigger event: [\(event.sourceId)] \(event.indicator) quips=\(event.quips.count)", source: "trigger")

        // Grant trigger XP
        grantTriggerXP()

        let shouldUseLLM = LLMService.shared.config.enabled
        var llmRequestFired = false

        // Try LLM-generated reaction if enabled and not in cooldown
        if !event.quips.isEmpty, shouldUseLLM {
            let now = Date()
            if lastLLMTriggerTime == nil || now.timeIntervalSince(lastLLMTriggerTime!) >= llmTriggerCooldown {
                lastLLMTriggerTime = now
                llmRequestFired = true
                let hour = Calendar.current.component(.hour, from: Date())
                let randomQuip = event.quips.randomElement() ?? ""
                let context = "System event: \(event.indicator) \(randomQuip) (time: \(hour):00, say something different each time)"
                LLMService.shared.generateReaction(companion: companion, context: context) { [weak self] reaction in
                    guard let self, let reaction, !reaction.isEmpty else { return }
                    logger.info("LLM reaction for [\(event.sourceId)]: \(reaction)", source: "llm")
                    if self.onTriggerEvent != nil {
                        self.onTriggerEvent?(TriggerEvent(sourceId: "llm", indicator: "", quips: [reaction]))
                    } else {
                        self.pendingLLMReaction = reaction
                    }
                    self.showMenuBarQuip(reaction)
                }
            }
        }

        // Update menu bar indicator
        systemIndicator = event.indicator
        triggerEyeOverride = event.eyeOverride
        triggerMood = event.mood

        // Show preset quip in popover when LLM was not fired (disabled, off, or cooldown)
        if !llmRequestFired {
            onTriggerEvent?(event)
        }

        // Show a preset quip in the menu bar (LLM will override with its own later)
        if let q = event.quips.randomElement() {
            showMenuBarQuip(q)
        }

        // Clear indicator after duration
        let indicator = event.indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + event.duration) { [weak self] in
            guard let self else { return }
            if self.systemIndicator == indicator {
                self.systemIndicator = ""
                self.triggerEyeOverride = nil
                self.triggerMood = nil
            }
        }
    }

    /// Increments pet count, persists it, grants XP, and returns any milestone message.
    @discardableResult
    func recordPet() -> String? {
        petCount += 1
        UserDefaults.standard.set(petCount, forKey: petCountKey)

        // Grant petting XP
        let levelUp = progression.grantXP(.pet, source: "pet")
        if let levelUp { handleLevelUp(levelUp) }
        refreshProgressionState()

        // Check for random cosmetic drop (5% chance per pet)
        if Double.random(in: 0...1) < 0.05 {
            if let drop = cosmetics.rollRandomDrop(level: progression.level) {
                cosmetics.addItem(drop)
                pendingCosmeticDrops.append(drop)
            }
        }

        if let milestone = milestoneMessage(for: petCount) {
            // Bonus XP for milestones
            let mlUp = progression.grantXP(.milestone, source: "milestone.\(petCount)")
            if let mlUp { handleLevelUp(mlUp) }
            refreshProgressionState()
            return milestone
        }
        return nil
    }

    private func milestoneMessage(for count: Int) -> String? {
        Strings.milestone(count)
    }

    // MARK: - Onboarding

    /// Returns an XP onboarding message the first time XP is earned, nil after.
    func consumeXPOnboarding() -> String? {
        let key = "onboarding.xpSeen"
        guard !UserDefaults.standard.bool(forKey: key) else { return nil }
        guard progression.state.totalXP > 0 else { return nil }
        UserDefaults.standard.set(true, forKey: key)
        return Strings.onboardingXP
    }

    /// Returns a cosmetics onboarding message the first time the panel is opened, nil after.
    func consumeCosmeticsOnboarding() -> String? {
        let key = "onboarding.cosmeticsSeen"
        guard !UserDefaults.standard.bool(forKey: key) else { return nil }
        UserDefaults.standard.set(true, forKey: key)
        return Strings.onboardingCosmetics
    }

    // MARK: - Progression Helpers

    func refreshProgressionState() {
        level = progression.level
        levelProgress = progression.levelProgress
        totalXP = progression.state.totalXP
        availablePoints = progression.availableAttributePoints
    }

    /// Grant XP for trigger events.
    func grantTriggerXP() {
        let levelUp = progression.grantXP(.triggerEvent, source: "trigger")
        if let levelUp { handleLevelUp(levelUp) }
        refreshProgressionState()
    }

    /// Grant XP for LLM reactions.
    func grantLLMXP() {
        let levelUp = progression.grantXP(.llmReaction, source: "llm")
        if let levelUp { handleLevelUp(levelUp) }
        refreshProgressionState()
    }

    /// Grant XP for app context switches.
    func grantAppContextXP() {
        let levelUp = progression.grantXP(.appContext, source: "appContext")
        if let levelUp { handleLevelUp(levelUp) }
        refreshProgressionState()
    }

    /// Allocate a bonus attribute point.
    func allocateAttributePoint(to stat: StatName) -> Bool {
        let result = progression.allocatePoint(to: stat)
        if result { refreshProgressionState() }
        return result
    }

    /// Get effective stat value including bonuses.
    func effectiveStat(_ stat: StatName) -> Int {
        let base = companion.stats[stat] ?? 0
        return progression.effectiveStat(stat, base: base)
    }

    private func handleLevelUp(_ info: LevelUpInfo) {
        pendingLevelUp = info
        // Grant a cosmetic reward on level up
        if let reward = cosmetics.grantLevelUpReward(level: info.newLevel) {
            pendingCosmeticDrops.append(reward)
        }
    }

    func consumeLevelUp() -> LevelUpInfo? {
        defer { pendingLevelUp = nil }
        return pendingLevelUp
    }

    func consumeCosmeticDrop() -> CosmeticItem? {
        guard !pendingCosmeticDrops.isEmpty else { return nil }
        return pendingCosmeticDrops.removeFirst()
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

    /// Change the companion's species. Keeps rarity, eye, hat, shiny, and stats.
    /// Requires level 5+.
    func changeSpecies(to newSpecies: Species) {
        guard progression.level >= 5 else { return }
        let oldBones = companion.bones
        let newBones = CompanionBones(
            rarity: oldBones.rarity,
            species: newSpecies,
            eye: oldBones.eye,
            hat: oldBones.hat,
            shiny: oldBones.shiny,
            stats: oldBones.stats
        )
        companion = Companion(bones: newBones, soul: companion.soul)
        // Persist the species override
        UserDefaults.standard.set(newSpecies.rawValue, forKey: "companion.speciesOverride")
        logger.info("Species changed to \(newSpecies.rawValue)", source: "store")
    }

    /// Wipes the current soul and creates a fresh one. Bones revert to the original machine-tied roll.
    func resetCompanion() {
        UserDefaults.standard.removeObject(forKey: soulKey)
        UserDefaults.standard.removeObject(forKey: petCountKey)
        UserDefaults.standard.removeObject(forKey: "companion.lastGreetedDay")
        UserDefaults.standard.removeObject(forKey: "companion.speciesOverride")
        UserDefaults.standard.removeObject(forKey: "onboarding.xpSeen")
        UserDefaults.standard.removeObject(forKey: "onboarding.cosmeticsSeen")
        petCount = 0
        // Re-roll original bones (no species override since we cleared it)
        let originalBones = rollCompanion(userId: userId)
        let (soul, _) = CompanionStore.loadOrCreateSoul()
        companion = Companion(bones: originalBones, soul: soul)
        pendingResetWelcome = true
        // Reset progression and cosmetics
        progression.reset()
        cosmetics.reset()
        refreshProgressionState()
    }

    private func saveSoul(_ soul: CompanionSoul) {
        if let data = try? JSONEncoder().encode(soul) {
            UserDefaults.standard.set(data, forKey: soulKey)
        }
    }
}

