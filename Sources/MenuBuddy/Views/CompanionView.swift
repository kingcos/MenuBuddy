import SwiftUI
import AppKit

// MARK: - Animation Constants (matching buddy source)
let tickInterval: TimeInterval = 0.5     // 500ms tick
let bubbleShowTicks = 20                  // ~10s
let fadeWindowTicks = 6                   // last ~3s

// Idle sequence: frame index, -1 = blink on frame 0
let idleSequence = [0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]

let petHearts = [
    "   ♥    ♥   ",
    "  ♥  ♥   ♥  ",
    " ♥   ♥  ♥   ",
    "♥  ♥      ♥ ",
    "·    ·   ·  ",
]

func quipsFor(species: Species) -> [String] {
    Strings.speciesQuips(for: species) + Strings.genericQuips
}

// MARK: - Shuffled Quip Deck

/// Cycles through all quips in shuffled order before repeating.
/// Never shows the same quip twice in a row across shuffles.
private struct QuipDeck {
    private var deck: [String] = []
    private var index = 0
    private let source: () -> [String]

    init(source: @escaping () -> [String]) {
        self.source = source
        refill()
    }

    mutating func next() -> String {
        if index >= deck.count { refill() }
        let quip = deck[index]
        index += 1
        return quip
    }

    private mutating func refill() {
        let current = deck.last // avoid same quip at boundary
        deck = source().shuffled()
        if deck.first == current, deck.count > 1 {
            deck.swapAt(0, 1) // move the repeated quip away from front
        }
        index = 0
    }
}

// MARK: - Animation Engine

/// Owns the 500ms tick timer. Lives as @StateObject so it's created once
/// per popover show and released on disappear.
@MainActor
final class AnimationEngine: ObservableObject {
    @Published var tickIndex = 0
    @Published var petHeartFrame: Int? = nil
    @Published var speechText: String? = nil
    @Published var speechTick = 0

    private var mainTimer: Timer?
    private var nextQuipTask: Task<Void, Never>?
    private var isMuted: Bool = false
    private var species: Species = .duck
    private var quipDeck: QuipDeck = QuipDeck(source: { Strings.genericQuips })
    private var workspaceObserver: NSObjectProtocol?
    private var lastContextBundleId: String = ""

    /// Called when a pet is triggered; returns optional milestone message.
    var onPet: (() -> String?)? = nil

    var currentSequenceIndex: Int { tickIndex % idleSequence.count }
    var currentFrame: Int {
        let f = idleSequence[currentSequenceIndex]
        return f < 0 ? 0 : f
    }
    var isBlink: Bool { idleSequence[currentSequenceIndex] < 0 }
    var speechFading: Bool { (bubbleShowTicks - speechTick) <= fadeWindowTicks }

    func start(muted: Bool, species: Species, isFirstLaunch: Bool, companionName: String) {
        isMuted = muted
        self.species = species
        quipDeck = QuipDeck(source: { quipsFor(species: species) })
        guard mainTimer == nil else { return } // already running
        mainTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        if isFirstLaunch {
            // Welcome message on very first launch
            scheduleWelcome(name: companionName, delay: 2.0)
        } else {
            scheduleNextQuip(delay: Double.random(in: 5...15))
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleId = app.bundleIdentifier,
                  bundleId != "com.menubuddy.app"  // ignore ourselves
            else { return }
            Task { @MainActor [weak self] in self?.handleAppActivation(bundleId: bundleId) }
        }
    }

    private func handleAppActivation(bundleId: String) {
        guard !isMuted, speechText == nil else { return }
        guard bundleId != lastContextBundleId else { return }  // same app, skip
        lastContextBundleId = bundleId

        let quip: String? = {
            switch true {
            case bundleId.hasPrefix("com.apple.dt.Xcode"),
                 bundleId.hasPrefix("com.microsoft.VSCode"),
                 bundleId.hasPrefix("com.jetbrains"),
                 bundleId.contains("cursor"),
                 bundleId.contains("zed"):
                return Strings.appCodingQuip
            case bundleId.hasPrefix("com.apple.Terminal"),
                 bundleId.hasPrefix("com.googlecode.iterm2"),
                 bundleId.hasPrefix("dev.warp"),
                 bundleId.contains("terminal"),
                 bundleId.contains("hyper"):
                return Strings.appTerminalQuip
            case bundleId.hasPrefix("com.apple.Safari"),
                 bundleId.hasPrefix("com.google.Chrome"),
                 bundleId.hasPrefix("org.mozilla.firefox"),
                 bundleId.hasPrefix("company.thebrowser"),   // Arc
                 bundleId.hasPrefix("com.microsoft.edgemac"):
                return Strings.appBrowsingQuip
            case bundleId.hasPrefix("com.tinyspeck.slackmacgap"),
                 bundleId.hasPrefix("com.hnc.Discord"),
                 bundleId.hasPrefix("com.microsoft.teams"),
                 bundleId.hasPrefix("ru.keepcoder.Telegram"):
                return Strings.appChattingQuip
            case bundleId.hasPrefix("com.figma"),
                 bundleId.hasPrefix("com.bohemiancoding.sketch"),
                 bundleId.hasPrefix("com.affinity"):
                return Strings.appDesignQuip
            case bundleId.hasPrefix("com.spotify.client"),
                 bundleId.hasPrefix("com.apple.Music"):
                return Strings.appMusicQuip
            default:
                return nil
            }
        }()

        guard let quip else { return }
        // 25% chance so context quips don't get annoying
        guard Double.random(in: 0...1) < 0.25 else { return }
        showSpeech(quip)
    }

