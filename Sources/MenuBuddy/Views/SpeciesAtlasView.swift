import SwiftUI

// MARK: - Species Atlas View

/// Shows all 18 species in a grid. Highlights the user's current companion.
struct SpeciesAtlasView: View {
    let currentSpecies: Species
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Strings.atlasTitle)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(Strings.atlasClose) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Species.allCases, id: \.self) { species in
                        speciesCard(species)
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 320, height: 420)
    }

    private func speciesCard(_ species: Species) -> some View {
        let isCurrent = species == currentSpecies
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
                .fill(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrent ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }
}
