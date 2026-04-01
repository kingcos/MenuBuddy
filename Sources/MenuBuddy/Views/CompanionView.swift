import SwiftUI

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

// Generic quips (fallback)
private let genericQuips = [
    "…", "*yawns*", "*stares at you*", "meep.", "*wiggles*",
    "did you pet me yet", "i am watching.", "*does a little spin*",
    "working hard?", "proud of u :)", "*blinks slowly*",
    "almost done?", "you got this!", "*investigates cursor*",
    "hi.", "sup.", "*stretches*", "still here.", "…ok.",
]

// Species-specific quips — personality flavoring
private let speciesQuips: [Species: [String]] = [
    .duck:     ["quack.", "*quacks softly*", "bread?", "QUACK.", "*shakes tail feathers*"],
    .goose:    ["HONK.", "mine.", "*stares menacingly*", "honk honk.", "i want that."],
    .blob:     ["blop.", "*jiggles*", "bloop?", "*merges with shadow*", "i am formless."],
    .cat:      ["*knocks something off the desk*", "feed me.", "*loafs*", "purrr.", "no."],
    .dragon:   ["*smoke from nostrils*", "scales: perfect.", "fire later.", "*hoards things*"],
    .octopus:  ["*eight-armed hug?*", "i have plans.", "*changes color*", "ink. soon."],
    .owl:      ["*rotates head*", "wise. very wise.", "hoot.", "*judges quietly*", "observed."],
    .penguin:  ["*waddles*", "cold please.", "*slides on belly*", "fish time?", "tuxedo ready."],
    .turtle:   ["*retreats into shell*", "slowly.", "patience.", "*peeks out*", "no rush."],
    .snail:    ["still getting there.", "*leaves trail*", "…", "*slides imperceptibly*"],
    .ghost:    ["boo.", "*fades slightly*", "spooky?", "*floats through wall*", "haunting vibes."],
    .axolotl:  ["*regenerates*", "neotenic.", "*wiggles gills*", "axolotl rights.", "yep."],
    .capybara: ["chill.", "*lets other animals sit on me*", "content.", "*closes eyes*", "ok."],
    .cactus:   ["*grows slowly*", "prickly today.", "*photosynthesizes*", "don't touch.", "…"],
    .robot:    ["processing…", "beep boop.", "01101000 01101001", "*whirrs*", "calculating."],
    .rabbit:   ["*nose twitch*", "hop.", "*binkies*", "lettuce?", "*digs determinedly*"],
    .mushroom: ["*sporulates*", "decomposing things.", "fungi vibes.", "*grows quietly*"],
    .chonk:    ["*sits heavily*", "big.", "chonky and content.", "*belly flop*", "dense."],
]

private let petResponses = ["♥", "hehe", "*purrs*", "yay!", "uwu", "eee!", "*happy wiggle*"]

func quipsFor(species: Species) -> [String] {
    let specific = speciesQuips[species] ?? []
    return specific + genericQuips
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
    private var quipDeck: QuipDeck = QuipDeck(source: { genericQuips })

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
        }
        if let q = quip { showSpeech(q) }
    }

    func stop() {
        mainTimer?.invalidate()
        mainTimer = nil
        nextQuipTask?.cancel()
        nextQuipTask = nil
    }

    func updateMuted(_ muted: Bool) {
        isMuted = muted
        if muted { withAnimation { speechText = nil } }
    }

    func triggerPet() {
        petHeartFrame = 0
        // Check for milestone first, otherwise use pet response
        let message = onPet?() ?? petResponses.randomElement() ?? "♥"
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
