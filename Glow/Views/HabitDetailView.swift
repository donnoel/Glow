import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit
    @State private var monthAnchor: Date = .now   // NEW: which month to show

    var body: some View {
        List {
            headerSection
            weekSection
            heatmapSection          // NEW
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

    // MARK: - NEW: Monthly Heatmap

    private var heatmapSection: some View {
        Section("Monthly") {
            MonthHeatmap(
                habit: habit,
                month: monthAnchor,
                onPrev: { monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor)! },
                onNext: { monthAnchor = Calendar.current.date(byAdding: .month, value:  1, to: monthAnchor)! }
            )
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

// MARK: - NEW: MonthHeatmap

private struct MonthHeatmap: View {
    let habit: Habit
    let month: Date
    let onPrev: () -> Void
    let onNext: () -> Void

    private var cal: Calendar { Calendar.current }

    private var monthTitle: String {
        month.formatted(.dateTime.year().month(.wide))
    }

    // Build a 7x6 grid of optional Dates for the given month
    private var gridDates: [[Date?]] {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let range = cal.range(of: .day, in: .month, for: first)!
        let count = range.count

        // firstWeekday in Calendar.current is 1 = Sunday … 7 = Saturday
        let firstWeekday = cal.component(.weekday, from: first) // 1..7
        let leadingBlanks = firstWeekday - 1 // number of empty cells before day 1

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...count {
            let d = cal.date(byAdding: .day, value: day - 1, to: first)!
            cells.append(d)
        }
        // pad to 42 cells (7*6) so grid height is stable
        while cells.count % 7 != 0 { cells.append(nil) }
        while cells.count < 42 { cells.append(nil) }

        // chunk into weeks
        var weeks: [[Date?]] = []
        for i in stride(from: 0, to: cells.count, by: 7) {
            weeks.append(Array(cells[i..<min(i+7, cells.count)]))
        }
        return weeks
    }

    private var completedDays: Set<Date> {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let end = cal.date(byAdding: DateComponents(month: 1, day: 0), to: start)!
        let normalized = habit.logs
            .filter { $0.completed && $0.date >= start && $0.date < end }
            .map { cal.startOfDay(for: $0.date) }
        return Set(normalized)
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            weekdayHeader
            grid
            summary
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
    }

    // Header with month title and chevrons
    private var header: some View {
        HStack {
            Button {
                onPrev()
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            Spacer()
            Text(monthTitle).font(.headline)
            Spacer()
            Button {
                onNext()
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Month navigation")
    }

    // Sun..Sat header
    private var weekdayHeader: some View {
        HStack {
            ForEach(["S","M","T","W","Th","F","S"], id: \.self) { d in
                Text(d).font(.caption2).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let today = cal.startOfDay(for: .now)
        return VStack(spacing: 6) {
            ForEach(0..<gridDates.count, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        let date = gridDates[row][col]
                        DayCell(
                            date: date,
                            isToday: date.map { cal.startOfDay(for: $0) == today } ?? false,
                            isInMonth: date.map { cal.isDate($0, equalTo: month, toGranularity: .month) } ?? false,
                            done: date.map { completedDays.contains(cal.startOfDay(for: $0)) } ?? false
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var summary: some View {
        let total = gridDates.flatMap { $0 }.compactMap { $0 }
            .filter { cal.isDate($0, equalTo: month, toGranularity: .month) }
        let doneCount = total.filter { completedDays.contains(cal.startOfDay(for: $0)) }.count
        let pct = total.isEmpty ? 0 : Int((Double(doneCount) / Double(total.count)) * 100.0)

        return HStack {
            Label("\(pct)% this month", systemImage: "calendar")
            Spacer()
            // lightweight current streak *within this month* (visual cue)
            let inMonthLogs = habit.logs.filter {
                cal.isDate($0.date, equalTo: month, toGranularity: .month) && $0.completed
            }
            let monthStreak = StreakEngine.computeStreaks(logs: inMonthLogs).current
            Label("Streak \(monthStreak)", systemImage: "flame.fill")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Month completion \(pct) percent. Current month streak \(monthStreak(from: habit.logs)) days.")
    }

    private func monthStreak(from logs: [HabitLog]) -> Int {
        let inMonth = logs.filter {
            cal.isDate($0.date, equalTo: month, toGranularity: .month) && $0.completed
        }
        return StreakEngine.computeStreaks(logs: inMonth).current
    }
}

private struct DayCell: View {
    let date: Date?
    let isToday: Bool
    let isInMonth: Bool
    let done: Bool

    var body: some View {
        ZStack {
            if let _ = date {
                RoundedRectangle(cornerRadius: 6)
                    .fill(fillStyle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isToday ? Color.primary.opacity(0.35) : .clear, lineWidth: 1)
                    )
                    .frame(height: 24)
                    .overlay(
                        Text(dateLabel)
                            .font(.caption2)
                            .foregroundStyle(isInMonth ? Color.primary.opacity(0.8) : Color.secondary.opacity(0.5))
                    )
            } else {
                Color.clear.frame(height: 24)
            }
        }
        .contentShape(Rectangle())
        .accessibilityHidden(date == nil)
        .accessibilityLabel(accessibilityLabel)
    }

    private var fillStyle: some ShapeStyle {
        guard date != nil else { return Color.clear }
        if !isInMonth { return Color.gray.opacity(0.08) }
        return done ? Color.accentColor.opacity(0.85) : Color.gray.opacity(0.15)
    }

    private var dateLabel: String {
        guard let d = date else { return "" }
        return Calendar.current.component(.day, from: d).description
    }

    private var accessibilityLabel: String {
        guard let d = date else { return "" }
        let formatted = d.formatted(date: .abbreviated, time: .omitted)
        return done ? "Completed on \(formatted)" : "Not completed on \(formatted)"
    }
}
