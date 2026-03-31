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

private let companionQuips = [
    "…", "*yawns*", "*stares at you*", "meep.", "*wiggles*",
    "did you pet me yet", "i am watching.", "*does a little spin*",
    "working hard?", "proud of u :)", "*blinks slowly*",
    "almost done?", "you got this!", "*investigates cursor*", "bzzt.",
    "hi.", "sup.", "*stretches*", "still here.", "…ok.",
]

private let petResponses = ["♥", "hehe", "*purrs*", "yay!", "uwu", "eee!"]

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

    var currentSequenceIndex: Int { tickIndex % idleSequence.count }
    var currentFrame: Int {
        let f = idleSequence[currentSequenceIndex]
        return f < 0 ? 0 : f
    }
    var isBlink: Bool { idleSequence[currentSequenceIndex] < 0 }
    var speechFading: Bool { (bubbleShowTicks - speechTick) <= fadeWindowTicks }

    func start(muted: Bool) {
        isMuted = muted
        mainTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        scheduleNextQuip(delay: Double.random(in: 5...15))
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
        showSpeech(petResponses.randomElement() ?? "♥")
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
        showSpeech(companionQuips.randomElement() ?? "…")
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
