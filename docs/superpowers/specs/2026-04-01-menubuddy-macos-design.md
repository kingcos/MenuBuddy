# MenuBuddy macOS Menu Bar App — Design Spec

**Date:** 2026-04-01
**Status:** Approved

## Overview

A standalone macOS menu bar companion pet app (Swift, macOS 14+) inspired by the Claude Code buddy system. The app lives exclusively in the menu bar (LSUIElement mode, no Dock icon) and shows an animated ASCII-art companion in a popover.

---

## Architecture

### Project Structure
```
MenuBuddy/
├── Package.swift
├── Makefile
├── Sources/
│   └── MenuBuddy/
│       ├── main.swift                    # Entry point
│       ├── App/
│       │   └── AppDelegate.swift         # NSStatusItem, popover management
│       ├── Models/
│       │   ├── CompanionTypes.swift      # Species, Rarity, Eyes, Hats, Stats enums
│       │   ├── CompanionModel.swift      # Deterministic generation (Mulberry32 PRNG)
│       │   └── CompanionStore.swift      # Persistence via UserDefaults
│       ├── Sprites/
│       │   ├── SpriteData.swift          # ASCII art frame data for all 18 species
│       │   └── SpriteRenderer.swift      # renderSprite(), renderFace() functions
│       └── Views/
│           ├── PopoverView.swift         # Main SwiftUI popover content
│           ├── CompanionView.swift       # Animated companion sprite display
│           └── StatsView.swift          # Stats display panel
└── Resources/
    └── Info.plist                        # LSUIElement = true
```

### Key Decisions
- **LSUIElement**: `Info.plist` sets `LSUIElement = YES` and `NSPrincipalClass` = `NSApplication`
- **SPM only**: No Xcode project, built entirely via `swift build`
- **Ad-hoc signing**: `codesign --sign -` produces a valid .app bundle for local use
- **SwiftUI popover**: NSPopover with SwiftUI content view

---

## Components

### 1. Companion Model (`CompanionModel.swift`)

Ports the TypeScript Mulberry32 PRNG and companion generation:

- **Hash function**: FNV-1a 32-bit hash of machine UUID + salt `"friend-2026-401"`
- **Mulberry32 PRNG**: Seeded from hash, generates deterministic random sequence
- **Generation**: species, rarity, eye, hat, shiny, stats — all deterministic from machine UUID
- **Soul persistence**: name (user-editable) stored in UserDefaults; bones always regenerated

**Rarity weights**: common 60%, uncommon 25%, rare 10%, epic 4%, legendary 1%

**Species** (18): duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

**Eyes** (6): `·`, `✦`, `×`, `◉`, `@`, `°`

**Hats** (8): none, crown, tophat, propeller, halo, wizard, beanie, tinyduck

**Stats** (5): DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK

### 2. Sprite System (`SpriteData.swift` + `SpriteRenderer.swift`)

Direct port of the TypeScript sprite system:
- 5 lines × 12 chars per frame
- 3 frames per species for idle animation
- Line 0 is hat slot (blank for hat insertion)
- `{E}` placeholder replaced with chosen eye character
- `renderSprite(bones, frame) -> [String]` — returns lines array
- `renderFace(bones) -> String` — returns compact face for menu bar icon

### 3. Animation Engine (in `CompanionView.swift`)

- **500ms tick** via `Timer.scheduledTimer`
- **Idle sequence**: `[0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]` (frame -1 = blink)
- **Blink**: Replace eye chars with `--` on frame 0
- **Pet interaction**: Tap companion → hearts float for 2.5s (5 frames × 500ms)
- **Speech bubbles**: Appear for 20 ticks (~10s), fade in last 6 ticks (~3s)

### 4. Menu Bar Integration (`AppDelegate.swift`)

- `NSStatusItem` with width `NSVariableStatusItemLength`
- Status button shows companion face emoji (from `renderFace()`) as title
- **Left-click**: Toggle NSPopover
- **Right-click**: Context menu with:
  - "Pet [name]" — trigger pet animation
  - Separator
  - "Mute Buddy" toggle
  - "About MenuBuddy"
  - Separator
  - "Quit"
- Popover auto-closes when clicking outside

### 5. Popover View (`PopoverView.swift`)

Fixed width ~300pt popover containing:
- Companion name + rarity stars (top)
- Animated ASCII sprite (monospaced font, centered)
- Speech bubble (when companion speaks)
- Stats grid (bottom): 5 stats with progress bars
- "Pet" button

---

## Data Flow

```
Machine UUID → FNV-1a hash → Mulberry32 PRNG → CompanionBones
UserDefaults → name, hatchedAt → CompanionSoul
Bones + Soul → Companion (full model)

Timer(500ms) → AnimationEngine → frame index → SpriteRenderer → SwiftUI Text
UserTap → pet state → heart animation (2.5s)
CompanionThinking → speech text → SpeechBubble (20 ticks, fades last 6)
```

---

## Build & Makefile

```makefile
build:   swift build -c release
run:     .build/release/MenuBuddy
install: cp -r .build/release/MenuBuddy.app /Applications/
clean:   swift package clean
```

The `install` target creates a signed `.app` bundle.

---

## Commit Plan

1. Project scaffolding (Package.swift, Info.plist, Makefile, .gitignore)
2. Companion model (types, PRNG, generation)
3. Sprite data and renderer
4. AppDelegate + menu bar integration
5. SwiftUI popover views
6. Animation engine + interactions
7. Polish + README
