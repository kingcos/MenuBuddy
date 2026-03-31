import SwiftUI

// MARK: - Animation Constants (matching buddy source)
private let tickMs: TimeInterval = 0.5          // 500ms tick
private let bubbleShowTicks = 20                 // ~10s
private let fadeWindowTicks = 6                  // last ~3s
private let petBurstMs: TimeInterval = 2.5       // 2.5s hearts

// Idle sequence: frame index or -1 for blink
private let idleSequence = [0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]

// Heart burst frames (5 ticks)
private let petHearts = [
    "   ♥    ♥   ",
    "  ♥  ♥   ♥  ",
    " ♥   ♥  ♥   ",
    "♥  ♥      ♥ ",
    "·    ·   ·  ",
]

// Random companion quips
private let companionQuips = [
    "…",
    "*yawns*",
    "*stares at you*",
    "meep.",
    "*wiggles*",
    "did you pet me yet",
    "i am watching.",
    "*does a little spin*",
    "working hard?",
    "proud of u :)",
    "*blinks slowly*",
    "almost done?",
    "you got this!",
    "*investigates cursor*",
    "bzzt.",
]

// MARK: - Companion View

struct CompanionView: View {
    @ObservedObject var store: CompanionStore
    var onPet: (() -> Void)?

    // Animation state
    @State private var tickIndex = 0
    @State private var timer: Timer?

    // Pet state
    @State private var petFrameIndex: Int? = nil
    @State private var petTimer: Timer?

    // Speech bubble
    @State private var speechText: String? = nil
    @State private var speechTick = 0
    @State private var speechTimer: Timer?

    var companion: Companion { store.companion }

    // Current sprite frame from idle sequence (-1 means blink on frame 0)
    private var currentSequenceIndex: Int { tickIndex % idleSequence.count }
    private var currentFrame: Int {
        let f = idleSequence[currentSequenceIndex]
        return f < 0 ? 0 : f
    }
    private var isBlink: Bool { idleSequence[currentSequenceIndex] < 0 }

    var body: some View {
        VStack(spacing: 8) {
            // Header: name + rarity
            HStack {
                Text(companion.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Spacer()
                Text(companion.rarity.stars)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: companion.rarity.color))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Sprite area
            VStack(spacing: 2) {
                // Pet hearts (shown above sprite during pet burst)
                if let petFrame = petFrameIndex, petFrame < petHearts.count {
                    Text(petHearts[petFrame])
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.pink)
                        .transition(.opacity)
                }

                // ASCII sprite
                let lines = renderSprite(bones: companion.bones, frame: currentFrame, blink: isBlink)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(companion.shiny ? Color(hex: "#f59e0b") : .primary)
                    }
                }
                .onTapGesture {
                    triggerPet()
                }
                .help("Tap to pet \(companion.name)!")
            }
            .padding(.vertical, 4)

            // Speech bubble
            if let text = speechText {
                let ticksLeft = bubbleShowTicks - speechTick
                let fading = ticksLeft <= fadeWindowTicks
                SpeechBubbleView(text: text, color: companion.rarity.color, fading: fading)
                    .padding(.horizontal, 12)
                    .transition(.opacity)
            }

            Divider()

            // Stats
            StatsView(stats: companion.stats)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
        .frame(width: 280)
        .onAppear {
            startIdleTimer()
            scheduleSpeech()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: - Timers

    private func startIdleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: tickMs, repeats: true) { _ in
            tickIndex += 1

            // Advance speech bubble
            if speechText != nil {
                speechTick += 1
                if speechTick >= bubbleShowTicks {
                    withAnimation { speechText = nil }
                    speechTick = 0
                    // Schedule next quip
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 15...45)) {
                        showRandomQuip()
                    }
                }
            }
        }
    }

    private func scheduleSpeech() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 5...15)) {
            showRandomQuip()
        }
    }

    private func showRandomQuip() {
        guard !store.muted else { return }
        withAnimation {
            speechText = companionQuips.randomElement()
            speechTick = 0
        }
    }

    private func triggerPet() {
        onPet?()
        petTimer?.invalidate()
        petFrameIndex = 0

        var frame = 0
        petTimer = Timer.scheduledTimer(withTimeInterval: petBurstMs / Double(petHearts.count), repeats: true) { t in
            frame += 1
            if frame < petHearts.count {
                withAnimation { petFrameIndex = frame }
            } else {
                t.invalidate()
                withAnimation { petFrameIndex = nil }
            }
        }

        // Show a pet response quip
        withAnimation {
            speechText = ["♥", "hehe", "*purrs*", "yay!", "uwu"].randomElement()
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
            VStack(alignment: .leading, spacing: 0) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .italic()
                    .foregroundColor(fading ? .secondary : .primary)
                    .opacity(fading ? 0.5 : 1.0)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: color).opacity(fading ? 0.3 : 0.8), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hex: color).opacity(0.05))
                    )
            )

            // Tail pointing down-left toward sprite
            VStack {
                Spacer()
                Text("╲")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color(hex: color).opacity(fading ? 0.3 : 0.8))
            }
        }
    }
}

// MARK: - Stats View

struct StatsView: View {
    let stats: [StatName: Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(StatName.allCases, id: \.self) { stat in
                HStack(spacing: 6) {
                    Text(stat.rawValue)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 72, alignment: .leading)

                    let value = stats[stat] ?? 0
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

                    Text("\(stats[stat] ?? 0)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    private func statColor(_ value: Int) -> Color {
        switch value {
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
