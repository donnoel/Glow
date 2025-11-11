import SwiftUI
import SwiftData
import Combine

@MainActor
final class RemindersViewModel: ObservableObject {
    @Published var reminderHabits: [Habit] = []

    func update(from habits: [Habit]) {
        let filtered = habits
            .filter { !$0.isArchived }
            .filter { $0.reminderEnabled && $0.hasValidReminder }
            .sorted { lhs, rhs in
                let l = lhs.reminderTimeComponents ?? DateComponents(hour: 23, minute: 59)
                let r = rhs.reminderTimeComponents ?? DateComponents(hour: 23, minute: 59)
                if (l.hour ?? 0) == (r.hour ?? 0) {
                    return (l.minute ?? 0) < (r.minute ?? 0)
                }
                return (l.hour ?? 0) < (r.hour ?? 0)
            }

        self.reminderHabits = filtered
    }
}

struct RemindersView: View {
    // grab all habits, we’ll filter in-memory because we only need the reminder ones
    @Query(sort: [
        SortDescriptor(\Habit.reminderHour, order: .forward),
        SortDescriptor(\Habit.reminderMinute, order: .forward),
        SortDescriptor(\Habit.title, order: .forward)
    ])
    private var habits: [Habit]

    @StateObject private var model = RemindersViewModel()

    var body: some View {
        GlowModalScaffold(
            title: "Reminders",
            subtitle: "Practices with “Remind me” turned on."
        ) {
            if model.reminderHabits.isEmpty {
                VStack(spacing: 16) {
                    ContentUnavailableView(
                        "No reminders set",
                        systemImage: "bell.slash",
                        description: Text("Turn on “Remind me” for a practice and it will show up here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(model.reminderHabits) { habit in
                        ReminderRow(habit: habit)
                    }
                }
            }
        }
        .onAppear {
            model.update(from: habits)
        }
        .onChange(of: habits) { _, newHabits in
            model.update(from: newHabits)
        }
    }
}

// MARK: - Row

private struct ReminderRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let habit: Habit

    private var timeString: String {
        guard let comps = habit.reminderTimeComponents,
              let h = comps.hour,
              let m = comps.minute
        else {
            return "—"
        }
        var dc = DateComponents()
        dc.hour = h
        dc.minute = m
        let cal = Calendar.current
        let date = cal.date(from: dc) ?? Date()
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    private var scheduleString: String {
        habit.schedule.displayLabel
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(habit.accentColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .frame(width: 34, height: 34)
                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                Text(scheduleString)
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)
            }

            Spacer()

            Text(timeString)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .opacity(colorScheme == .dark ? 0.72 : 0.82)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Schedule display helper

private extension HabitSchedule {
    var displayLabel: String {
        switch kind {
        case .daily:
            return "Every day"
        case .custom:
            if days.isEmpty {
                return "Custom"
            }
            let ordered = Weekday.allCases.filter { days.contains($0) }
            let names = ordered.map { $0.shortName }
            return names.joined(separator: ", ")
        }
    }
}

private extension Weekday {
    var shortName: String {
        switch self {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }
}
