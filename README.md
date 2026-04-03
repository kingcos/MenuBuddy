# MenuBuddy

[中文说明](README.zh-CN.md)

A tiny companion pet that lives in your macOS menu bar. Click the icon to open the popover and see your buddy — an animated ASCII creature unique to your machine.

## Features

### Companion

- **18 species** in a browsable atlas: duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk
- **5 rarity tiers**: Common (60%) → Uncommon (25%) → Rare (10%) → Epic (4%) → Legendary (1%) — each with distinct colors and hats
- **1% shiny** variant with golden glow
- **Deterministic generation**: derived from your machine UUID — same machine, same buddy, always
- **Idle animations**: 3-frame fidget loop with blink, at 500ms tick rate
- **Speech bubbles**: species-specific and generic quips every 15–45s, fade out gracefully
- **Pet interaction**: tap the sprite for a heart burst; milestones at 1, 5, 10, 25, 50, 100 pets
- **Stats**: DEBUGGING / PATIENCE / CHAOS / WISDOM / SNARK — personality traits that influence AI reactions
- **Species Atlas**: grid view of all 18 species with rarity preview (tap to see any species in each rarity tier)
- **Rarity colors**: sprites render in their rarity color (gray/green/blue/purple/gold)

### Progression System (v2)

Earn XP through interactions and level up your companion:

- **5 XP sources**: petting (5 XP), daily login (20 XP), system events (3 XP), app switching (1 XP), AI reactions (8 XP)
- **Level formula**: `Level = floor(sqrt(XP / 10))` — smooth curve from Lv.1 (10 XP) to Lv.10 (1000 XP)
- **Attribute points**: +2 per level, allocate to any stat (DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK)
- **Species change**: at Lv.5+, switch species freely via the Species Atlas
- **Level-up celebrations**: notification sheet with new slot unlocks and cosmetic rewards

### Cosmetic Dress-Up System (v2)

Customize your companion's appearance with a pluggable item system:

- **5 cosmetic slots**: Hat, Eye, Accessory, Aura, Frame — unlock progressively (Lv.0 → Lv.8)
- **40+ items** across 5 rarities (Common → Legendary), each with ASCII sprite modifiers
- **Random drops**: 5% chance per pet + guaranteed reward on level-up
- **Custom hat creator**: design your own 12-character ASCII hat with live preview
- **Import / Export**: share items between users via base64 share codes
- **Dress-up UI**: slot tabs, item grid, equip/unequip, live sprite preview

> See [docs/v2-progression-and-cosmetics.md](docs/v2-progression-and-cosmetics.md) for the full design document.

### AI Reactions (LLM-Powered)

When configured with an LLM API, your companion generates contextual reactions based on its personality stats:

- **SNARK ≥50** → snarky and sarcastic responses
- **CHAOS ≥50** → unpredictable and random
- **WISDOM ≥50** → thoughtful and philosophical
- **PATIENCE <25** → impatient and restless
- **DEBUGGING ≥50** → tech-savvy, coding references

Configure in Settings → AI Reactions:
- Supports any OpenAI-compatible API (DeepSeek by default, also OpenAI, Ollama, etc.)
- Token usage tracking with reset
- Test button to verify connection
- Falls back to preset quips when LLM is disabled

### Pluggable Trigger System

Any data source can drive companion reactions through a standardized plugin architecture:

