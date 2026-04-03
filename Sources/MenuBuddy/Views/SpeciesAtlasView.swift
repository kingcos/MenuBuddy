import SwiftUI

// MARK: - Species Atlas View

/// Shows all 18 species in a grid across all 5 rarities.
/// Highlights the user's current companion. Tap a card to see it in each rarity.
struct SpeciesAtlasView: View {
    let currentSpecies: Species
    var store: CompanionStore? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSpecies: Species?
    @State private var previewRarity: Rarity = .common
    @State private var showingChangeConfirm = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Strings.atlasTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Species change hint (when progression enabled and no species selected)
            if let store, store.progressionEnabled, selectedSpecies == nil {
                HStack(spacing: 6) {
                    Image(systemName: store.level >= 5 ? "arrow.triangle.2.circlepath" : "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(store.level >= 5 ? .accentColor : .secondary)
                    Text(store.level >= 5 ? Strings.atlasChangeHint : Strings.atlasChangeLocked(5))
                        .font(.system(size: 10))
                        .foregroundColor(store.level >= 5 ? .accentColor : .secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.04))
            }

            // Rarity preview bar
            if let species = selectedSpecies {
                rarityPreview(species)
                Divider()
            }

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Species.allCases, id: \.self) { species in
                        speciesCard(species)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedSpecies = selectedSpecies == species ? nil : species
                                    previewRarity = .common
                                }
                            }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 340, height: 480)
    }

    // MARK: - Rarity Preview

    private func rarityPreview(_ species: Species) -> some View {
        VStack(spacing: 8) {
            // Sprite in selected rarity
            let hat: Hat = previewRarity == .common ? .none : .crown
            let bones = CompanionBones(
                rarity: previewRarity, species: species, eye: .dot,
                hat: hat, shiny: false, stats: [:]
            )
            let lines = renderSprite(bones: bones, frame: 0, blink: false)
            VStack(alignment: .center, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Color(hex: previewRarity.color))
                }
            }
            .frame(height: 50)

            // Rarity picker
            HStack(spacing: 4) {
                ForEach(Rarity.allCases, id: \.self) { rarity in
                    Button(action: { previewRarity = rarity }) {
                        Text(rarity.stars)
                            .font(.system(size: 9))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(previewRarity == rarity
                                          ? Color(hex: rarity.color).opacity(0.2)
                                          : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(rarity.localizedName)
                }
            }

            Text("\(species.localizedName) · \(previewRarity.localizedName)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: previewRarity.color))

            // Species change button (level 5+)
            if let store, species != currentSpecies {
                if store.level >= 5 {
                    Button(action: { showingChangeConfirm = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 10))
                            Text(Strings.atlasChangeSpecies)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .alert(Strings.atlasChangeConfirmTitle, isPresented: $showingChangeConfirm) {
                        Button(Strings.atlasChangeConfirmOK) {
                            store.changeSpecies(to: species)
                            dismiss()
                        }
                        Button(Strings.renameCancel, role: .cancel) {}
                    } message: {
                        Text(Strings.atlasChangeConfirmBody(species.localizedName))
                    }
                } else {
                    Text(Strings.atlasChangeLocked(5))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(hex: previewRarity.color).opacity(0.04))
    }

    // MARK: - Species Card

    private func speciesCard(_ species: Species) -> some View {
        let isCurrent = species == currentSpecies
        let isSelected = species == selectedSpecies
        let bones = CompanionBones(
            rarity: .common, species: species, eye: .dot,
            hat: .none, shiny: false, stats: [:]
        )
        let lines = renderSprite(bones: bones, frame: 0, blink: false)

        return VStack(spacing: 2) {
            VStack(alignment: .center, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(isCurrent ? Color(hex: Rarity.common.color) : .secondary)
                }
            }
            .frame(height: 48)

            Text(species.localizedName)
                .font(.system(size: 9, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? .primary : .secondary)
                .lineLimit(1)

            if isCurrent {
                Text(Strings.atlasYours)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundColor(.accentColor)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) :
                      isCurrent ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.6) :
                        isCurrent ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}
