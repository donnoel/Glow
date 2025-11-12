import SwiftUI
import SwiftData

struct HabitDetailView: View {
    @StateObject private var viewModel: HabitDetailViewModel

    init(habit: Habit, prewarmedMonth: MonthHeatmapModel? = nil) {
        _viewModel = StateObject(
            wrappedValue: HabitDetailViewModel(
                habit: habit,
                prewarmedMonth: prewarmedMonth
            )
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {

                // HEADER / STREAKS
                headerSection
                    .padding(.top, 8)

                // RECENT
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(GlowTheme.textPrimary)

                    RecentDaysStrip(
                        logs: viewModel.logs,
                        days: 14,
                        tint: viewModel.habitTint
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .glowSurfaceCard(cornerRadius: 16)
                }

                // WEEK
                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(GlowTheme.textPrimary)

                    WeeklyProgressRing(
                        percent: viewModel.weeklyPercent(),
                        tint: viewModel.habitTint
                    )
                    .frame(height: 120)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(viewModel.habitTint.opacity(0.08))
                                    .blendMode(.plusLighter)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(viewModel.habitTint.opacity(0.28), lineWidth: 1)
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
                        model: MonthHeatmapModel(
                            habit: viewModel.habit,
                            month: viewModel.monthModel.month
                        ),
                        tint: viewModel.habitTint,
                        onPrev: { viewModel.goToPreviousMonth() },
                        onNext: { viewModel.goToNextMonth() }
                    )
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: - Header / Streaks
    private var headerSection: some View {
        let streaks = viewModel.streaks()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {

                // icon bubble
                ZStack {
                    Circle()
                        .fill(viewModel.habitTint.opacity(0.18))
                        .overlay(
                            Circle()
                                .stroke(viewModel.habitTint.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: viewModel.habit.iconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(viewModel.habitTint)
                }

                // title + streaks
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.habit.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)

                    HStack(spacing: 12) {
                        Label {
                            Text("\(streaks.current)d streak")
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "flame.fill")
                        }

                        Label {
                            Text("best \(streaks.best)d")
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: "trophy.fill")
                        }
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(GlowTheme.textSecondary)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Current streak \(streaks.current) days. Best streak \(streaks.best) days.")
                }

                Spacer(minLength: 8)
            }
        }
        .padding(16)
        .glowSurfaceCard(cornerRadius: 20)
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
    let days: Int
    let tint: Color
    private let calendar: Calendar
    private let today: Date
    private let completed: Set<Date>

    init(logs: [HabitLog], days: Int, tint: Color) {
        self.days = days
        self.tint = tint
        let cal = Calendar.current
        self.calendar = cal
        let today = cal.startOfDay(for: Date())
        self.today = today

        let completedSet = Set(
            logs
                .filter { $0.completed }
                .map { cal.startOfDay(for: $0.date) }
                .filter { $0 <= today }
        )
        self.completed = completedSet
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let spacing: CGFloat = 6
            let count = CGFloat(days)
            let itemSize = max(16, (totalWidth - (spacing * (count - 1))) / count)

            HStack(spacing: spacing) {
                ForEach(0..<days, id: \.self) { offset in
                    let base = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                    let cellDate = calendar.startOfDay(for: base)
                    let done = completed.contains(cellDate)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(done ? tint : GlowTheme.borderMuted.opacity(0.6))
                        .frame(width: itemSize, height: itemSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 44)
    }
}

// MARK: - MonthHeatmap
private struct MonthHeatmap: View {
    let model: MonthHeatmapModel
    let tint: Color
    let onPrev: () -> Void
    let onNext: () -> Void

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

            Text(model.monthTitle)
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
            ForEach(model.weekdays, id: \.self) { d in
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        VStack(spacing: 6) {
            ForEach(0..<model.gridDates.count, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        let cellDate = model.gridDates[row][col]
                        DayCell(
                            date: cellDate,
                            isToday: cellDate.map { model.isToday($0) } ?? false,
                            isInMonth: cellDate.map { model.isInMonth($0) } ?? false,
                            done: cellDate.map { model.isCompleted($0) } ?? false,
                            tint: tint
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                Text("\(model.pct)% this month")
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("Streak \(model.monthStreak)")
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
            "Month completion \(model.pct) percent. Current month streak \(model.monthStreak) days."
        )
    }
}

// MARK: - MonthHeatmapModel
struct MonthHeatmapModel {
    let cal: Calendar
    let month: Date
    let monthTitle: String
    let gridDates: [[Date?]]
    let completedDays: Set<Date>
    let totalDaysInMonth: [Date]
    let pct: Int
    let monthStreak: Int
    let today: Date
    let weekdays: [String] = ["S","M","T","W","Th","F","S"]

    init(habit: Habit, month: Date) {
        let cal = Calendar.current
        let todayLocal = cal.startOfDay(for: .now)
        let monthTitleLocal = month.formatted(.dateTime.year().month(.wide))

        // Build grid locally (do not touch self yet)
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        let daysRange = startOfMonth.flatMap { cal.range(of: .day, in: .month, for: $0) }

        var localGrid: [[Date?]] = [Array(repeating: nil, count: 7)]
        if let start = startOfMonth, let range = daysRange {
            let firstWeekday = cal.component(.weekday, from: start)
            let leadingBlanks = firstWeekday - 1

            var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)

            for day in 1...range.count {
                if let d = cal.date(byAdding: .day, value: day - 1, to: start) {
                    cells.append(d)
                }
            }

            while cells.count % 7 != 0 { cells.append(nil) }
            while cells.count < 42 { cells.append(nil) }

            var weeks: [[Date?]] = []
            for i in stride(from: 0, to: cells.count, by: 7) {
                weeks.append(Array(cells[i..<min(i + 7, cells.count)]))
            }
            localGrid = weeks
        }

        // Completed days for this month (normalized and clamped to today)
        let completedDaysLocal: Set<Date>
        if let start = startOfMonth,
           let end = cal.date(byAdding: DateComponents(month: 1, day: 0), to: start) {

            let normalized = (habit.logs ?? [])
                .filter { $0.completed }
                .map { cal.startOfDay(for: $0.date) }
                .filter { $0 >= start && $0 < end && $0 <= todayLocal }

            completedDaysLocal = Set(normalized)
        } else {
            completedDaysLocal = []
        }

        // All valid days inside the visible month
        let monthDatesLocal: [Date] = localGrid
            .flatMap { $0 }
            .compactMap { $0 }
            .filter { cal.isDate($0, equalTo: month, toGranularity: .month) }

        // Percent complete for the month
        let pctLocal: Int
        if monthDatesLocal.isEmpty {
            pctLocal = 0
        } else {
            let doneCount = monthDatesLocal.filter {
                completedDaysLocal.contains(cal.startOfDay(for: $0))
            }.count
            pctLocal = Int((Double(doneCount) / Double(monthDatesLocal.count)) * 100.0)
        }

        // Month streak — sanitize logs to start-of-day and clamp to today
        let sanitizedMonthLogs: [HabitLog] = (habit.logs ?? [])
            .filter { $0.completed && cal.isDate($0.date, equalTo: month, toGranularity: .month) }
            .map { HabitLog(date: cal.startOfDay(for: $0.date), completed: true, habit: nil) }
            .filter { $0.date <= todayLocal }

        let monthStreakLocal = StreakEngine.computeStreaks(
            logs: sanitizedMonthLogs,
            today: todayLocal,
            calendar: cal
        ).current

        // FINAL ASSIGNMENT — now it is safe to touch self
        self.cal = cal
        self.month = month
        self.monthTitle = monthTitleLocal
        self.gridDates = localGrid
        self.completedDays = completedDaysLocal
        self.totalDaysInMonth = monthDatesLocal
        self.pct = pctLocal
        self.monthStreak = monthStreakLocal
        self.today = todayLocal
    }

    func isToday(_ date: Date) -> Bool {
        cal.startOfDay(for: date) == today
    }

    func isInMonth(_ date: Date) -> Bool {
        cal.isDate(date, equalTo: month, toGranularity: .month)
    }

    func isCompleted(_ date: Date) -> Bool {
        completedDays.contains(cal.startOfDay(for: date))
    }
}

// MARK: - DayCell
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
                                isToday ? GlowTheme.textPrimary.opacity(0.35) : .clear,
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

// MARK: - Shared Card Style
private extension View {
    func glowSurfaceCard(cornerRadius: CGFloat = GlowTheme.Radius.medium) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(GlowTheme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.15),
                radius: 20, y: 10
            )
    }
}
