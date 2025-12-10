import SwiftUI
import SwiftData
import Combine

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
        GeometryReader { proxy in
            let isRegularWidth = proxy.size.width >= 768
            let isLandscape = proxy.size.width > proxy.size.height
            let isPadPortrait = isRegularWidth && !isLandscape
            // iPhone stays as-is. On iPad (portrait and landscape), use a larger inset (~1 inch)
            // so the content has the same breathing room on the left and right.
            let horizontalInset: CGFloat = {
                if isRegularWidth {
                    return 96 // ~1 inch margin on each side on most iPads
                } else {
                    return 16
                }
            }()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: isRegularWidth ? 28 : 24) {

                    // HEADER / STREAKS
                    headerSection
                        .padding(.top, isRegularWidth ? 24 : 8)

                    // RECENT
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent")
                            .font(.headline)
                            .foregroundStyle(GlowTheme.textPrimary)

                        // Card with symmetrical padding so colored boxes float inside
                        ZStack {
                            // Card background and border
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(GlowTheme.bgSurface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
                                )
                                .shadow(
                                    color: Color.black.opacity(0.15),
                                    radius: 20, y: 10
                                )
                            // Content with inner padding
                            RecentDaysStrip(
                                logs: viewModel.logs,
                                startDate: viewModel.habit.createdAt,
                                days: 14,
                                tint: viewModel.habitTint
                            )
                            .padding(12)
                        }
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
                        .frame(height: isRegularWidth ? 180 : 120)
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
                            model: viewModel.monthModel,
                            tint: viewModel.habitTint,
                            onPrev: { viewModel.goToPreviousMonth() },
                            onNext: { viewModel.goToNextMonth() }
                        )
                    }

                    Spacer(minLength: isPadPortrait ? 0 : (isRegularWidth ? 64 : 32))
                }
                .padding(.top, isPadPortrait ? 120 : 0)
                .padding(.horizontal, horizontalInset)
                .padding(.bottom, isPadPortrait ? 0 : (isRegularWidth ? 40 : 24))
                // Use nearly full width on iPad while keeping a margin from the edges
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .onAppear { viewModel.refreshFromStore() }
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                viewModel.refreshFromStore()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowDataDidChange)) { _ in
                viewModel.refreshFromStore()
            }
        }
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

// MARK: - WeeklyProgressRing
private struct WeeklyProgressRing: View {
    let percent: Double
    let tint: Color
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        let isRegularWidth = horizontalSizeClass == .regular
        ZStack {
            Circle()
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: isRegularWidth ? 14 : 12)

