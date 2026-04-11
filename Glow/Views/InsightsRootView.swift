import SwiftUI
import SwiftData

struct InsightsRootView: View {
    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var homeViewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Current Momentum") {
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
                        title: "Active days (last 7)",
                        value: "\(homeViewModel.recentActiveDays)",
                        icon: "calendar"
                    )
                }

                Section("Explore") {
                    NavigationLink {
                        YouView(
                            currentStreak: homeViewModel.globalStreak.current,
                            bestStreak: homeViewModel.globalStreak.best,
                            favoriteTitle: homeViewModel.mostConsistentHabit.title,
                            favoriteHits: homeViewModel.mostConsistentHabit.hits,
                            favoriteWindow: homeViewModel.mostConsistentHabit.window,
                            checkInTime: homeViewModel.typicalCheckInTime,
                            recentActiveDays: homeViewModel.recentActiveDays,
                            lifetimeActiveDays: homeViewModel.lifetimeActiveDays,
                            lifetimeCompletions: homeViewModel.lifetimeCompletions
                        )
                    } label: {
                        Label("Reflection", systemImage: "person.text.rectangle")
                    }

                    NavigationLink {
                        TrendsView()
                    } label: {
                        Label("Trends", systemImage: "chart.bar")
                    }
                }
            }
            .navigationTitle("Insights")
            .onAppear {
                homeViewModel.updateHabits(Array(habits))
            }
            .onChange(of: habits) { _, newHabits in
                homeViewModel.updateHabits(Array(newHabits))
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
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(GlowTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}
