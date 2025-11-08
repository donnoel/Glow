import SwiftUI
import SwiftData

struct TrendsView: View {
    @Environment(\.modelContext) private var context

    // Pull all habits (active + archived). We'll decide what to show.
    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    // We'll talk about "last 7 days", "this month", etc. Use `Date()` as anchor.
    @State private var now: Date = Date()

    // MARK: - Derived Data

    // Only consider non-archived habits for most stats.
    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    /// For each habit, compute:
    /// - streak info
    /// - recent completion %
    ///
    /// We'll sort by "recent %", highest first.
    private var habitStats: [HabitPerformance] {
        activeHabits.map { habit in
            let streaks = StreakEngine.computeStreaks(logs: habit.logs)
            return HabitPerformance(
                habit: habit,
                currentStreak: streaks.current,
                bestStreak: streaks.best,
                recentPercent: percentLast7Days(for: habit)
            )
        }
        .sorted { a, b in
            if a.recentPercent == b.recentPercent {
                return a.currentStreak > b.currentStreak
            }
            return a.recentPercent > b.recentPercent
        }
    }

    /// Global streak = streak across "any habit done each day".
    /// We'll define "you showed up that day" if you completed at least one habit that day.
    private var globalStreaks: (current: Int, best: Int) {
        let allLogs = habits.flatMap { $0.logs }
        return StreakEngine.computeStreaks(
            logs: mergeLogsByDay(logs: allLogs)
        )
    }

    /// How many of the last 7 days did the user complete *anything*?
    private var weeklyActiveDaysCount: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        let completedDays = Set(
            habits
                .flatMap { $0.logs }
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )

        return completedDays.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {

                    // 1. HERO STREAK CARD
                    streakHeroCard

                    // 2. TOP HABITS / LEADERBOARD
                    if !habitStats.isEmpty {
                        topHabitsSection
                    }

                    // 3. WEEKLY ACTIVITY STRIP
                    weeklyActivitySection
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Trends")
            .navigationBarTitleDisplayMode(.inline)
            .background(GlowBackground())
        }
    }

    // MARK: - Sections

    // big proud card at the top
    private var streakHeroCard: some View {
        let current = globalStreaks.current
        let best = globalStreaks.best

        return VStack(alignment: .leading, spacing: 16) {

            // streak headline row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(GlowTheme.accentPrimary)

                Text("You’re on a streak ✨")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                Spacer(minLength: 0)
            }

            // 3-column stats row
            HStack(alignment: .top, spacing: 0) {

                // Current streak column
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(current) days")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)
                    Text("Current streak")
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Best streak column
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(best) days")
                        .font(.title2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)
                    Text("Best streak")
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Active this week column
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(weeklyActiveDaysCount)/7")
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
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.25),
                            lineWidth: 1
                        )
                        .blendMode(.plusLighter)
                )
                .shadow(
                    color: Color.black.opacity(0.15),
                    radius: 24,
                    y: 12
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Current streak \(current) days. Best streak \(best) days. You were active \(weeklyActiveDaysCount) of the last 7 days."
        )
    }

    // leaderboard style list of habits you're doing best
    private var topHabitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Top Habits")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)
                .padding(.top, 4)

            VStack(spacing: 10) {
                ForEach(habitStats.prefix(5)) { stat in
                    HabitPerformanceRow(stat: stat)
                }
            }
        }
    }

    // last 7 days, "did you show up?"
    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)

            WeeklyActivityStrip(allHabits: habits)
                .accessibilityLabel("Weekly activity over the last 7 days.")
        }
    }

    // MARK: - Helpers

    /// Collapse multiple habits' logs down to "did ANYTHING this day?"
    /// We create pseudo-logs where each unique day you did something becomes one "completed" log.
    private func mergeLogsByDay(logs: [HabitLog]) -> [HabitLog] {
        let cal = Calendar.current
        var byDay: [Date: HabitLog] = [:]

        for log in logs where log.completed {
            let d = cal.startOfDay(for: log.date)
            // Keep the first completed log we see for that day.
            if byDay[d] == nil {
                byDay[d] = log
            }
        }

        // Return them as an array so StreakEngine can reason over unique days.
        return Array(byDay.values)
    }

    /// % of last 7 days this habit was completed.
    private func percentLast7Days(for habit: Habit) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        let completedDays = Set(
            habit.logs
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )

        let count = completedDays.count
        let pct = (Double(count) / 7.0) * 100.0
        return Int(pct.rounded())
    }
}

// MARK: - HabitPerformance model

private struct HabitPerformance: Identifiable {
    let habit: Habit
    let currentStreak: Int
    let bestStreak: Int
    let recentPercent: Int // e.g. 86 (% of last 7 days)

    // Use the object identity of the Habit instance as a stable Hashable ID.
    var id: AnyHashable { AnyHashable(ObjectIdentifier(habit)) }
}

// MARK: - HabitPerformanceRow
// one row in "Your Top Habits"

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

// MARK: - WeeklyActivityStrip
// like RecentDaysStrip but global: “did you do ANY habit this day?”

private struct WeeklyActivityStrip: View {
    let allHabits: [Habit]
    @Environment(\.colorScheme) private var colorScheme

    private var daysData: [(date: Date, didAnything: Bool)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today

        var map: [Date: Bool] = [:]

        for habit in allHabits {
            for log in habit.logs where log.completed {
                let d = cal.startOfDay(for: log.date)
                if d >= start {
                    map[d] = true
                }
            }
        }

        // oldest → newest
        return (0..<7).reversed().map { offset in
            let base = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let d = cal.startOfDay(for: base)
            return (date: d, didAnything: map[d] ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 8) {

            // Row of squares
            HStack(spacing: 6) {
                ForEach(0..<daysData.count, id: \.self) { idx in
                    let info = daysData[idx]
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(
                            info.didAnything
                            ? GlowTheme.accentPrimary
                            : GlowTheme.borderMuted.opacity(0.4)
                        )
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                }
            }

            // Row of weekday labels
            HStack(spacing: 6) {
                ForEach(0..<daysData.count, id: \.self) { idx in
                    let info = daysData[idx]
                    Text(shortWeekday(for: info.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            info.didAnything
                            ? (colorScheme == .dark ? Color.white : GlowTheme.textPrimary)
                            : (colorScheme == .dark
                               ? Color.white.opacity(0.6)
                               : GlowTheme.textSecondary)
                        )
                        .frame(width: 20)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly activity. Most recent day is on the right.")
    }

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()

    private func shortWeekday(for date: Date) -> String {
        WeeklyActivityStrip.weekdayFormatter.string(from: date)
    }
}

// MARK: - GlowBackground helper
// soft background to match HomeView vibe without List
private struct GlowBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
