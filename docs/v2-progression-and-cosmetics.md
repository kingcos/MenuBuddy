# v2: Progression System & Cosmetic Dress-Up System

> Design document for the two core v2 systems in MenuBuddy.
> Branch: `feature/v2-progression-and-cosmetics`

---

## Table of Contents

1. [Overview](#overview)
2. [Progression System](#progression-system)
   - [XP Sources](#xp-sources)
   - [Level Formula](#level-formula)
   - [Attribute Points](#attribute-points)
   - [Species Change](#species-change)
   - [Slot Unlocking](#slot-unlocking)
3. [Cosmetic System](#cosmetic-system)
   - [Architecture](#architecture)
   - [Slots & Items](#slots--items)
   - [Item Catalog](#item-catalog)
   - [Custom Item Creator](#custom-item-creator)
   - [Random Drops](#random-drops)
   - [Import / Export](#import--export)
   - [Sprite Rendering](#sprite-rendering)
4. [Integration Points](#integration-points)
5. [Data Persistence](#data-persistence)
6. [UI Components](#ui-components)

---

## Overview

v2 adds two interconnected systems that reward continued use of MenuBuddy:

```
┌─────────────────────┐     unlocks slots      ┌─────────────────────┐
│  Progression System │ ──────────────────────▶ │   Cosmetic System   │
│                     │                         │                     │
│  XP → Level → Pts  │     level-up rewards     │  Items → Equip →   │
│                     │ ──────────────────────▶ │  Sprite Modifiers   │
│  5 XP sources       │                         │                     │
│  Attribute bonuses  │     species change       │  5 slots, 40+ items│
│  Daily login        │ ◀─────── Lv.5+ ──────▶ │  Custom creation    │
└─────────────────────┘                         └─────────────────────┘
```

**Design principles:**
- Non-intrusive — systems enrich but never block existing functionality
- Progressive disclosure — features unlock gradually as the user levels up
- Pluggable — cosmetic items are data-driven, easy to extend
- Reversible — full reset returns everything to initial state
- **Opt-in** — master toggle in Settings, **default OFF**. Users who prefer the classic experience are unaffected

---

## Progression System

**File:** `Sources/MenuBuddy/Models/ProgressionSystem.swift`

### XP Sources

Users earn XP through 5 types of interactions:

| Source | XP | Trigger |
|--------|-----|---------|
| Petting | 5 | Each tap on the companion sprite |
| Daily Login | 20 | First app launch each day (auto-claimed) |
| Trigger Event | 3 | System monitor fires (CPU/memory/network/battery) |
| App Context | 1 | Switching to a recognized app (IDE, terminal, browser, etc.) |
| LLM Reaction | 8 | AI generates a response |
| Milestone | 15 | Reaching a pet count milestone (1, 5, 10, 25, 50, 100) |

### Level Formula

```
Level = floor(sqrt(totalXP / 10))
```

This produces a smooth, decelerating curve:

| Level | Total XP Required | Incremental XP |
|-------|-------------------|----------------|
| 0 | 0 | — |
| 1 | 10 | 10 |
| 2 | 40 | 30 |
| 3 | 90 | 50 |
| 4 | 160 | 70 |
| 5 | 250 | 90 |
| 6 | 360 | 110 |
| 7 | 490 | 130 |
| 8 | 640 | 150 |
| 9 | 810 | 170 |
| 10 | 1000 | 190 |

**Progress within a level** is calculated as:

```
progress = (currentXP - xpForCurrentLevel) / (xpForNextLevel - xpForCurrentLevel)
```

This drives the XP bar in the popover header.

### Attribute Points

Each level grants **+2 attribute points** that the user can allocate to any of the 5 stats:

- DEBUGGING
- PATIENCE
- CHAOS
- WISDOM
- SNARK

**Effective stat** = base stat (from machine-tied roll) + allocated bonus, capped at 100.

Points are allocated via `+` buttons next to each stat bar in the popover. Unallocated points are shown as a badge (`+N pts ↓`) in the XP bar area.

### Species Change

At **level 5+**, users can change their companion's species via the Species Atlas:

1. Open Species Atlas (grid icon in toolbar)
2. Tap any species to preview
3. "Change Species" button appears for non-current species
4. Confirmation dialog → species changes immediately

The change is persisted as a `speciesOverride` in UserDefaults. The original machine-tied roll is preserved and restored on reset.

### Slot Unlocking

Cosmetic slots unlock at specific levels:

| Level | Slot Unlocked |
|-------|---------------|
| 0 | Hat |
| 2 | Eye |
| 3 | Accessory |
| 5 | Aura |
| 8 | Frame |

Locked slots appear greyed out with a lock icon and "Lv.N" label in the dress-up UI.

### Anti-Cheat

| Mechanism | Value | Notes |
|-----------|-------|-------|
| **Daily XP cap** | 200 XP/day | Daily login bonus (20 XP) is exempt |
| **Pet cooldown** | 2 seconds | Prevents spam-clicking |
| **Trigger cooldown** | 10 seconds | Matches system monitor poll rate |
| **App switch cooldown** | 30 seconds | Prevents rapid alt-tab farming |
| **LLM cooldown** | 15 seconds | Prevents API spam |

- XP grants during cooldown are **silently rejected** (no XP, no event)
- XP that would exceed the daily cap is **clamped** to remaining allowance
- Daily tracking resets automatically at midnight (calendar day boundary)
- Cooldowns are in-memory only (reset on app relaunch — intentional leniency)

### Global Toggle

The entire progression + cosmetics system is behind a master switch:

- **Settings → Progression → "Enable Progression & Cosmetics"**
- **Default: OFF** — new users get the classic experience
- When OFF: no XP granted, level/XP bar hidden, cosmetics button hidden, stats show base values only, sprites render without cosmetic modifiers
- When ON: full v2 experience
- Toggle persisted in UserDefaults (`companion.progressionEnabled`)

---

## Cosmetic System

**File:** `Sources/MenuBuddy/Models/CosmeticSystem.swift`

### Architecture

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│  CosmeticCatalog │     │ CosmeticInventory│     │  SpriteRenderer  │
│  (static items)  │     │  (owned + equip) │     │  (applies mods)  │
│  40+ items       │────▶│  ownedItemIds    │────▶│                  │
│  5 rarities      │     │  equipped map    │     │  renderSprite()  │
│  5 slot types    │     │  customItems[]   │     │  renderFace()    │
└──────────────────┘     └──────────────────┘     └──────────────────┘
                                │
                                ▼
                         ┌──────────────────┐
                         │ SpriteModifier   │
                         │ (cached, rebuilt │
                         │  on equip/unequip)│
                         └──────────────────┘
```

Key design: `CosmeticItem` contains a `SpriteModifier` struct that declaratively describes how to alter the ASCII sprite. The renderer consumes a combined modifier from all equipped items.

### Slots & Items

Each item belongs to exactly one slot:

| Slot | Modifier | Visual Effect |
|------|----------|---------------|
| **Hat** | `hatLine` (12-char string) | Replaces the blank first line of the sprite |
| **Eye** | `eyeChar` (single character) | Replaces `{E}` placeholders in sprite frames |
| **Accessory** | `accessoryLeft` / `accessoryRight` | Added to left/right of middle sprite line |
| **Aura** | `auraTop` / `auraBottom` | New lines above/below the sprite |
| **Frame** | `frameLeft` / `frameRight` | Wraps every line of the sprite |

### Item Catalog

**42 items** across 5 rarities:

| Rarity | Drop Weight | Items | Color |
|--------|-------------|-------|-------|
| Common | 50% | 5 | Gray `#888` |
| Uncommon | 30% | 10 | Green `#22c55e` |
| Rare | 13% | 11 | Blue `#3b82f6` |
| Epic | 5% | 9 | Purple `#a855f7` |
| Legendary | 2% | 7 | Gold `#f59e0b` |

**Hat items (13):** None, Crown, Top Hat, Propeller, Halo, Wizard, Beanie, Tiny Duck, Pirate, Antenna, Flower, Chef, Party, Ninja

**Eye items (8):** Default, Star ✦, Heart ♥, Diamond ◆, Spiral @, Fire ⚡, Moon ☽, Cross ×, Ring ◉

**Accessory items (8):** Bow, Sword, Shield, Wand, Scarf, Flag, Balloon, Guitar

**Aura items (6):** Sparkle, Fire, Hearts, Snowfall, Music, Rainbow

**Frame items (5):** Brackets, Pipes, Star Frame, Arrow Frame, Diamond Frame

### Custom Item Creator

Users can create their own hat items:

1. Open Dress Up panel → select Hat slot → tap "Create"
2. Enter a name and a 12-character ASCII art string
3. Live preview shows the hat on the companion
4. Created items are stored in `CosmeticInventory.customItems`
5. Custom items show a paintbrush icon and can be deleted via right-click

Custom items are persisted locally and are not exportable to other users (catalog validation prevents importing arbitrary items).

### Random Drops

Items are acquired through two mechanisms:

**Pet drops (5% chance per pet):**
1. Roll a random eligible item (level ≤ user level, not already owned)
2. Weighted by rarity (`dropWeight`)
3. If no eligible items remain, no drop occurs

**Level-up rewards (guaranteed):**
1. Same weighted random from eligible pool
2. One item per level-up

### Import / Export

Items can be shared between users:

- **Export:** Serializes a `CosmeticItem` to base64-encoded JSON → copies to clipboard
- **Import:** Decodes base64, validates the item ID exists in the catalog, adds to inventory
- Security: only catalog items can be imported (prevents injection of arbitrary data)

### Sprite Rendering

The `renderSprite()` function applies modifiers in this order:

1. **Eye override:** cosmetic eye > blink "-" > default eye character
2. **Hat line:** cosmetic hat > companion's rolled hat > none
3. **Drop blank hat slot** (if species has blank line 0 in all frames)
4. **Accessories:** left/right strings added to middle line
5. **Aura:** top/bottom decoration lines added
6. **Frame:** left/right wrapping on all lines

The **menu bar face** (`renderFace()`) also respects cosmetic eyes:
- Priority: trigger eye (stress) > cosmetic eye > blink > default
- Cosmetic eyes suppress blink flicker

**Performance:** The combined `SpriteModifier` is cached and rebuilt only on equip/unequip, not every render frame.

### Behavioral Modifiers (Enriched Cosmetics)

Beyond visual changes, Epic and Legendary items carry **behavioral modifiers** that affect how the companion acts:

| Field | Type | Effect |
|-------|------|--------|
| `exclusiveQuips` | `[String]?` | Item-specific speech lines mixed into the quip rotation |
| `equipAnnouncement` | `String?` | One-time speech shown when the item is first equipped |
| `idleSequenceOverride` | `[Int]?` | Custom animation pattern replacing the default idle loop |

**Items with behavioral modifiers:**

| Item | Rarity | Quips | Announcement | Idle Override |
|------|--------|-------|--------------|---------------|
| Wizard Hat | Epic | 3 magic quips | "I feel powerful" | — |
| Tiny Duck | Legendary | 4 duck quips | "we are one" | Faster, more active |
| Pirate Hat | Epic | 3 pirate quips | "pirate mode activated" | — |
| Chef Hat | Epic | 3 cooking quips | "now we're cooking" | — |
| Ninja Band | Legendary | 4 stealth quips | "I am shadow" | Slower, stealthy |

Behavioral modifiers are wired into `AnimationEngine`:
- Exclusive quips are appended to the shuffled quip deck source
- Idle sequence overrides replace `idleSequence` for frame/blink calculations
- Equip announcements appear as speech bubbles in the CosmeticView preview

---

## Update Checker

**File:** `Sources/MenuBuddy/System/UpdateChecker.swift`

Checks GitHub Releases API for new versions:

- **Two channels:** stable (releases only) and beta (includes pre-releases)
- **Semantic version comparison:** major.minor.patch
- **Download & install:** downloads DMG to `~/Downloads`, opens it for drag-to-install
- **UI in Settings:** "Updates" section with beta toggle, check button, progress bar
- **Context menu:** "Check for Updates…" item with alert-based flow

---

## Integration Points

The two systems integrate with the existing MenuBuddy architecture at these points:

| Component | Integration |
|-----------|-------------|
| **CompanionStore** | Owns `ProgressionSystem` and `CosmeticSystem` instances; publishes `level`, `levelProgress`, `totalXP`, `availablePoints`; wires XP grants into existing actions |
| **PopoverView** | Shows level badge + XP bar in header; level-up celebration sheet; cosmetic drop notifications |
| **CompanionView (StatsView)** | Displays effective stats (base + bonus); shows `+` allocation buttons when points available |
| **CompanionView (AnimationEngine)** | `onAppContextSwitch` closure grants app context XP |
| **SpriteRenderer** | `cosmeticModifier` parameter on `renderSprite()` and eye override on `renderFace()` |
| **AppDelegate** | Context menu shows level; tooltip includes level; about dialog shows level + XP; menu bar face reflects cosmetic eyes |
| **SettingsView** | New "Progression" section with level, XP bar, slot unlock status |
| **SpeciesAtlasView** | "Change Species" button at Lv.5+ with confirmation |
| **HelpView** | Two new tips for leveling and cosmetics |
| **LLMService** | System prompt includes level and XP for richer AI personality |
| **Reset flow** | Clears progression, cosmetics, species override, and onboarding flags |

---

## Data Persistence

All data is stored in **UserDefaults**:

| Key | Type | Content |
|-----|------|---------|
| `progression.state` | JSON Data | `ProgressionState` (XP, bonuses, events, daily claim) |
| `cosmetic.inventory` | JSON Data | `CosmeticInventory` (owned IDs, equipped map, custom items) |
| `companion.speciesOverride` | String | Species raw value (nil = use machine roll) |
| `onboarding.xpSeen` | Bool | First XP onboarding message shown |
| `onboarding.cosmeticsSeen` | Bool | First cosmetics panel onboarding shown |

All keys are cleared on companion reset via `CompanionStore.resetCompanion()`.

---

## UI Components

### PopoverView Header
```
┌──────────────────────────────┐
│ Buddy Name  😊  ✨   Lv.3 ★★│
│ Duck · Uncommon        ✏️   │
│ ▓▓▓▓▓▓▓▓▓▓░░░░  +2 pts ↓  │
│ 75 XP              → Lv.4  │
└──────────────────────────────┘
```

### StatsView with Bonuses
```
DEBUGGING  ▓▓▓▓▓▓▓░░░  68 +3  [+]
PATIENCE   ▓▓▓▓░░░░░░  42
CHAOS      ▓▓▓▓▓▓▓▓░░  82 +5  [+]
WISDOM     ▓▓▓▓▓░░░░░  55
SNARK      ▓▓▓░░░░░░░  28
```

### CosmeticView (Dress Up)
```
┌─────── Dress Up ──────── ✕ ─┐
│      Preview Sprite          │
│─────────────────────────────│
│ [Hat] [Eye] [Acc] [Aura] [🔒]│
│─────────────────────────────│
│ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │Crown│ │Top  │ │Beanie│    │
│ │ ★★★ │ │ ★★  │ │  ★   │    │
│ └─────┘ └─────┘ └─────┘    │
│ ┌─────┐ ┌─────┐ ┌─────┐    │
│ │Halo │ │Wizrd│ │Pirat│    │
│ │ ★★★ │ │★★★★ │ │★★★★ │    │
│ └─────┘ └─────┘ └─────┘    │
│─────────────────────────────│
│ [+Create] [Import] [Export] │
│                  12/42 items│
└─────────────────────────────┘
```

### LevelUpSheet
```
┌─────────────────────┐
│         ⬆           │
│     Level 3!        │
│                     │
│  +2 attribute points│
│  🔓 Accessory slot  │
│                     │
│  🎁 New: Sword!     │
│                     │
│     [Awesome!]      │
└─────────────────────┘
```

### Settings — Progression Section
```
PROGRESSION
┌─────────────────────────────┐
│ Lv.5  250 XP               │
│ ▓▓▓▓▓▓▓▓░░░░░░░░           │
│─────────────────────────────│
│ Cosmetic Slots              │
│ ✓Hat ✓Eye ✓Acc ✓Aura 🔒Frame│
└─────────────────────────────┘
```
