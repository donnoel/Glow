import SwiftUI
import SwiftData

struct HabitDetailView: View {
    let habit: Habit
    @State private var monthAnchor: Date = .now

    private var habitTint: Color {
        habit.accentColor
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // HEADER / STREAKS
                headerSection
                    .padding(.top, 8) // slight breathing under nav bar

                // RECENT
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(GlowTheme.textPrimary)

                    RecentDaysStrip(logs: habit.logs, days: 14, tint: habitTint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(GlowTheme.bgSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
                        )
                        .shadow(
                            color: Color.black.opacity(0.15),
                            radius: 20, y: 10
                        )
                }

                // WEEK
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(GlowTheme.textPrimary)

                    WeeklyProgressRing(percent: weeklyPercent(from: habit.logs), tint: habitTint)
                        .frame(height: 120)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(habitTint.opacity(0.08))
                                        .blendMode(.plusLighter)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(
                                            habitTint.opacity(0.28),
                                            lineWidth: 1
                                        )
                                )
                                .shadow(
                                    color: Color.black.opacity(0.4),
                                    radius: 20, y: 10
                                )
                        )
                }

                // MONTHLY
                VStack(alignment: .leading, spacing: 8) {
                    Text("Monthly")
                        .font(.headline)
                        .foregroundStyle(GlowTheme.textPrimary)

                    MonthHeatmap(
                        habit: habit,
                        month: monthAnchor,
                        tint: habitTint,
                        onPrev: {
                            if let prev = Calendar.current.date(byAdding: .month, value: -1, to: monthAnchor) {
                                monthAnchor = prev
                            }
                        },
                        onNext: {
                            if let next = Calendar.current.date(byAdding: .month, value: 1, to: monthAnchor) {
                                monthAnchor = next
                            }
                        }
                    )
                }

                // >>> THIS IS THE MAGIC LINE <<<
                // This guarantees we ALWAYS get comfy air below the calendar
                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24) // keeps it off the home bar / bottom edge
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Header / Streaks (unchanged layout, just pulled into VStack world)
    // MARK: - Header / Streaks
    private var headerSection: some View {
        let s = computeStreaks(from: habit.logs)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {

                // icon bubble
                ZStack {
                    Circle()
                        .fill(
                            habitTint.opacity(0.18)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    habitTint.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: habit.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(habitTint)
                }

                // title + streaks
                VStack(alignment: .leading, spacing: 4) {
                    Text(habit.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)

                    HStack(spacing: 12) {
                        Label {
                            Text("\(s.current)d streak")
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "flame.fill")
                        }

                        Label {
                            Text("best \(s.best)d")
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "trophy.fill")
                        }
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(GlowTheme.textSecondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current streak \(s.current) days. Best streak \(s.best) days.")
                }

                Spacer(minLength: 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(GlowTheme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 20,
            y: 10
        )
    }
    // MARK: - Helpers
    private func weeklyPercent(from logs: [HabitLog]) -> Double {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // today + previous 6 days = 7
        guard let start = cal.date(byAdding: .day, value: -6, to: today) else {
            return 0.0
        }

        let completed = Set(
            logs
                .filter { $0.completed && $0.date >= start }
                .map { cal.startOfDay(for: $0.date) }
        )

        var hits = 0
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -i, to: today) else { continue }
            let d = cal.startOfDay(for: day)
            if completed.contains(d) {
                hits += 1
            }
        }

        return Double(hits) / 7.0
    }

    private func computeStreaks(from logs: [HabitLog]) -> (current: Int, best: Int) {
        StreakEngine.computeStreaks(logs: logs)
    }
}

// MARK: - WeeklyProgressRing (unchanged)
private struct WeeklyProgressRing: View {
    let percent: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 12)

            Circle()
                .trim(from: 0, to: max(0, min(1, percent)))
                .stroke(
                    tint,
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
    let tint: Color
    
    var body: some View {
        let cal = Calendar.current
        let completed = Set(
            logs
                .filter { $0.completed }
                .map { cal.startOfDay(for: $0.date) }
        )
        
        GeometryReader { geo in
            let today = cal.startOfDay(for: Date())
            let totalWidth = geo.size.width
            let spacing: CGFloat = 6
            let count = CGFloat(days)
            let itemSize = max(16, (totalWidth - (spacing * (count - 1))) / count)
            
            VStack {
                Spacer(minLength: 0)
                HStack(spacing: spacing) {
                    ForEach(0..<days, id: \.self) { offset in
                        let base = cal.date(byAdding: .day, value: -offset, to: today) ?? today
                        let cellDate = cal.startOfDay(for: base)
                        let done = completed.contains(cellDate)
                        
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(done ? tint : GlowTheme.borderMuted.opacity(0.6))
                            .frame(width: itemSize, height: itemSize)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - MonthHeatmap (mostly unchanged, just standalone)
private struct MonthHeatmap: View {
    let habit: Habit
    let month: Date
    let tint: Color
    let onPrev: () -> Void
    let onNext: () -> Void
    
    private var cal: Calendar { Calendar.current }
    
    private var monthTitle: String {
        month.formatted(.dateTime.year().month(.wide))
    }
    
    private var gridDates: [[Date?]] {
        guard let first = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let range = cal.range(of: .day, in: .month, for: first) else {
            // fallback: a single empty week
            return [Array(repeating: nil, count: 7)]
        }
        
        let count = range.count
        let firstWeekday = cal.component(.weekday, from: first) // Sun = 1
        let leadingBlanks = firstWeekday - 1
        
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        
        for day in 1...count {
            if let d = cal.date(byAdding: .day, value: day - 1, to: first) {
                cells.append(d)
            }
        }
        
        // pad to full weeks
        while cells.count % 7 != 0 { cells.append(nil) }
        while cells.count < 42 { cells.append(nil) }
        
        var weeks: [[Date?]] = []
        for i in stride(from: 0, to: cells.count, by: 7) {
            weeks.append(Array(cells[i..<min(i + 7, cells.count)]))
        }
        return weeks
    }
    
    private var completedDays: Set<Date> {
        guard let start = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let end = cal.date(byAdding: DateComponents(month: 1, day: 0), to: start) else {
            return []
        }

        let normalized = habit.logs
            .filter { $0.completed && $0.date >= start && $0.date < end }
            .map { cal.startOfDay(for: $0.date) }
        return Set(normalized)
    }
    
    var body: some View {
        VStack(spacing: 8) {
            header
            weekdayHeader
            grid
            summary
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(GlowTheme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
        )
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 20, y: 10
        )
        .accessibilityElement(children: .contain)
    }
    
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
                            done: cellDate.map { completedDays.contains(cal.startOfDay(for: $0)) } ?? false,
                            tint: tint
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
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Month completion \(pct) percent. Current month streak \(monthStreak) days."
        )
    }
}

// MARK: - DayCell (unchanged)
private struct DayCell: View {
    let date: Date?
    let isToday: Bool
    let isInMonth: Bool
    let done: Bool
    let tint: Color
    
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
        ? tint.opacity(0.85)
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
