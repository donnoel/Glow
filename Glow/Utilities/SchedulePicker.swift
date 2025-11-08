import SwiftUI

struct SchedulePicker: View {
    @Binding var selection: HabitSchedule

    @State private var isCustom: Bool = false
    @State private var setDays: Set<Weekday> = Set(Weekday.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { !isCustom },
                    set: { newValue in
                        isCustom = !newValue
                        updateSelection()
                    }
                )) {
                    Text("Every day")
                        .foregroundStyle(GlowTheme.textPrimary)
                }
                .toggleStyle(.switch)

                if isCustom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which days?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GlowTheme.textPrimary)

                        HStack(spacing: 8) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                let active = setDays.contains(day)

                                DayChip(
                                    label: shortLabel(for: day),
                                    active: active
                                ) {
                                    if active {
                                        setDays.remove(day)
                                    } else {
                                        setDays.insert(day)
                                    }
                                    updateSelection()
                                }
                                .accessibilityLabel("Toggle \(fullLabel(for: day))")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GlowTheme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
            )
        }
        .onAppear {
            isCustom = (selection.kind == .custom)
            setDays = selection.days
        }
    }

    private func updateSelection() {
        if isCustom {
            selection = .weekdays(Array(setDays))
        } else {
            selection = .daily
            setDays = Set(Weekday.allCases)
        }
    }

    private func shortLabel(for day: Weekday) -> String {
        switch day {
        case .sun: return "S"
        case .mon: return "M"
        case .tue: return "T"
        case .wed: return "W"
        case .thu: return "Th"
        case .fri: return "F"
        case .sat: return "S"
        }
    }

    private func fullLabel(for day: Weekday) -> String {
        switch day {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }
}

private struct DayChip: View {
    let label: String
    let active: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    active
                    ? GlowTheme.accentPrimary
                    : GlowTheme.textPrimary
                )
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            active
                            ? GlowTheme.accentPrimary.opacity(0.15)
                            : GlowTheme.borderMuted.opacity(0.15)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    active
                                    ? GlowTheme.accentPrimary
                                    : GlowTheme.borderMuted.opacity(0.4),
                                    lineWidth: active ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
