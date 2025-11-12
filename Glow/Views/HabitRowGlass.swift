import SwiftUI

struct HabitRowGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    let habit: Habit
    let isArchived: Bool
    let toggle: () -> Void

    @State private var tappedBounce = false

    private var doneToday: Bool {
        guard let logs = habit.logs, !logs.isEmpty else { return false }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return logs.contains {
            $0.completed && cal.isDate($0.date, inSameDayAs: today)
        }
    }

    private var rowTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }

    private var iconBubbleColor: Color {
        habit.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.22)
    }

    private var incompleteRingColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.45)
        : GlowTheme.borderMuted.opacity(0.8)
    }

    private var glassCapsule: some View {
        RoundedRectangle(cornerRadius: GlowTheme.Radius.medium, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: GlowTheme.Radius.medium, style: .continuous)
                    .fill(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.16 : 0.08)
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlowTheme.Radius.medium, style: .continuous)
                    .stroke(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.28 : 0.18),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                radius: 20, y: 10
            )
    }

    var body: some View {
        HStack(spacing: GlowTheme.Spacing.small) {
            // icon
            ZStack {
                Circle()
                    .fill(iconBubbleColor)
                    .frame(width: 32, height: 32)

                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.accentColor)
            }

            // title
            Text(habit.title)
                .foregroundStyle(rowTextColor)

            Spacer(minLength: 8)

            // complete button (hidden for archived habits)
            if !isArchived {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        tappedBounce = true
                    }
                    GlowTheme.tapHaptic()
                    toggle()
                } label: {
                    Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                        .imageScale(.large)
                        .foregroundStyle(
                            doneToday
                            ? Color.green
                            : incompleteRingColor
                        )
                        .scaleEffect(tappedBounce ? 1.08 : 1.0)
                        .accessibilityLabel(
                            doneToday
                            ? "Mark practice incomplete"
                            : "Mark practice complete"
                        )
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .onChange(of: doneToday) { _, _ in
                    withAnimation(
                        .spring(response: 0.3, dampingFraction: 0.8)
                            .delay(0.05)
                    ) {
                        tappedBounce = false
                    }
                }
            }
        }
        .padding(.vertical, GlowTheme.Spacing.small)
        .padding(.horizontal, GlowTheme.Spacing.small)
        .background(glassCapsule)
        .contentShape(RoundedRectangle(cornerRadius: GlowTheme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue(doneToday ? "Completed today" : "Not completed today")
        .accessibilityHint("Double tap for details")
    }
}
