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
            if let text = engine.speechText {
                SpeechBubbleView(
                    text: text,
                    color: companion.rarity.color,
                    fading: engine.speechFading
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 6)
                .transition(.opacity.animation(.easeInOut(duration: 0.3)))
            }
            Divider()
            StatsView(stats: companion.stats)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            engine.onPet = { store.recordPet() }
            engine.start(
                muted: store.muted,
                species: companion.species,
                isFirstLaunch: store.isFirstLaunch,
                companionName: companion.name
            )
        }
        .onDisappear { engine.stop() }
        .onChange(of: store.muted) { _, newValue in engine.updateMuted(newValue) }
        .onReceive(NotificationCenter.default.publisher(for: .triggerPet)) { _ in
            engine.triggerPet()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRename)) { _ in
            startRename()
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
                    if companion.shiny {
                        Text("✨")
                            .font(.system(size: 11))
                    }
                }
                Text("\(companion.species.rawValue.capitalized) · \(companion.rarity.rawValue.capitalized)")
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
                .help("Rename \(companion.name)")
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
            .onTapGesture { engine.triggerPet() }
            .help("Tap to pet \(companion.name)!")
        }
        .padding(.vertical, 8)
    }

    // MARK: - Rename Sheet

    private var renameSheet: some View {
        VStack(spacing: 16) {
            Text("Rename your buddy")
                .font(.headline)
            TextField("Name", text: $renameText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
                .onSubmit { commitRename() }
            HStack(spacing: 12) {
                Button("Cancel") { isRenaming = false }
                    .keyboardShortcut(.cancelAction)
                Button("Rename") { commitRename() }
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

