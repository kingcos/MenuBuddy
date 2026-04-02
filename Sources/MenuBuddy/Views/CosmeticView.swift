import SwiftUI

// MARK: - Cosmetic View (Dress-Up UI)

struct CosmeticView: View {
    @ObservedObject var store: CompanionStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSlot: CosmeticSlot = .hat
    @State private var importText = ""
    @State private var showingImport = false
    @State private var showingCreator = false
    @State private var importResult: String?
    @State private var onboardingMessage: String?
    @State private var customHatName = ""
    @State private var customHatLine = ""

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
        .sheet(isPresented: $showingCreator) {
            creatorSheet
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
        let isCustom = cosmetics.isCustomItem(item.id)
        return Button(action: {
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
                // Custom items show the name directly; catalog items use L10n
                Text(isCustom ? item.name : L(item.name))
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                HStack(spacing: 2) {
                    Text(item.rarity.stars)
                        .font(.system(size: 7))
                        .foregroundColor(Color(hex: item.rarity.color))
                    if isCustom {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 6))
                            .foregroundColor(.orange)
                    }
                }
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
        .contextMenu {
            if isCustom {
                Button(role: .destructive, action: {
                    cosmetics.deleteCustomItem(id: item.id)
                    store.objectWillChange.send()
                }) {
                    Label(Strings.cosmeticsDelete, systemImage: "trash")
                }
            }
        }
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
        HStack(spacing: 10) {
            // Create custom hat
            if selectedSlot == .hat {
                Button(action: {
                    customHatName = ""
                    customHatLine = ""
                    showingCreator = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                        Text(Strings.cosmeticsCreate)
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

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

            let totalOwned = cosmetics.inventory.ownedItemIds.count + cosmetics.inventory.customItems.count
            let totalItems = cosmetics.catalog.count + cosmetics.inventory.customItems.count
            Text(Strings.cosmeticsOwned(totalOwned, totalItems))
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

    // MARK: - Creator Sheet

    private var creatorSheet: some View {
        VStack(spacing: 16) {
            Text(Strings.cosmeticsCreateTitle)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text(Strings.cosmeticsCreateNameLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField(Strings.cosmeticsCreateNamePlaceholder, text: $customHatName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 240)

                Text(Strings.cosmeticsCreateLineLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("   \\^^^/    ", text: $customHatLine)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(width: 240)
                    .onChange(of: customHatLine) { _, newValue in
                        // Limit to 12 characters
                        if newValue.count > 12 {
                            customHatLine = String(newValue.prefix(12))
                        }
                    }

                Text(Strings.cosmeticsCreateHint)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            // Live preview
            if !customHatLine.isEmpty {
                VStack(spacing: 2) {
                    Text(Strings.cosmeticsCreatePreview)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                    let padded = customHatLine.padding(toLength: 12, withPad: " ", startingAt: 0)
                    let previewMod = SpriteModifier(hatLine: padded)
                    let lines = renderSprite(
                        bones: companion.bones,
                        frame: 0,
                        blink: false,
                        cosmeticModifier: previewMod
                    )
                    VStack(alignment: .center, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: companion.rarity.color))
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Button(Strings.renameCancel) { showingCreator = false }
                    .keyboardShortcut(.cancelAction)
                Button(Strings.cosmeticsCreateConfirm) {
                    let name = customHatName.trimmingCharacters(in: .whitespaces)
                    let item = cosmetics.createCustomHat(
                        name: name.isEmpty ? "Custom Hat" : name,
                        hatLine: customHatLine
                    )
                    cosmetics.equip(item)
                    store.objectWillChange.send()
                    showingCreator = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(customHatLine.trimmingCharacters(in: .whitespaces).isEmpty)
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
