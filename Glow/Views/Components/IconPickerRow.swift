import SwiftUI

/// A grid of tappable icons (SF Symbols) pulled from HabitIconLibrary.
/// Caller binds to `selection`, which is the chosen symbol name.
struct IconPickerRow: View {
    @Binding var selection: String   // e.g. "figure.walk", "drop.fill"
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(HabitIconLibrary.all, id: \.id) { icon in
                IconChip(
                    symbolName: icon.name,
                    label: icon.label,
                    isSelected: icon.name == selection
                ) {
                    selection = icon.name
                }
            }
        }
        .accessibilityLabel("Choose icon")
    }
}

private struct IconChip: View {
    let symbolName: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    let tint: Color = GlowTheme.accentPrimary

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? tint.opacity(0.15)
                              : GlowTheme.borderMuted.opacity(0.15)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                    ? tint
                                    : GlowTheme.borderMuted.opacity(0.4),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .frame(width: 50, height: 50)

                    HabitIconSymbol(name: symbolName, size: 21)
                        .foregroundStyle(
                            isSelected
                            ? tint
                            : GlowTheme.textPrimary
                        )
                        .accessibilityHidden(true)
                }

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityLabel("\(label) icon")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }
}
