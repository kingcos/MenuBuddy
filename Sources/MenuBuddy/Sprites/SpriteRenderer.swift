import Foundation

// MARK: - Sprite Renderer (ported from buddy/sprites.ts)

/// Renders a companion sprite for a given animation frame.
/// Returns an array of text lines.
func renderSprite(bones: CompanionBones, frame: Int = 0, blink: Bool = false, cosmeticModifier: SpriteModifier? = nil) -> [String] {
    guard let frames = spriteFrames[bones.species] else { return [] }

    let frameIndex = frame % frames.count

    // Eye character: cosmetic override > blink > default
    // Cosmetic eyes always win (no blink flicker for equipped eye styles)
    let eyeChar: String
    if let cosmeticEye = cosmeticModifier?.eyeChar {
        eyeChar = cosmeticEye
    } else if blink {
        eyeChar = "-"
    } else {
        eyeChar = bones.eye.character
    }

    var lines = frames[frameIndex].map { line in
        line.replacingOccurrences(of: "{E}", with: eyeChar)
    }

    // Hat: cosmetic hat > bones hat > none
    let hatLine = cosmeticModifier?.hatLine ?? (bones.hat != .none ? bones.hat.line : nil)
    if let hatLine, lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true {
        lines[0] = hatLine
    }

    // Drop blank hat slot if ALL frames have blank line 0
    let allFramesHaveBlankLine0 = frames.allSatisfy { $0.first?.trimmingCharacters(in: .whitespaces).isEmpty == true }
    if lines.first?.trimmingCharacters(in: .whitespaces).isEmpty == true && allFramesHaveBlankLine0 {
        lines.removeFirst()
    }

    // Apply accessory modifiers (left/right decorations on middle line)
    if let mod = cosmeticModifier {
        let midIndex = lines.count / 2
        if let left = mod.accessoryLeft {
            lines[midIndex] = left + lines[midIndex]
        }
        if let right = mod.accessoryRight {
            lines[midIndex] = lines[midIndex] + right
        }

        // Apply aura (top/bottom decorations)
        if let auraTop = mod.auraTop {
            lines.insert(auraTop, at: 0)
        }
        if let auraBottom = mod.auraBottom {
            lines.append(auraBottom)
        }

        // Apply frame (left/right on all lines)
        if let frameLeft = mod.frameLeft, let frameRight = mod.frameRight {
            lines = lines.map { frameLeft + $0 + frameRight }
        }
    }

    return lines
}

/// Returns a compact face string for use in menu bar status button.
/// - eyeOverride: if non-nil, replaces the eye character (e.g. "x" for stressed state)
func renderFace(bones: CompanionBones, blink: Bool = false, eyeOverride: String? = nil) -> String {
    let e = eyeOverride ?? (blink ? "-" : bones.eye.character)
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
