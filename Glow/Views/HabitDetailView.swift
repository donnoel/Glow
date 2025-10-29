import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit

    var body: some View {
        List {
            headerSection
            weekSection
            recentSection
        }
        .navigationTitle("Details")
    }

    private var headerSection: some View {
        let s = computeStreaks(from: habit.logs)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.title)
                    .font(.title2).bold()
                HStack(spacing: 12) {
                    Label("Current \(s.current)", systemImage: "flame.fill")
                    Label("Best \(s.best)", systemImage: "trophy.fill")
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current streak \(s.current) days. Best streak \(s.best) days.")
            }
        }
    }

    private var weekSection: some View {
        Section("This Week") {
            WeeklyProgressRing(percent: weeklyPercent(from: habit.logs))
                .frame(height: 140)
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowInsets(EdgeInsets())
        }
    }

    private var recentSection: some View {
        Section("Recent Activity") {
            RecentDaysStrip(logs: habit.logs, days: 14)
                .listRowInsets(EdgeInsets())
        }
    }

    private func weeklyPercent(from logs: [HabitLog]) -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -6, to: Date())!)
        let completed = Set(
            logs.filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )
        var hits = 0
        for i in 0..<7 {
            let d = cal.startOfDay(for: cal.date(byAdding: .day, value: -i, to: Date())!)
            if completed.contains(d) { hits += 1 }
        }
        return Double(hits) / 7.0
    }

    private func computeStreaks(from logs: [HabitLog]) -> (current: Int, best: Int) {
        StreakEngine.computeStreaks(logs: logs)
    }
}

private struct WeeklyProgressRing: View {
    let percent: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0, min(1, percent)))
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
    let logs: [HabitLog]
    let days: Int
    var body: some View {
        let cal = Calendar.current
        let completed = Set(
            logs.filter { $0.completed }.map { cal.startOfDay(for: $0.date) }
        )
        HStack(spacing: 6) {
            ForEach((0..<days).reversed(), id: \.self) { offset in
                let date = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
                let done = completed.contains(date)
                RoundedRectangle(cornerRadius: 4)
                    .fill(done ? Color.accentColor : Color.gray.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .accessibilityLabel(done
                        ? "Completed on \(date.formatted(date: .abbreviated, time: .omitted))"
                        : "Missed on \(date.formatted(date: .abbreviated, time: .omitted))")
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}
