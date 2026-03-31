import Foundation

// MARK: - Sprite Renderer (ported from buddy/sprites.ts)

/// Renders a companion sprite for a given animation frame.
/// Returns an array of text lines.
func renderSprite(bones: CompanionBones, frame: Int = 0, blink: Bool = false) -> [String] {
    guard let frames = spriteFrames[bones.species] else { return [] }

    let frameIndex = frame % frames.count
    // Blink uses "-" (single dash, same width as eye char) to keep ASCII art aligned.
    let eyeChar = blink ? "-" : bones.eye.character

    var lines = frames[frameIndex].map { line in
        line.replacingOccurrences(of: "{E}", with: eyeChar)
    }

    // Insert hat on line 0 if line 0 is blank
    if bones.hat != .none && lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
        lines[0] = bones.hat.line
    }

    // Drop blank hat slot if ALL frames have blank line 0
    let allFramesHaveBlankLine0 = frames.allSatisfy { $0.first?.trimmingCharacters(in: .whitespaces).isEmpty == true }
    if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true && allFramesHaveBlankLine0 {
        lines.removeFirst()
    }

    return lines
}

/// Returns a compact face string for use in menu bar status button.
func renderFace(bones: CompanionBones) -> String {
    let e = bones.eye.character
    switch bones.species {
    case .duck, .goose:
        return "(\(e)>"
    case .blob:
        return "(\(e)\(e))"
    case .cat:
        return "=\(e)ω\(e)="
    case .dragon:
        return "<\(e)~\(e)>"
    case .octopus:
        return "~(\(e)\(e))~"
    case .owl:
        return "(\(e))(\(e))"
    case .penguin:
        return "(\(e)>)"
    case .turtle:
        return "[\(e)_\(e)]"
    case .snail:
        return "\(e)(@)"
    case .ghost:
        return "/\(e)\(e)\\"
    case .axolotl:
        return "}\(e).\(e){"
    case .capybara:
        return "(\(e)oo\(e))"
    case .cactus:
        return "|\(e)  \(e)|"
    case .robot:
        return "[\(e)\(e)]"
    case .rabbit:
        return "(\(e)..\(e))"
    case .mushroom:
        return "|\(e)  \(e)|"
    case .chonk:
        return "(\(e).\(e))"
    }
}

/// Returns the number of animation frames for a species.
func spriteFrameCount(species: Species) -> Int {
    return spriteFrames[species]?.count ?? 3
}
