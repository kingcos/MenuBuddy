import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: CompanionStore
    @StateObject private var engine = AnimationEngine()
    @State private var isRenaming = false
    @State private var renameText = ""

    var companion: Companion { store.companion }

    @State private var showingAtlas = false
    @State private var showingHelp = false
    @State private var showingCosmetics = false
    @State private var showingLevelUp = false
    @State private var showingCosmeticDrop = false
    @State private var levelUpInfo: LevelUpInfo?
    @State private var cosmeticDropItem: CosmeticItem?

    var body: some View {
        VStack(spacing: 0) {
            headerView
            SpeechBubbleView(
                text: engine.speechText ?? " ",
                color: companion.rarity.color,
                fading: engine.speechFading
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 2)
            .opacity(engine.speechText != nil ? 1 : 0)
            spriteAreaView
            hatchFooter
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            Divider()
            StatsView(stats: companion.stats, store: store)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            if !store.triggerManager.allMetrics.isEmpty {
                Divider()
                MetricStripView(metrics: store.triggerManager.allMetrics)
            }
            Divider()
            popoverToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            engine.onPet = { store.recordPet() }
            engine.onPetLLM = { callback in store.requestLLMPetReaction(completion: callback) }
            engine.onAppContextSwitch = { store.grantAppContextXP() }
            store.onTriggerEvent = { [weak engine] event in
                guard let quip = event.quips.randomElement() else { return }
                engine?.showSpeech(quip)
            }
            engine.start(
                muted: store.muted,
                chattyMode: store.chattyMode,
                species: companion.species,
                isFirstLaunch: store.isFirstLaunch,
                companionName: companion.name
            )
            // Check for pending level-up
            if let info = store.consumeLevelUp() {
                levelUpInfo = info
                cosmeticDropItem = store.consumeCosmeticDrop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.showSpeech(Strings.levelUpQuip(info.newLevel))
                    showingLevelUp = true
                }
            } else if let drop = store.consumeCosmeticDrop() {
                cosmeticDropItem = drop
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.showSpeech(Strings.cosmeticDropQuip(L(drop.name)))
                }
            }

            // Show pending wake quip if Mac woke while popover was closed
            if let quip = store.consumeWakeQuip() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    engine.showSpeech(quip)
                }
            }
            // Show welcome quip after companion reset
            else if store.consumeResetWelcome() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.showSpeech(Strings.welcome(companion.name))
                }
            }
            // Show pending LLM reaction
            else if let llm = store.consumeLLMReaction() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    engine.showSpeech(llm)
                }
            }
            // Show startup greeting (random, once per launch)
            else if let startup = store.consumeStartupGreeting() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    engine.showSpeech(startup)
                }
            }
            // Show daily time-of-day greeting (once per day, not on first launch)
            else if !store.isFirstLaunch, let greeting = store.consumeDailyGreeting() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    engine.showSpeech(greeting)
                }
            }
            // Show XP onboarding (first time XP is earned)
            else if let xpOnboard = store.consumeXPOnboarding() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    engine.showSpeech(xpOnboard)
                }
            }
        }
        .onDisappear {
            store.onTriggerEvent = nil
            engine.stop()
        }
        .onChange(of: store.muted) { _, newValue in engine.updateMuted(newValue) }
        .onChange(of: store.chattyMode) { _, newValue in engine.updateChatty(newValue) }
        .onReceive(NotificationCenter.default.publisher(for: .triggerPet)) { _ in
            engine.triggerPet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRename)) { _ in
            startRename()
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionWoke)) { note in
            if let quip = note.object as? String {
                engine.showSpeech(quip)
                _ = store.consumeWakeQuip()  // clear the pending quip
            }
        }
        .sheet(isPresented: $isRenaming) {
            renameSheet
        }
        .sheet(isPresented: $showingAtlas) {
            SpeciesAtlasView(currentSpecies: companion.species, store: store)
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
        .sheet(isPresented: $showingCosmetics) {
            CosmeticView(store: store)
        }
        .sheet(isPresented: $showingLevelUp) {
            if let info = levelUpInfo {
                LevelUpSheet(info: info, cosmeticDrop: cosmeticDropItem)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(companion.name)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                        Text(store.mood)
                            .font(.system(size: 12))
                        if companion.shiny {
                            Text("✨")
                                .font(.system(size: 11))
                        }
                    }
                    Text("\(companion.species.localizedName) · \(companion.rarity.localizedName)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    // Level badge
                    HStack(spacing: 3) {
                        Text("Lv.\(store.level)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: companion.rarity.color))
                        Text(companion.rarity.stars)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: companion.rarity.color))
                    }
                    Button(action: startRename) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(Strings.menuRename(companion.name))
                }
            }
            // XP progress bar
            xpProgressBar
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var xpProgressBar: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: companion.rarity.color).opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(store.levelProgress), height: 5)
                        .animation(.easeInOut(duration: 0.3), value: store.levelProgress)
                }
            }
            .frame(height: 5)
            HStack {
                Text("\(store.totalXP) XP")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                if store.availablePoints > 0 {
                    Text("+\(store.availablePoints) pts ↓")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(hex: companion.rarity.color))
                        .help(Strings.allocatePoint)
                }
                Text("→ Lv.\(store.level + 1)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Sprite Area

    private var spriteAreaView: some View {
        VStack(spacing: 2) {
            if let frame = engine.petHeartFrame, frame < petHearts.count {
                Text(petHearts[frame])
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.pink)
                    .transition(.opacity)
            }
            let lines = renderSprite(
                bones: companion.bones,
                frame: engine.currentFrame,
                blink: engine.isBlink,
                cosmeticModifier: store.cosmetics.allEquippedModifiers()
            )
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(companion.shiny ? Color(hex: "#f59e0b") : Color(hex: companion.rarity.color))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Strings.a11ySpriteLabel(companion.name, companion.species.localizedName))
            .accessibilityHint(Strings.a11ySpriteHint)
            .accessibilityAddTraits(.isButton)
            .onTapGesture { engine.triggerPet() }
            .help(Strings.a11ySpriteHint)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Hatch Footer

    private var hatchFooter: some View {
        HStack {
            let hatchDate = Date(timeIntervalSince1970: companion.soul.hatchedAt)
            let days = Calendar.current.dateComponents([.day], from: hatchDate, to: Date()).day ?? 0
            let ageText = days == 0 ? Strings.footerAgeToday : Strings.footerAgeDays(days)
            Text(ageText)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Spacer()
            Text(Strings.footerPets(store.petCount))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Toolbar

    private var popoverToolbar: some View {
        HStack(spacing: 12) {
            Button(action: { NotificationCenter.default.post(name: .openSettings, object: nil) }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.menuSettings)

            Button(action: { showingCosmetics = true }) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.cosmeticsTitle)

            Button(action: { showingAtlas = true }) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.atlasTitle)

            Button(action: { showingHelp = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.helpTitle)

            Spacer()

            Button(action: { NSApp.terminate(nil) }) {
                Image(systemName: "power")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.menuQuit)
        }
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text(Strings.renameTitle)
                .font(.headline)
            TextField(Strings.renamePlaceholder, text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit { commitRename() }
            HStack(spacing: 12) {
                Button(Strings.renameCancel) { isRenaming = false }
                    .keyboardShortcut(.cancelAction)
                Button(Strings.renameConfirm) { commitRename() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 260)
    }

    private func startRename() {
        renameText = companion.name
        isRenaming = true
    }

    private func commitRename() {
        store.rename(to: renameText)
        isRenaming = false
    }
}

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(Strings.helpTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                helpRow("hand.tap", Strings.helpTipPet)
                helpRow("cursorarrow.click.2", Strings.helpTipClick)
                helpRow("pencil", Strings.helpTipRename)
                helpRow("face.smiling", Strings.helpTipQuips)
                helpRow("arrow.up.circle", Strings.helpTipLevel)
                helpRow("sparkles", Strings.helpTipCosmetics)
                helpRow("brain", Strings.helpTipAI)
                helpRow("bolt.fill", Strings.helpTipTriggers)
                helpRow("moon.fill", Strings.helpTipDND)
            }

            Divider()

            HStack(spacing: 4) {
                Text(Strings.helpMore)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Button(action: {
                    if let url = URL(string: "https://kingcos.github.io/MenuBuddy/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("kingcos.github.io/MenuBuddy")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 300)
    }

    private func helpRow(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.accentColor)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

