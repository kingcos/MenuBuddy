import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: CompanionStore
    @StateObject private var engine = AnimationEngine()
    @State private var isRenaming = false
    @State private var renameText = ""

    var companion: Companion { store.companion }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            spriteAreaView
            SpeechBubbleView(
                text: engine.speechText ?? " ",
                color: companion.rarity.color,
                fading: engine.speechFading
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
            .opacity(engine.speechText != nil ? 1 : 0)
            Divider()
            StatsView(stats: companion.stats)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
            if let snap = store.systemSnapshot {
                Divider()
                SystemStatusView(snapshot: snap, prev: store.prevSystemSnapshot)
            }
            hatchFooter
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            Divider()
            popoverToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            engine.onPet = { store.recordPet() }
            store.onSystemEvent = { [weak engine] event in engine?.showSystemQuip(for: event) }
            engine.start(
                muted: store.muted,
                species: companion.species,
                isFirstLaunch: store.isFirstLaunch,
                companionName: companion.name
            )
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
            // Show daily time-of-day greeting (once per day, not on first launch)
            else if !store.isFirstLaunch, let greeting = store.consumeDailyGreeting() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    engine.showSpeech(greeting)
                }
            }
        }
        .onDisappear {
            store.onSystemEvent = nil
            engine.stop()
        }
        .onChange(of: store.muted) { _, newValue in engine.updateMuted(newValue) }
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
    }

    // MARK: - Header

    private var headerView: some View {
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
                Text(companion.rarity.stars)
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: companion.rarity.color))
                Button(action: startRename) {
                    Image(systemName: "pencil.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(Strings.menuRename(companion.name))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
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
                blink: engine.isBlink
            )
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(companion.shiny ? Color(hex: "#f59e0b") : .primary)
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

            Button(action: { NotificationCenter.default.post(name: .openAbout, object: nil) }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(Strings.menuAbout)

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

