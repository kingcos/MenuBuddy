# MenuBuddy

A tiny companion pet that lives in your macOS menu bar. Click the icon to open the popover and see your buddy — an animated ASCII creature unique to your machine.

## Features

- **18 species**: duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk
- **5 rarity tiers**: common → uncommon → rare → epic → legendary (1% chance)
- **1% shiny** variant with golden glow
- **Deterministic generation**: your buddy is derived from your machine UUID — same machine, same buddy, always
- **Idle animations**: 3-frame fidget loop with blink, at 500ms tick rate
- **Speech bubbles**: species-specific personality quips every 15–45s, fade out gracefully
- **Pet interaction**: tap the sprite for a heart burst
- **Stats panel**: DEBUGGING / PATIENCE / CHAOS / WISDOM / SNARK
- **Rename**: pencil button in header or "Rename…" in context menu
- **Mute**: silence the speech bubbles
- **Launch at Login**: register as a login item via context menu
- **LSUIElement mode**: no Dock icon, lives only in the menu bar

## Requirements

- macOS 14+
- Swift 5.9+ (Xcode 15+)

## Build

```bash
make build    # swift build -c release, creates .build/release/MenuBuddy.app (ad-hoc signed)
make run      # builds then opens the .app
make install  # builds then copies to /Applications/MenuBuddy.app
make clean    # swift package clean
```

## Project Structure

```
Sources/MenuBuddy/
├── main.swift                     # Entry point
├── App/AppDelegate.swift          # NSStatusItem, NSPopover, context menu
├── Models/
│   ├── CompanionTypes.swift       # Species, Rarity, Eye, Hat, StatName enums
│   ├── CompanionModel.swift       # Mulberry32 PRNG + FNV-1a, deterministic generation
│   └── CompanionStore.swift       # UserDefaults persistence for name/personality
├── Sprites/
│   ├── SpriteData.swift           # ASCII art frames for all 18 species
│   └── SpriteRenderer.swift       # renderSprite(), renderFace()
└── Views/
    ├── CompanionView.swift        # AnimationEngine, SpeechBubbleView, StatsView
    └── PopoverView.swift          # Main popover UI
```

## How companion generation works

Your companion is generated deterministically from your machine's IOPlatformUUID, salted and hashed with FNV-1a 32-bit, then fed into a Mulberry32 PRNG. The resulting sequence picks rarity, species, eye style, hat, shiny chance, and stats in order — same inputs always yield the same output.

Only the companion's **name** is stored in UserDefaults and can be edited. Everything else is derived at runtime from your machine UUID, so editing preferences can't fake a legendary.

## Acknowledgements

Companion design inspired by the Claude Code buddy system (`buddy/` folder).
