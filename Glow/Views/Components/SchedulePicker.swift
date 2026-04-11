import SwiftUI

struct SchedulePicker: View {
    @Binding var selection: HabitSchedule

    @State private var isCustom: Bool = false
    @State private var setDays: Set<Weekday> = Set(Weekday.allCases)
    private let dayColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(
                "Frequency",
                selection: Binding(
                    get: { isCustom ? 1 : 0 },
                    set: { newValue in
                        isCustom = (newValue == 1)
                        updateSelection()
                    }
                )
            ) {
                Text("Daily").tag(0)
                Text("Custom").tag(1)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Schedule frequency")

            if isCustom {
                Text("Select the days this habit should appear.")
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)

                LazyVGrid(columns: dayColumns, spacing: 8) {
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
                        .accessibilityValue(active ? "Selected" : "Not selected")
                    }
                }

                Text(customSelectionSummaryText)
                    .font(.footnote)
                    .foregroundStyle(setDays.isEmpty ? .orange : GlowTheme.textSecondary)

                Text(customNextDueText)
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)
            } else {
                Text("This habit is due every day.")
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)
            }
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
        case .sun: return "Su"
        case .mon: return "M"
        case .tue: return "Tu"
        case .wed: return "W"
        case .thu: return "Th"
        case .fri: return "F"
        case .sat: return "Sa"
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

    private var customSelectionSummaryText: String {
        let previewSchedule = HabitSchedule.weekdays(Array(setDays))
        return SchedulePresentation.customDaysReviewText(for: previewSchedule)
    }

    private var customNextDueText: String {
        let previewSchedule = HabitSchedule.weekdays(Array(setDays))
        return SchedulePresentation.dueStatusText(for: previewSchedule)
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
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
