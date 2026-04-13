import SwiftUI
import SwiftData

struct InsightsRootView: View {
    private static let cachedWeekSymbols: [String] = {
        Calendar.current.shortWeekdaySymbols.map { String($0.prefix(3)) }
    }()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var homeViewModel = HomeViewModel()
    @StateObject private var trendsViewModel = TrendsViewModel(habits: [])
    @State private var showAddHabit = false

    private var isIPadRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    private var showsLowDataHelper: Bool {
        activeHabits.isEmpty || homeViewModel.lifetimeActiveDays < 3
    }

    private var lowDataTitle: String {
        activeHabits.isEmpty ? "Insights start with your first habit" : "Insights are warming up"
    }

    private var lowDataMessage: String {
        activeHabits.isEmpty
            ? "Add a habit and check in today to start building momentum and patterns."
            : "Keep checking in for a few days to unlock clearer weekly patterns."
    }

    private var trendsFallbackLabel: String {
        activeHabits.isEmpty ? "Add your first habit" : "Keep checking in"
    }

    private var completedTodayTotal: Int {
        homeViewModel.todayCompletion.done + homeViewModel.bonusCompletedToday.count
    }

    private var strongestHabitLabel: String {
        guard let top = trendsViewModel.habitStats.first else {
            return trendsFallbackLabel
        }
        return "\(top.habit.title) • \(top.recentPercent)%"
    }

    private var weakestHabitLabel: String {
        guard let tail = trendsViewModel.habitStats.last else {
            return trendsFallbackLabel
        }
        return "\(tail.habit.title) • \(tail.recentPercent)%"
    }

    var body: some View {
        NavigationStack {
            List {
                if showsLowDataHelper {
                    Section {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                lowDataTitle,
                                systemImage: "chart.line.uptrend.xyaxis",
                                description: Text(lowDataMessage)
                            )
                            .frame(maxWidth: .infinity, minHeight: 150)

                            if activeHabits.isEmpty {
                                Button {
                                    showAddHabit = true
                                } label: {
                                    Label("Add your first habit", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } header: {
                        GlowSectionHeader("Getting Started")
                    }
                }

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
                        title: "Active days, last 7",
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddOrEditHabitForm(mode: .add)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
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
        Self.cachedWeekSymbols
    }

    private var mostConsistentLabel: String {
        let m = homeViewModel.mostConsistentHabit
        guard m.hits > 0, m.title != "—" else {
            return trendsFallbackLabel
        }
        return "\(m.title) • \(m.hits)/\(m.window) days"
    }

    private func refreshInsights() {
        let allHabits = Array(habits)
        homeViewModel.updateHabits(allHabits)
        trendsViewModel.recalc(habits: allHabits, now: Date())
    }
}
