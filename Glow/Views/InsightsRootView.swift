import SwiftUI
import SwiftData

struct InsightsRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var trendsViewModel = TrendsViewModel(habits: [])

    private var isIPadRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var completedTodayTotal: Int {
        homeViewModel.todayCompletion.done + homeViewModel.bonusCompletedToday.count
    }

    private var strongestHabitLabel: String {
        guard let top = trendsViewModel.habitStats.first else {
            return "No trend data yet"
        }
        return "\(top.habit.title) (\(top.recentPercent)%)"
    }

    private var weakestHabitLabel: String {
        guard let tail = trendsViewModel.habitStats.last else {
            return "No trend data yet"
        }
        return "\(tail.habit.title) (\(tail.recentPercent)%)"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    metricRow(
                        title: "Current streak",
                        value: "\(homeViewModel.globalStreak.current) days",
                        icon: "flame.fill"
                    )
                    metricRow(
                        title: "Best streak",
                        value: "\(homeViewModel.globalStreak.best) days",
                        icon: "trophy.fill"
                    )
                    metricRow(
                        title: "Today",
                        value: "\(completedTodayTotal)/\(homeViewModel.todayCompletion.total) complete",
                        icon: "checkmark.circle.fill"
                    )
                } header: {
                    GlowSectionHeader("Current Momentum")
                }

                Section {
                    weekStripRow
                    metricRow(
                        title: "Active days (last 7)",
                        value: "\(trendsViewModel.weeklyActiveDaysCount)/7",
                        icon: "calendar"
                    )
                    metricRow(
                        title: "Weekly activity",
                        value: "\(trendsViewModel.weeklyActivityPercent)%",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                } header: {
                    GlowSectionHeader("Weekly / Recent Activity")
                }

                Section {
                    metricRow(
                        title: "Most consistent",
                        value: mostConsistentLabel,
                        icon: "heart.text.square.fill"
                    )
                    metricRow(
                        title: "Strongest this week",
                        value: strongestHabitLabel,
                        icon: "arrow.up.forward.circle.fill"
                    )
                    metricRow(
                        title: "Needs attention",
                        value: weakestHabitLabel,
                        icon: "arrow.down.forward.circle.fill"
                    )
                    metricRow(
                        title: "Typical check-in",
                        value: homeViewModel.typicalCheckInTime.formatted(date: .omitted, time: .shortened),
                        icon: "clock.fill"
                    )
                } header: {
                    GlowSectionHeader("Patterns / Reflection")
                }

                Section {
                    metricRow(
                        title: "Lifetime check-ins",
                        value: "\(homeViewModel.lifetimeCompletions)",
                        icon: "checklist.checked"
                    )
                    metricRow(
                        title: "Lifetime active days",
                        value: "\(homeViewModel.lifetimeActiveDays)",
                        icon: "calendar.badge.clock"
                    )
                    metricRow(
                        title: "Recent active days",
                        value: "\(homeViewModel.recentActiveDays)/7",
                        icon: "bolt.heart.fill"
                    )
                } header: {
                    GlowSectionHeader("Milestones / Highlights")
                }
            }
            .glowCoreListRhythm()
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(isIPadRegularWidth ? .inline : .large)
            .glowIPadPageContainer(maxWidth: 860)
            .onAppear {
                refreshInsights()
            }
            .onChange(of: habits) { _, _ in
                refreshInsights()
            }
        }
    }

    @ViewBuilder
    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(GlowTheme.accentPrimary)
                .frame(width: 22)

            Text(title)
                .font(.body.weight(.medium))

            Spacer()

            Text(value)
                .monospacedDigit()
                .foregroundStyle(GlowTheme.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var weekStripRow: some View {
        HStack(spacing: 10) {
            ForEach(Array(weekSymbols.enumerated()), id: \.offset) { index, symbol in
                let weekday = index + 1
                let active = trendsViewModel.weeklyActivityMap[weekday] == true

                VStack(spacing: 6) {
                    Circle()
                        .fill(active ? GlowTheme.accentPrimary : GlowTheme.borderMuted.opacity(0.35))
                        .frame(width: 9, height: 9)

                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(GlowTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(symbol), \(active ? "active" : "inactive")")
            }
        }
        .listRowSeparator(.hidden)
    }

    private var weekSymbols: [String] {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols.map { String($0.prefix(3)) }
    }

    private var mostConsistentLabel: String {
        let m = homeViewModel.mostConsistentHabit
        guard m.hits > 0, m.title != "—" else {
            return "No clear pattern yet"
        }
        return "\(m.title) (\(m.hits)/\(m.window) days)"
    }

    private func refreshInsights() {
        let allHabits = Array(habits)
        homeViewModel.updateHabits(allHabits)
        trendsViewModel.recalc(habits: allHabits, now: Date())
    }
}
