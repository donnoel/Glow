import SwiftUI
import SwiftData
import Combine

@MainActor
final class TrendsViewModel: ObservableObject {
    @Published var habitStats: [HabitPerformance] = []
    @Published var globalStreaks: (current: Int, best: Int) = (0, 0)
    @Published var weeklyActiveDaysCount: Int = 0

    init(habits: [Habit], now: Date = Date()) {
        recalc(habits: habits, now: now)
    }

    func recalc(habits: [Habit], now: Date) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        // active (non-archived)
        let activeHabits = habits.filter { !$0.isArchived }

        // habit stats (uses percentLast7Days equivalent)
        let stats: [HabitPerformance] = activeHabits.map { habit in
            let streaks = StreakEngine.computeStreaks(logs: habit.logs ?? [])

            // percent of last 7 days for this habit
            let completedDays = Set(
                (habit.logs ?? [])
                    .filter { $0.completed && $0.date >= start }
                    .map { cal.startOfDay(for: $0.date) }
            )
            let pct = Int(((Double(completedDays.count) / 7.0) * 100.0).rounded())

            return HabitPerformance(
                habit: habit,
                currentStreak: streaks.current,
                bestStreak: streaks.best,
                recentPercent: pct
            )
        }
        .sorted { a, b in
            if a.recentPercent == b.recentPercent {
                return a.currentStreak > b.currentStreak
            }
            return a.recentPercent > b.recentPercent
        }

        // global streaks (any habit per day)
        let allLogs = habits.compactMap { $0.logs }.flatMap { $0 }
        let merged = Self.mergeLogsByDay(logs: allLogs)
        let global = StreakEngine.computeStreaks(logs: merged)

        // weekly active count
        let completedDays = Set(
            habits
                .compactMap { $0.logs }
                .flatMap { $0 }
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )

        self.habitStats = stats
        self.globalStreaks = (global.current, global.best)
        self.weeklyActiveDaysCount = completedDays.count
    }

    private static func mergeLogsByDay(logs: [HabitLog]) -> [HabitLog] {
        let cal = Calendar.current
        var byDay: [Date: HabitLog] = [:]

        for log in logs where log.completed {
            let d = cal.startOfDay(for: log.date)
            if byDay[d] == nil {
                byDay[d] = log
            }
        }
        return Array(byDay.values)
    }
}

struct TrendsView: View {
    @Environment(\.modelContext) private var context

    // Pull all habits (active + archived). We'll decide what to show.
    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    @StateObject private var model = TrendsViewModel(habits: [])
    @State private var now: Date = Date()

    var body: some View {
        GlowModalScaffold(
            title: "Trends",
            subtitle: "Last 7 days, streaks, and which practices are carrying you."
        ) {
            VStack(spacing: 28) {
                streakHeroCard

                if !model.habitStats.isEmpty {
                    topHabitsSection
                }

                weeklyActivitySection
            }
        }
        .onAppear {
            model.recalc(habits: Array(habits), now: now)
        }
        .onChange(of: habits) { _, newHabits in
            model.recalc(habits: Array(newHabits), now: now)
        }
        .onChange(of: now) { _, newNow in
            model.recalc(habits: Array(habits), now: newNow)
        }
    }

    // MARK: - Sections

    private var streakHeroCard: some View {
        let current = model.globalStreaks.current
        let best = model.globalStreaks.best

        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GlowTheme.accentPrimary)

                Text("You’re on a streak ✨")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 0) {

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(current) days")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)
                    Text("Current streak")
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(best) days")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)
                    Text("Best streak")
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(model.weeklyActiveDaysCount)/7")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlowTheme.accentPrimary)
                    Text("Active this week")
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(glassCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current streak \(current) days. Best streak \(best) days. You were active \(model.weeklyActiveDaysCount) of the last 7 days."
        )
    }

    private var topHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Top Habits")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(model.habitStats.prefix(5)) { stat in
                    HabitPerformanceRow(stat: stat)
                }
            }
        }
    }

    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)

            WeeklyActivityStrip(allHabits: habits)
                .accessibilityLabel("Weekly activity over the last 7 days.")
        }
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .shadow(color: Color.black.opacity(0.15), radius: 24, y: 12)
    }
}

// MARK: - Supporting types (unchanged)

struct HabitPerformance: Identifiable {
    let habit: Habit
    let currentStreak: Int
    let bestStreak: Int
    let recentPercent: Int

    var id: AnyHashable { AnyHashable(ObjectIdentifier(habit)) }
}

private struct HabitPerformanceRow: View {
    let stat: HabitPerformance
    @Environment(\.colorScheme) private var colorScheme

    private var bubbleColor: Color {
        stat.habit.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.22)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(bubbleColor)
                    .frame(width: 32, height: 32)

                Image(systemName: stat.habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(stat.habit.accentColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.habit.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                HStack(spacing: 12) {
                    Label {
                        Text("\(stat.recentPercent)% last 7d")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "clock")
                    }

                    Label {
                        Text("Streak \(stat.currentStreak)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "flame.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(GlowTheme.textSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            stat.habit.accentColor
                                .opacity(colorScheme == .dark ? 0.24 : 0.15),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.06),
                    radius: 16, y: 8
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stat.habit.title). \(stat.recentPercent) percent in last 7 days. Streak \(stat.currentStreak).")
    }
}

private struct WeeklyActivityStrip: View {
    let allHabits: [Habit]
    @Environment(\.colorScheme) private var colorScheme

    // fixed labels so we don't depend on DateFormatter weekday order
    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    // build a map of weekday (1 = Sun ... 7 = Sat) → did anything
    private var didSomethingByWeekday: [Int: Bool] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        var map: [Int: Bool] = [:]

        for habit in allHabits {
            for log in (habit.logs ?? []) where log.completed {
                let day = cal.startOfDay(for: log.date)
                // only look at last 7 days so we don't mark an old Sunday
                guard day >= start else { continue }
                let weekday = cal.component(.weekday, from: day) // 1 = Sun
                map[weekday] = true
            }
        }

        return map
    }

    var body: some View {
        VStack(spacing: 10) {

            // row of squares Sun → Sat
            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { weekday in
                    let didAnything = didSomethingByWeekday[weekday] ?? false
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            didAnything
                            ? GlowTheme.accentPrimary
                            : GlowTheme.borderMuted.opacity(0.4)
                        )
                        .frame(width: 26, height: 26)
                        .accessibilityHidden(true)
                }
            }

            // labels under them
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { idx in
                    let weekday = idx + 1
                    let didAnything = didSomethingByWeekday[weekday] ?? false
                    Text(weekdayLabels[idx])
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            didAnything
                            ? (colorScheme == .dark ? Color.white : GlowTheme.textPrimary)
                            : (colorScheme == .dark
                               ? Color.white.opacity(0.6)
                               : GlowTheme.textSecondary)
                        )
                        .frame(width: 26)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly activity, Sunday through Saturday.")
    }
}
