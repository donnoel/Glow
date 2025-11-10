import SwiftUI

struct HabitRowGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    let habit: Habit
    let toggle: () -> Void

    @State private var tappedBounce = false

    private var doneToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (habit.logs ?? []).first(where: { cal.startOfDay(for: $0.date) == today })?.completed == true
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
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.16 : 0.08)
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
        HStack(spacing: 12) {
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

            // complete button
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
                        ? habit.accentColor
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
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(glassCapsule)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(habit.title)
        .accessibilityValue(doneToday ? "Completed today" : "Not completed today")
        .accessibilityHint("Double tap for details")
    }
}
