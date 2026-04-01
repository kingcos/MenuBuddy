# MenuBuddy

[中文说明](README.zh-CN.md)

A tiny companion pet that lives in your macOS menu bar. Click the icon to open the popover and see your buddy — an animated ASCII creature unique to your machine.

## Features

### Companion

- **18 species**: duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk
- **5 rarity tiers**: Common (60%) → Uncommon (25%) → Rare (10%) → Epic (4%) → Legendary (1%)
- **1% shiny** variant with golden glow
- **Deterministic generation**: your buddy is derived from your machine UUID — same machine, same buddy, always
- **Idle animations**: 3-frame fidget loop with blink, at 500ms tick rate
- **Speech bubbles**: species-specific and generic quips every 15–45s, fade out gracefully
- **Pet interaction**: tap the sprite for a heart burst; milestones at 1, 5, 10, 25, 50, 100 pets
- **Stats**: DEBUGGING / PATIENCE / CHAOS / WISDOM / SNARK — personality traits determined by species and rarity (hover for descriptions)
- **Rename**: pencil button in header, right-click menu, or Settings
- **Reset**: get a new companion with a fresh name (bones stay the same — they're machine-tied)

### Pluggable Trigger System

MenuBuddy uses a **plugin architecture** for driving companion reactions. Any data source can be a trigger — system stats, stock prices, weather, CI/CD status, etc. Each trigger source independently monitors its data and produces standardized events that drive the companion's expressions, quips, mood, and menu bar indicators.

```
┌───────────────┐  ┌──────────────┐  ┌───────────────┐
│ System Monitor│  │ Stock Prices │  │ Your Plugin   │
│ (built-in)    │  │ (example)    │  │               │
└──────┬────────┘  └──────┬───────┘  └───────┬───────┘
       │ TriggerEvent     │                   │
       ▼                  ▼                   ▼
  ┌──────────────────────────────────────────────────┐
  │              TriggerManager                      │
  │  routes events → mood, quips, indicator, eyes    │
  └──────────────────────────────────────────────────┘
```

**Built-in: System Monitor** — reacts to your Mac's real-time state:

| Metric | Threshold | Indicator | Mood |
|--------|-----------|-----------|------|
| CPU | >70% | 🔥 | 😰 stress eyes (×) |
| Memory | >85% used | 🧠 | 😵 squiggly eyes (~) |
| Network | >5 MB/s | ⚡ | 🚀 |
| Network | idle after active | 🐌 | flat eyes (_) |
| Disk I/O | >50 MB/s | 💾 | wide eyes (o) |
| Battery | <20% | 🪫 | tiny dot eyes (.) |
| Battery | charging | ⚡ | — |
| Idle | CPU <10%, no net | — | 😴 |

**Script triggers (no coding required):**

Drop any executable script into `~/.menubuddy/triggers/`. MenuBuddy runs it periodically and reads JSON from stdout:

```bash
#!/bin/bash
# ~/.menubuddy/triggers/stock.sh
curl -s "https://api.example.com/stock/AAPL" | jq '{
  name: "Stock Monitor",
  interval: 60,
  trigger: {
    indicator: "📈",
    quips: ["AAPL is moving!", "stonks!"],
    mood: "🤑",
    eyeOverride: "$",
    duration: 30
  },
  metrics: [
    { label: "AAPL", value: ("$" + (.price | tostring)), alert: (.change > 5), trend: (if .change > 0 then "↑" else "↓" end) }
  ]
}'
```

JSON format:

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name in Settings (default: filename) |
| `interval` | No | Polling interval in seconds (default: 60, min: 5) |
| `trigger.indicator` | Yes* | Emoji for menu bar (e.g. "📈") |
| `trigger.quips` | No | Speech bubble texts (one picked at random) |
| `trigger.mood` | No | Companion mood emoji override |
| `trigger.eyeOverride` | No | Menu bar face eye character |
| `trigger.duration` | No | How long indicator stays (default: 30s) |
| `metrics[].label` | Yes* | Metric label (e.g. "AAPL") |
| `metrics[].value` | Yes* | Metric value (e.g. "$189") |
| `metrics[].alert` | No | Highlight in orange (default: false) |
| `metrics[].trend` | No | "↑", "↓", or "" |

\* Required within their respective objects; both `trigger` and `metrics` are optional top-level.

Scripts can be bash, python, node, or any language. See `Examples/triggers/` for samples.

**Swift API (for compiled plugins):**

Implement the `TriggerSource` protocol and register with `store.triggerManager.register(source)`.

Each registered source appears in Settings → Trigger Sources and can be toggled on/off independently.

### Menu Bar

- **Animated face**: your companion's face animates in the menu bar with blink and idle frames
- **Trigger indicator emoji**: shows next to the face when an event is active (auto-clears after duration)
- **Menu bar quips**: buddy occasionally says something next to its face (every 2–5 min, clears after 6s)
- **Do Not Disturb**: configure quiet hours in Settings to suppress menu bar quips (supports overnight wrap, e.g. 22:00→08:00)

### Awareness

- **Sleep/wake**: buddy greets you when your Mac wakes up, with different messages based on sleep duration
- **Workspace**: 25% chance to comment when you switch to coding, terminal, browsing, chatting, design, or music apps
- **Time of day**: daily greeting (morning/afternoon/evening/night) on first popover open each day

### UI & Interaction

- **Left-click**: open/close popover
- **Right-click**: context menu with pet, rename, mute, launch at login, settings, about, quit
- **Popover toolbar**: settings gear, info, and quit buttons at the bottom — no need to right-click
- **Settings window**: General, Language, Menu Bar, Do Not Disturb, Trigger Sources, Help, and Reset sections
- **In-app language switcher**: System Default / English / 简体中文
- **Launch at Login**: via SMAppService
- **Mute**: silences all speech bubbles and menu bar quips
- **LSUIElement**: no Dock icon, lives only in the menu bar

### Internationalization

- **English** and **Simplified Chinese** (zh-Hans) fully supported
- 270+ localized string keys covering all UI, quips, stats, system messages, and accessibility labels
- In-app language switcher or follows system locale

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
├── L10n.swift                     # Localization helper + Strings enum
├── App/AppDelegate.swift          # NSStatusItem, NSPopover, context menu, sleep/wake
├── Models/
│   ├── CompanionTypes.swift       # Species, Rarity, Eye, Hat, StatName enums
│   ├── CompanionModel.swift       # Mulberry32 PRNG + FNV-1a, deterministic generation
│   └── CompanionStore.swift       # State management, trigger routing, menu bar quips, DND
├── Triggers/
│   ├── TriggerPlugin.swift        # TriggerSource protocol, TriggerEvent, TriggerMetric
│   ├── TriggerManager.swift       # Central hub: register sources, route events, persist state
│   └── SystemTriggerSource.swift  # Built-in system monitor trigger (CPU/mem/net/bat)
├── System/
│   └── SystemMonitor.swift        # Low-level CPU, memory, network, disk I/O, battery polling
├── Sprites/
│   ├── SpriteData.swift           # ASCII art frames for all 18 species
│   └── SpriteRenderer.swift       # renderSprite(), renderFace()
└── Views/
    ├── CompanionView.swift        # AnimationEngine, SpeechBubbleView, StatsView, MetricStripView
    ├── PopoverView.swift          # Main popover UI with toolbar
    └── SettingsView.swift         # Settings window with trigger source toggles

Resources/
├── en.lproj/Localizable.strings       # English strings
├── zh-Hans.lproj/Localizable.strings  # Simplified Chinese strings
└── Info.plist                         # Bundle config + localization declarations

Examples/triggers/                         # Sample trigger scripts
```

## How Companion Generation Works

Your companion is generated deterministically from your machine's IOPlatformUUID, salted and hashed with FNV-1a 32-bit, then fed into a Mulberry32 PRNG. The resulting sequence picks rarity, species, eye style, hat, shiny chance, and stats — same inputs always yield the same output.

Only the companion's **name** is stored in UserDefaults. Everything else is derived at runtime from your machine UUID, so editing preferences can't fake a legendary.

## Author

**kingcos** — [github.com/kingcos](https://github.com/kingcos)

## Acknowledgements

Companion design inspired by the Claude Code buddy system (`buddy/` folder).