            Circle()
                .trim(from: 0, to: max(0, min(1, percent)))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: isRegularWidth ? 16 : 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: percent)

            Text("\(Int(percent * 100))%")
                .font((isRegularWidth ? Font.title2 : Font.headline).monospacedDigit())
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
    private let cycleStart: Date
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(logs: [HabitLog], startDate: Date, days: Int, tint: Color) {
        self.days = days
        self.tint = tint

        // Work with locals first to avoid capturing self during initialization.
        let cal = Calendar.current
        let todayLocal = cal.startOfDay(for: Date())

        // Normalize all completed log dates to start-of-day and ignore anything in the future.
        let completedDates = logs
            .filter { $0.completed }
            .map { cal.startOfDay(for: $0.date) }
            .filter { $0 <= todayLocal }

        // The origin of the habit timeline is the first completed day; if there are
        // no completions yet, fall back to the habit's creation date.
        let originLocal: Date
        if let first = completedDates.min() {
            originLocal = first
        } else {
            originLocal = cal.startOfDay(for: startDate)
        }

        // How many days have elapsed since the origin (0-based).
        let dayIndexLocal = max(0, cal.dateComponents([.day], from: originLocal, to: todayLocal).day ?? 0)

        // Determine which 14-day window we are in, starting from the origin. This keeps
        // the strip as a 14-day window that advances in chunks of `days`, while still
        // ensuring that the very first completion appears in the left-most box.
        let cycleIndexLocal = dayIndexLocal / days

        // The calendar date for the first slot in the current 14-day window.
        let cycleStartLocal = cal.date(byAdding: .day, value: cycleIndexLocal * days, to: originLocal) ?? originLocal

        // Completed days as a set for fast lookup.
        let completedSet = Set(completedDates)

        // Assign stored properties last.
        self.calendar = cal
        self.today = todayLocal
        self.cycleStart = cycleStartLocal
        self.completed = completedSet
    }

    var body: some View {
        let isRegularWidth = horizontalSizeClass == .regular
        let spacing: CGFloat = isRegularWidth ? 8 : 4
        let cellHeight: CGFloat = isRegularWidth ? 28 : 20

        HStack(spacing: spacing) {
            ForEach(0..<days, id: \.self) { offset in
                // Date for this slot in the current 14-day cycle.
                let date = calendar.date(byAdding: .day, value: offset, to: cycleStart) ?? today
                let normalized = calendar.startOfDay(for: date)
                let done = normalized <= today && completed.contains(normalized)

                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(done ? tint : GlowTheme.borderMuted.opacity(0.6))
                    .frame(maxWidth: .infinity)     // each box takes equal horizontal space
                    .frame(height: cellHeight)      // consistent row height
                    .accessibilityHidden(false)
                    .accessibilityLabel(accessibilityLabel(for: normalized, done: done))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func accessibilityLabel(for date: Date, done: Bool) -> String {
        let formatted = date.formatted(date: .abbreviated, time: .omitted)
        return done
            ? "Completed on \(formatted)"
            : "Not completed on \(formatted)"
    }
}

// MARK: - MonthHeatmap
private struct MonthHeatmap: View {
    let model: MonthHeatmapModel
    let tint: Color
    let onPrev: () -> Void
    let onNext: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
            ForEach(Array(model.weekdays.enumerated()), id: \.offset) { _, d in
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let vSpacing: CGFloat = horizontalSizeClass == .regular ? 8 : 6
        let hSpacing: CGFloat = horizontalSizeClass == .regular ? 8 : 6
        return VStack(spacing: vSpacing) {
            ForEach(0..<model.gridDates.count, id: \.self) { row in
                HStack(spacing: hSpacing) {
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

    init(habit: Habit, month: Date, logs: [HabitLog]? = nil) {
        // --------- Locals first (avoid referencing self during init) ---------
        let cal = Calendar.current
        let todayLocal = cal.startOfDay(for: Date())
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: month))
        let endOfMonth = startOfMonth.flatMap { cal.date(byAdding: DateComponents(month: 1), to: $0) }
        let daysRange = startOfMonth.flatMap { cal.range(of: .day, in: .month, for: $0) }

        // Use the explicit logs list if provided; otherwise fall back to the habit's relationship.
        let sourceLogs = logs ?? (habit.logs ?? [])

        // Build the 6x7 month grid (including leading/trailing blanks)
        var computedGrid: [[Date?]] = [Array(repeating: nil, count: 7)]
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
            computedGrid = weeks
        }

        // Dates that belong to the visible month
        let monthDates: [Date] = computedGrid
            .flatMap { $0 }
            .compactMap { $0 }
            .filter { cal.isDate($0, equalTo: month, toGranularity: .month) }

        // Completed days for this month, **ignoring any date after today**
        let completedSet: Set<Date>
        if let start = startOfMonth,
           let end = cal.date(byAdding: DateComponents(month: 1), to: start) {
            let normalized = sourceLogs
                .filter { $0.completed }
                .map { cal.startOfDay(for: $0.date) }
                .filter { $0 >= start && $0 < end && $0 <= todayLocal }

            completedSet = Set(normalized)
        } else {
            completedSet = []
        }

        // Percent complete = completed cells / total cells in month (up to today handled by completedSet)
        let doneCount = monthDates.filter { completedSet.contains(cal.startOfDay(for: $0)) }.count
        let daysInMonth = daysRange?.count ?? monthDates.count
        let denominator: Int
        if let start = startOfMonth, let end = endOfMonth {
            if todayLocal < start {
                denominator = 0 // future month
            } else if todayLocal >= end {
                denominator = daysInMonth // past month: whole month counts
            } else {
                // current month: only count days that have occurred (inclusive of today)
                let elapsed = (cal.dateComponents([.day], from: start, to: todayLocal).day ?? 0) + 1
                denominator = min(daysInMonth, elapsed)
            }
        } else {
            denominator = monthDates.count
        }

        let pctLocal: Int
        if denominator == 0 {
            pctLocal = 0
        } else {
            pctLocal = Int((Double(doneCount) / Double(denominator)) * 100.0)
        }

        // Month streak based on logs in this month **up to today only**,
        // using one completion per calendar day (to match HomeViewModel’s global streak logic).
        let inMonthCompletedLogs = sourceLogs.filter {
            $0.completed
            && cal.isDate($0.date, equalTo: month, toGranularity: .month)
            && cal.startOfDay(for: $0.date) <= todayLocal
        }

        let groupedByDay = Dictionary(grouping: inMonthCompletedLogs) { log in
            cal.startOfDay(for: log.date)
        }

        let syntheticMonthLogs: [HabitLog] = groupedByDay.keys.map { day in
            HabitLog(date: day, completed: true, habit: Habit.placeholder)
        }

        let monthStreakLocal = StreakEngine.computeStreaks(logs: syntheticMonthLogs).current

        // --------- Assign stored properties last ---------
        self.cal = cal
        self.month = month
        self.today = todayLocal
        self.monthTitle = month.formatted(.dateTime.year().month(.wide))
        self.gridDates = computedGrid
        self.completedDays = completedSet
        self.totalDaysInMonth = monthDates
        self.pct = pctLocal
        self.monthStreak = monthStreakLocal
    }

    func isToday(_ date: Date) -> Bool { cal.startOfDay(for: date) == today }
    func isInMonth(_ date: Date) -> Bool { cal.isDate(date, equalTo: month, toGranularity: .month) }
    func isCompleted(_ date: Date) -> Bool { completedDays.contains(cal.startOfDay(for: date)) }
}

// MARK: - DayCell
private struct DayCell: View {
    let date: Date?
    let isToday: Bool
    let isInMonth: Bool
    let done: Bool
    let tint: Color
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
                    .frame(height: cellHeight)
                    .overlay(
                        Text(dateLabel)
                            .font(horizontalSizeClass == .regular ? .caption : .caption2)
                            .foregroundStyle(
                                isInMonth
                                ? GlowTheme.textPrimary.opacity(0.8)
                                : GlowTheme.textSecondary.opacity(0.5)
                            )
                    )
            } else {
                Color.clear.frame(height: cellHeight)
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

    private var cellHeight: CGFloat {
        horizontalSizeClass == .regular ? 32 : 24
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
