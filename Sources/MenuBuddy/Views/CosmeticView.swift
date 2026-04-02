import SwiftUI

// MARK: - Cosmetic View (Dress-Up UI)

struct CosmeticView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: CosmeticSlot = .hat
    @State private var importText = ""
    @State private var showingImport = false
    @State private var importResult: String?
    @State private var onboardingMessage: String?

    private var cosmetics: CosmeticSystem { store.cosmetics }
    private var progression: ProgressionSystem { store.progression }
    private var companion: Companion { store.companion }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(Strings.cosmeticsTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Preview
            previewSection
                .padding(.bottom, 8)

            // Onboarding banner
            if let msg = onboardingMessage {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text(msg)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.06))
            }

            Divider()

            // Slot tabs
            slotTabBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            // Item grid
            itemGrid
                .padding(.horizontal, 12)

            Divider()

            // Bottom bar: import/export
            bottomBar
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .frame(width: 320, height: 460)
        .onAppear {
            onboardingMessage = store.consumeCosmeticsOnboarding()
        }
        .sheet(isPresented: $showingImport) {
            importSheet
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 4) {
            let lines = renderSprite(
                bones: companion.bones,
                frame: 0,
                blink: false,
                cosmeticModifier: cosmetics.allEquippedModifiers()
            )
            VStack(alignment: .center, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(companion.shiny ? Color(hex: "#f59e0b") : Color(hex: companion.rarity.color))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Slot Tabs

    private var slotTabBar: some View {
        HStack(spacing: 4) {
            ForEach(CosmeticSlot.allCases, id: \.self) { slot in
                let isUnlocked = progression.isSlotUnlocked(slot)
                let isSelected = selectedSlot == slot
                Button(action: {
                    if isUnlocked { selectedSlot = slot }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: slotIcon(slot))
                            .font(.system(size: 12))
                        Text(Strings.slotName(slot))
                            .font(.system(size: 8, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                    )
                    .foregroundColor(isUnlocked ? (isSelected ? .accentColor : .primary) : .secondary.opacity(0.4))
                    .overlay(
                        Group {
                            if !isUnlocked {
                                VStack {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Text("Lv.\(progression.unlockLevel(for: slot))")
                                        .font(.system(size: 7, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
                .disabled(!isUnlocked)
            }
        }
    }

    // MARK: - Item Grid

    private var itemGrid: some View {
        let items = cosmetics.ownedItems(for: selectedSlot)
        let equipped = cosmetics.equippedItem(for: selectedSlot)

        return ScrollView {
            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "shippingbox")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text(Strings.cosmeticsEmpty)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ], spacing: 8) {
                    ForEach(items) { item in
                        let isEquipped = equipped?.id == item.id
                        itemCard(item, isEquipped: isEquipped)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(height: 160)
    }

    private func itemCard(_ item: CosmeticItem, isEquipped: Bool) -> some View {
        Button(action: {
            if isEquipped {
                cosmetics.unequip(item.slot)
            } else {
                cosmetics.equip(item)
            }
            store.objectWillChange.send()
        }) {
            VStack(spacing: 3) {
                // Item icon/preview
                itemPreview(item)
                    .frame(height: 24)
                Text(L(item.name))
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(item.rarity.stars)
                    .font(.system(size: 7))
                    .foregroundColor(Color(hex: item.rarity.color))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isEquipped ? Color.accentColor.opacity(0.12) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isEquipped ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isEquipped ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func itemPreview(_ item: CosmeticItem) -> some View {
        Group {
            let m = item.spriteModifier
            if let hatLine = m.hatLine {
                Text(hatLine.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 10, design: .monospaced))
            } else if let eyeChar = m.eyeChar {
                Text(eyeChar)
                    .font(.system(size: 14))
            } else if let left = m.accessoryLeft {
                Text(left.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 14))
            } else if let right = m.accessoryRight {
                Text(right.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 14))
            } else if let auraTop = m.auraTop {
                Text(auraTop.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 10, design: .monospaced))
            } else if let fl = m.frameLeft, let fr = m.frameRight {
                Text(fl.trimmingCharacters(in: .whitespaces) + " · " + fr.trimmingCharacters(in: .whitespaces))
                    .font(.system(size: 10, design: .monospaced))
            } else {
                Text("—")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(action: { showingImport = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11))
                    Text(Strings.cosmeticsImport)
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)

            if let equipped = cosmetics.equippedItem(for: selectedSlot) {
                Button(action: {
                    if let code = cosmetics.exportItem(equipped) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11))
                        Text(Strings.cosmeticsExport)
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            Spacer()

            Text(Strings.cosmeticsOwned(cosmetics.inventory.ownedItemIds.count, cosmetics.catalog.count))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Import Sheet

    private var importSheet: some View {
        VStack(spacing: 16) {
            Text(Strings.cosmeticsImportTitle)
                .font(.headline)
            TextField(Strings.cosmeticsImportPlaceholder, text: $importText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
            if let result = importResult {
                Text(result)
                    .font(.system(size: 11))
                    .foregroundColor(result.contains("✓") ? .green : .red)
            }
            HStack(spacing: 12) {
                Button(Strings.renameCancel) { showingImport = false }
                    .keyboardShortcut(.cancelAction)
                Button(Strings.cosmeticsImportConfirm) {
                    // Try to import from paste
                    let text = importText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let item = cosmetics.importItem(from: text) {
                        importResult = "✓ \(L(item.name))"
                        store.objectWillChange.send()
                    } else {
                        importResult = Strings.cosmeticsImportFail
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 300)
    }

    // MARK: - Helpers

    private func slotIcon(_ slot: CosmeticSlot) -> String {
        switch slot {
        case .hat: return "party.popper"
        case .eye: return "eye"
        case .accessory: return "wand.and.stars"
        case .aura: return "sparkles"
        case .frame: return "rectangle.dashed"
        }
    }
}

// MARK: - Level Up Sheet

struct LevelUpSheet: View {
    let info: LevelUpInfo
    let cosmeticDrop: CosmeticItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("⬆")
                .font(.system(size: 40))

            Text(Strings.levelUpTitle(info.newLevel))
                .font(.system(size: 18, weight: .bold, design: .rounded))

            VStack(spacing: 6) {
                Text(Strings.levelUpPoints(info.attributePointsGained))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                if !info.newSlots.isEmpty {
                    ForEach(info.newSlots, id: \.self) { slot in
                        HStack(spacing: 4) {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.green)
                            Text(Strings.slotUnlocked(Strings.slotName(slot)))
                                .font(.system(size: 12))
                        }
                    }
                }

                if let drop = cosmeticDrop {
                    Divider()
                    HStack(spacing: 6) {
                        Text("🎁")
                            .font(.system(size: 14))
                        Text(Strings.cosmeticReward(L(drop.name)))
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: drop.rarity.color))
                    }
                }
            }

            Button(Strings.levelUpOK) { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 260)
    }
}