    /// Called by PopoverView when a system event fires, to show a relevant quip.
    func showSystemQuip(for event: SystemEvent) {
        guard !isMuted, speechText == nil else { return }
        let quip: String?
        switch event {
        case .cpuHigh:         quip = Strings.cpuHighQuips.randomElement()
        case .memHigh:         quip = Strings.memHighQuips.randomElement()
        case .netFast:         quip = Strings.netFastQuips.randomElement()
        case .netSlow:         quip = Strings.netSlowQuips.randomElement()
        case .batteryLow:      quip = Strings.batteryLowQuips.randomElement()
        case .batteryCharging: quip = Strings.batteryChargingQuip
        case .diskBusy:        quip = Strings.diskBusyQuips.randomElement()
        }
        if let q = quip { showSpeech(q) }
    }

    func stop() {
        mainTimer?.invalidate()
        mainTimer = nil
        nextQuipTask?.cancel()
        nextQuipTask = nil
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
    }

    func updateMuted(_ muted: Bool) {
        isMuted = muted
        if muted { withAnimation { speechText = nil } }
    }

    func triggerPet() {
        petHeartFrame = 0
        // Check for milestone first, otherwise use pet response
        let message = onPet?() ?? Strings.petResponses.randomElement() ?? "♥"
        showSpeech(message)
    }

    private func tick() {
        tickIndex += 1

        // Advance pet hearts
        if let frame = petHeartFrame {
            let next = frame + 1
            petHeartFrame = next < petHearts.count ? next : nil
        }

        // Advance speech bubble
        if speechText != nil {
            speechTick += 1
            if speechTick >= bubbleShowTicks {
                withAnimation { speechText = nil }
                speechTick = 0
                scheduleNextQuip(delay: Double.random(in: 15...45))
            }
        }
    }

    private func scheduleWelcome(name: String, delay: TimeInterval) {
        nextQuipTask?.cancel()
        nextQuipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.showSpeech(Strings.welcome(name))
            // Schedule regular quips after welcome
            self?.scheduleNextQuip(delay: Double.random(in: 12...20))
        }
    }

    private func scheduleNextQuip(delay: TimeInterval) {
        nextQuipTask?.cancel()
        nextQuipTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.showRandomQuip()
        }
    }

    private func showRandomQuip() {
        guard !isMuted else { return }
        showSpeech(quipDeck.next())
    }

    func showSpeech(_ text: String) {
        withAnimation {
            speechText = text
            speechTick = 0
        }
    }
}

// MARK: - Speech Bubble

struct SpeechBubbleView: View {
    let text: String
    let color: String
    let fading: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .italic()
                .foregroundColor(fading ? .secondary : .primary)
                .opacity(fading ? 0.5 : 1.0)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Strings.a11ySpeechLabel(text))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: color).opacity(fading ? 0.3 : 0.7), lineWidth: 1)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(hex: color).opacity(0.06))
                        )
                )
            VStack {
                Spacer()
                Text("╲")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: color).opacity(fading ? 0.3 : 0.7))
                    .padding(.bottom, 2)
            }
            .frame(height: 36)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stats View

struct StatsView: View {
    let stats: [StatName: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(StatName.allCases, id: \.self) { stat in
                let value = stats[stat] ?? 0
                HStack(spacing: 6) {
                    Text(Strings.statName(stat))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 72, alignment: .leading)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.secondary.opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(statColor(value))
                                .frame(width: geo.size.width * CGFloat(value) / 100, height: 4)
                        }
                    }
                    .frame(height: 4)
                    Text("\(value)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Strings.a11yStatLabel(Strings.statName(stat), value))
            }
        }
    }

    private func statColor(_ v: Int) -> Color {
        switch v {
        case 75...: return .green
        case 50...: return .blue
        case 25...: return .orange
        default: return .red
        }
    }
}

// MARK: - System Status Strip

struct SystemStatusView: View {
    let snapshot: SystemSnapshot

    var body: some View {
        HStack(spacing: 10) {
            metricPill(label: Strings.sysstatCPU,
                       value: "\(Int(snapshot.cpuUsage * 100))%",
                       alert: snapshot.cpuUsage > 0.70)
            metricPill(label: Strings.sysstatMEM,
                       value: "\(Int((1 - snapshot.memFree) * 100))%",
                       alert: snapshot.memFree < 0.15)
            metricPill(label: Strings.sysstatNET,
                       value: netLabel(snapshot.netBytesPerSec),
                       alert: false)
            if snapshot.diskBytesPerSec > 0 {
                metricPill(label: Strings.sysstatDisk,
                           value: netLabel(snapshot.diskBytesPerSec),
                           alert: snapshot.diskBytesPerSec > 50_000_000)
            }
            if let bat = snapshot.batteryPct {
                metricPill(label: snapshot.isCharging ? Strings.sysstatCharging : Strings.sysstatBAT,
                           value: "\(Int(bat * 100))%",
                           alert: bat < 0.20 && !snapshot.isCharging)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func metricPill(label: String, value: String, alert: Bool) -> some View {
        VStack(spacing: 1) {
            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(alert ? .orange : .secondary)
            Text(value)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(alert ? .orange : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private func netLabel(_ bps: UInt64) -> String {
        if bps >= 1_000_000 {
            return Strings.sysstatNetMB(Double(bps) / 1_000_000)
        } else {
            return Strings.sysstatNetKB(Double(bps) / 1_000)
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}
