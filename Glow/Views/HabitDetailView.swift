import SwiftUI

struct HabitDetailView: View {
    let habit: Habit

    // Simple, schedule-agnostic weekly percent: 7 days window
    private var weeklyPercent: Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -6, to: Date())!)
        let completed = Set(
            habit.logs
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )
        // Count completed unique days in the last 7 days
        var hits = 0
        for i in 0..<7 {
            let d = cal.startOfDay(for: cal.date(byAdding: .day, value: -i, to: Date())!)
            if completed.contains(d) { hits += 1 }
        }
        return Double(hits) / 7.0
    }

    private var streaks: (current: Int, best: Int) {
        StreakEngine.computeStreaks(logs: habit.logs)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(habit.title)
                        .font(.title2).bold()
                    HStack(spacing: 12) {
                        Label("Current \(streaks.current)", systemImage: "flame.fill")
                        Label("Best \(streaks.best)", systemImage: "trophy.fill")
                    }
                    .foregroundStyle(.secondary)
                }
            }

            Section("This Week") {
                WeeklyProgressRing(percent: weeklyPercent)
                    .frame(height: 140)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowInsets(EdgeInsets())
            }

            Section("Recent Activity") {
                // Show last 14 days (✓ / —)
                RecentDaysStrip(habit: habit, days: 14)
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Details")
    }
}

private struct WeeklyProgressRing: View {
    let percent: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: percent)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: percent)
            Text("\(Int(percent * 100))%")
                .font(.headline)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly completion \(Int(percent * 100)) percent")
    }
}

private struct RecentDaysStrip: View {
    let habit: Habit
    let days: Int
    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 6) {
            ForEach((0..<days).reversed(), id: \.self) { offset in
                let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
                let done = habit.logs.contains { $0.completed && $0.date == date }
                RoundedRectangle(cornerRadius: 4)
                    .fill(done ? Color.accentColor : Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .accessibilityLabel(done
                        ? "Completed on \(date.formatted(date: .abbreviated, time: .omitted))"
                        : "Missed on \(date.formatted(date: .abbreviated, time: .omitted))"
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}