```
┌───────────────┐  ┌──────────────┐  ┌───────────────┐
│ System Monitor│  │ Stock Prices │  │ Your Script   │
│ (built-in)    │  │ (script)     │  │               │
└──────┬────────┘  └──────┬───────┘  └───────┬───────┘
       │ TriggerEvent     │                   │
       ▼                  ▼                   ▼
  ┌──────────────────────────────────────────────────┐
  │              TriggerManager                      │
  │  routes events → mood, quips, indicator, eyes    │
  │  optionally → LLM for contextual AI reactions    │
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

Drop any executable script into `~/.menubuddy/triggers/`. The app runs it periodically and reads JSON from stdout. Use "Rescan Scripts" in Settings to pick up new scripts without restart.

```bash
#!/bin/bash
# ~/.menubuddy/triggers/stock.sh
echo '{"interval":60,"trigger":{"indicator":"📈","quips":["涨了!"],"mood":"🤑"},"metrics":[{"label":"AAPL","value":"$254","trend":"↑"}]}'
```

See `Examples/triggers/` for complete samples (stock price, network speed, CPU/memory).

Use `Examples/TRIGGER_PROMPT.md` to have any AI assistant generate custom trigger scripts for you.

**JSON format:**

| Field | Required | Description |
|-------|----------|-------------|
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

### Menu Bar

- **Animated face**: companion face animates with blink and idle frames, colored by rarity
- **Trigger indicator emoji**: shows next to face when an event fires
- **Menu bar quips**: buddy says something next to its face periodically (configurable)
- **Do Not Disturb**: quiet hours in Settings (supports overnight wrap, e.g. 22:00→08:00)
- **Startup greeting**: random greeting each launch

### UI & Interaction

- **Left-click**: open/close popover
- **Right-click**: context menu (pet, rename, mute, launch at login, settings, quit)
- **Popover toolbar**: settings, species atlas, quit
- **Settings**: General, Language, Menu Bar, Trigger Sources, AI Reactions, Logs, Reset
- **Species Atlas**: browse all 18 species with rarity preview
- **Logging**: optional file logging to `~/.menubuddy/logs/` (7-day rotation)
- **LSUIElement**: no Dock icon, menu bar only

### Internationalization

- **English** and **Simplified Chinese** (zh-Hans) fully supported
- 300+ localized string keys
- In-app language switcher (System / EN / 中文)

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
│   └── CompanionStore.swift       # State management, trigger routing, LLM integration
├── Triggers/
│   ├── TriggerPlugin.swift        # TriggerSource protocol, TriggerEvent, TriggerMetric
│   ├── TriggerManager.swift       # Central hub: register sources, route events
│   ├── SystemTriggerSource.swift  # Built-in system monitor trigger
│   └── ScriptTriggerSource.swift  # Script-based triggers from ~/.menubuddy/triggers/
├── System/
│   ├── SystemMonitor.swift        # CPU, memory, network, disk I/O, battery polling
│   ├── LLMService.swift           # OpenAI-compatible API client for AI reactions
│   └── Logger.swift               # File-based logging with daily rotation
├── Sprites/
│   ├── SpriteData.swift           # ASCII art frames for all 18 species
│   └── SpriteRenderer.swift       # renderSprite(), renderFace()
└── Views/
    ├── CompanionView.swift        # AnimationEngine, SpeechBubble, Stats, MetricStrip
    ├── PopoverView.swift          # Main popover UI with toolbar
    ├── SettingsView.swift         # Settings window
    └── SpeciesAtlasView.swift     # Species grid with rarity preview

Resources/
├── en.lproj/Localizable.strings
├── zh-Hans.lproj/Localizable.strings
└── Info.plist

Examples/
├── triggers/                      # Sample trigger scripts
│   ├── stock-aapl.sh              # AAPL stock via East Money API
│   ├── network-speed.sh           # Network speed monitor
│   ├── cpu-memory.sh              # CPU & memory monitor
│   └── random-mood.sh             # Minimal example
└── TRIGGER_PROMPT.md              # AI prompt for generating custom triggers
```

## How Companion Generation Works

Your companion is generated deterministically from your machine's IOPlatformUUID, salted and hashed with FNV-1a 32-bit, then fed into a Mulberry32 PRNG. The resulting sequence picks rarity, species, eye style, hat, shiny chance, and stats — same inputs always yield the same output.

Only the companion's **name** is stored in UserDefaults. Everything else is derived at runtime from your machine UUID.

## Author

**kingcos** — [github.com/kingcos/MenuBuddy](https://github.com/kingcos/MenuBuddy)

## Acknowledgements

Companion design inspired by the Claude Code buddy system.
