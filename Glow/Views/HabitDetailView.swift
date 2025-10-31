import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit
    @State private var monthAnchor: Date = .now

    var body: some View {
        List {
            headerSection
            weekSection
            heatmapSection
            recentSection
        }
        .navigationTitle("Details")
    }

    // MARK: - Header / Streaks
    private var headerSection: some View {
        let s = computeStreaks(from: habit.logs)
        return Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(habit.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                HStack(spacing: 12) {
                    Label {
                        Text("Current \(s.current)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "flame.fill")
                    }

                    Label {
                        Text("Best \(s.best)")
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "trophy.fill")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(GlowTheme.textSecondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Current streak \(s.current) days. Best streak \(s.best) days.")
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Weekly Ring
    private var weekSection: some View {
        Section("This Week") {
            WeeklyProgressRing(percent: weeklyPercent(from: habit.logs))
                .frame(height: 140)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(GlowTheme.bgSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
                )
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Monthly Heatmap
    private var heatmapSection: some View {
        Section("Monthly") {
            MonthHeatmap(
                habit: habit,
                month: monthAnchor,
                onPrev: {
                    monthAnchor = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor)!
                },
                onNext: {
                    monthAnchor = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor)!
                }
            )
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Recent Activity strip
    private var recentSection: some View {
        Section("Recent Activity") {
            RecentDaysStrip(logs: habit.logs, days: 14)
                .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Helpers
    private func weeklyPercent(from logs: [HabitLog]) -> Double {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: -6, to: Date())!)
        let completed = Set(
            logs
                .filter { $0.completed && $0.date >= start }
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

// MARK: - WeeklyProgressRing
private struct WeeklyProgressRing: View {
    let percent: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0, min(1, percent)))
                .stroke(
                    GlowTheme.accentPrimary,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: percent)

            Text("\(Int(percent * 100))%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(GlowTheme.textPrimary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly completion \(Int(percent * 100)) percent")
    }
}

// MARK: - RecentDaysStrip
private struct RecentDaysStrip: View {
    let logs: [HabitLog]
    let days: Int

    var body: some View {
        let cal = Calendar.current
        let completed = Set(
            logs
                .filter { $0.completed }
                .map { cal.startOfDay(for: $0.date) }
        )

        HStack(spacing: 6) {
            ForEach((0..<days).reversed(), id: \.self) { offset in
                let cellDate = cal.startOfDay(for: cal.date(byAdding: .day, value: -offset, to: Date())!)
                let done = completed.contains(cellDate)

                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        done
                        ? GlowTheme.accentPrimary
                        : GlowTheme.borderMuted.opacity(0.6)
                    )
                    .frame(width: 16, height: 16)
                    .accessibilityLabel(
                        done
                        ? "Completed on \(cellDate.formatted(date: .abbreviated, time: .omitted))"
                        : "Missed on \(cellDate.formatted(date: .abbreviated, time: .omitted))"
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}

// MARK: - MonthHeatmap
private struct MonthHeatmap: View {
    let habit: Habit
    let month: Date
    let onPrev: () -> Void
    let onNext: () -> Void

    private var cal: Calendar { Calendar.current }

    private var monthTitle: String {
        month.formatted(.dateTime.year().month(.wide))
    }

    // stable 7x6 grid
    private var gridDates: [[Date?]] {
        let first = cal.date(from: cal.dateComponents([.year, .month], from: month))!
        let range = cal.range(of: .day, in: .month, for: first)!
        let count = range.count

        let firstWeekday = cal.component(.weekday, from: first) // Sun = 1
        let leadingBlanks = firstWeekday - 1

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for day in 1...count {
            let d = cal.date(byAdding: .day, value: day - 1, to: first)!
            cells.append(d)
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        while cells.count < 42 { cells.append(nil) }

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
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GlowTheme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    // header row (month + chevrons)
    private var header: some View {
        HStack {
            Button(action: onPrev) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .foregroundStyle(GlowTheme.textPrimary)

            Spacer()

            Button(action: onNext) {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel("Month navigation")
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(["S","M","T","W","Th","F","S"], id: \.self) { d in
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(GlowTheme.textSecondary)
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
                        let cellDate = gridDates[row][col]
                        DayCell(
                            date: cellDate,
                            isToday: cellDate.map { cal.startOfDay(for: $0) == today } ?? false,
                            isInMonth: cellDate.map { cal.isDate($0, equalTo: month, toGranularity: .month) } ?? false,
                            done: cellDate.map { completedDays.contains(cal.startOfDay(for: $0)) } ?? false
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var summary: some View {
        let totalDaysInMonth = gridDates
            .flatMap { $0 }
            .compactMap { $0 }
            .filter { cal.isDate($0, equalTo: month, toGranularity: .month) }

        let doneCount = totalDaysInMonth.filter {
            completedDays.contains(cal.startOfDay(for: $0))
        }.count

        let pct = totalDaysInMonth.isEmpty
            ? 0
            : Int((Double(doneCount) / Double(totalDaysInMonth.count)) * 100.0)

        let inMonthLogs = habit.logs.filter {
            cal.isDate($0.date, equalTo: month, toGranularity: .month) && $0.completed
        }
        let monthStreak = StreakEngine.computeStreaks(logs: inMonthLogs).current

        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("\(pct)% this month")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("Streak \(monthStreak)")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.footnote)
        .foregroundStyle(GlowTheme.textSecondary)
        .padding(.top, 6)
        .padding(.horizontal, 4)   // safe inside the rounded rect
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Month completion \(pct) percent. Current month streak \(monthStreak) days."
        )
    }
}

// MARK: - DayCell
private struct DayCell: View {
    let date: Date?
    let isToday: Bool
    let isInMonth: Bool
    let done: Bool

    var body: some View {
        ZStack {
            if let _ = date {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fillStyle)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(
                                isToday
                                ? GlowTheme.textPrimary.opacity(0.35)
                                : .clear,
                                lineWidth: 1
                            )
                    )
                    .frame(height: 24)
                    .overlay(
                        Text(dateLabel)
                            .font(.caption2)
                            .foregroundStyle(
                                isInMonth
                                ? GlowTheme.textPrimary.opacity(0.8)
                                : GlowTheme.textSecondary.opacity(0.5)
                            )
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
        if !isInMonth {
            return GlowTheme.borderMuted.opacity(0.08)
        }
        return done
            ? GlowTheme.accentPrimary.opacity(0.85)
            : GlowTheme.borderMuted.opacity(0.15)
    }

    private var dateLabel: String {
        guard let d = date else { return "" }
        return Calendar.current.component(.day, from: d).description
    }

    private var accessibilityLabel: String {
        guard let d = date else { return "" }
        let formatted = d.formatted(date: .abbreviated, time: .omitted)
        return done
            ? "Completed on \(formatted)"
            : "Not completed on \(formatted)"
    }
}
