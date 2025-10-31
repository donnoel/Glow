import SwiftUI

/// A horizontal row of tappable icons (SF Symbols) pulled from HabitIconLibrary.
/// Caller binds to `selection`, which is the chosen symbol name.
struct IconPickerRow: View {
    @Binding var selection: String   // e.g. "figure.walk", "drop.fill"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
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
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose icon")
    }
}

private struct IconChip: View {
    let symbolName: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? GlowTheme.accentPrimary.opacity(0.15)
                              : GlowTheme.borderMuted.opacity(0.15)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected
                                    ? GlowTheme.accentPrimary
                                    : GlowTheme.borderMuted.opacity(0.4),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(
                            isSelected
                            ? GlowTheme.accentPrimary
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
            .frame(minWidth: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) icon")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }
}
