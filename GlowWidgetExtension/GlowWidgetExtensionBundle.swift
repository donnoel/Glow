import WidgetKit
import SwiftUI

// read today's progress from the shared app group
private let appGroupID = "group.movie.Glow"

// local widget design tokens so we don't depend on the main app target
private enum WidgetTokens {
    static let cornerRadius: CGFloat = 12
    static let pillPaddingH: CGFloat = 10
    static let pillPaddingV: CGFloat = 4
    static let progressHeight: CGFloat = 6
    static let markSpacing: CGFloat = 5
}

private struct TodayProgressSnapshot {
    let done: Int
    let total: Int
    let bonus: Int
    let isCurrentDay: Bool
}

private func loadTodayProgress() -> TodayProgressSnapshot {
    let defaults = UserDefaults(suiteName: appGroupID)
    let done = defaults?.integer(forKey: "today_done") ?? 0
    let total = defaults?.integer(forKey: "today_total") ?? 0
    let bonus = defaults?.integer(forKey: "today_bonus") ?? 0
    let savedStamp = defaults?.integer(forKey: "today_stamp") ?? 0

    return TodayProgressSnapshot(
        done: done,
        total: total,
        bonus: bonus,
        isCurrentDay: savedStamp == yyyyMMddStamp(for: Date())
    )
}

private func yyyyMMddStamp(for date: Date) -> Int {
    let cal = Calendar.current
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
}

// 1) The data the widget shows
struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let done: Int
    let total: Int
    let bonus: Int
    let isCurrentDay: Bool
}

// 2) Where the widget gets its data
struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: Date(), done: 2, total: 3, bonus: 0, isCurrentDay: true)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> ()) {
        let progress = loadTodayProgress()
        completion(
            TodayProgressEntry(
                date: Date(),
                done: progress.done,
                total: progress.total,
                bonus: progress.bonus,
                isCurrentDay: progress.isCurrentDay
            )
        )
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> ()) {
        let now = Date()
        let progress = loadTodayProgress()

        let currentEntry = TodayProgressEntry(
            date: now,
            done: progress.done,
            total: progress.total,
            bonus: progress.bonus,
            isCurrentDay: progress.isCurrentDay
        )

        // Always schedule an automatic rollover entry at the next midnight so the widget resets
        // even if the app hasn't been launched yet.
        let midnight = nextMidnight(after: now)
        let rolloverEntry = TodayProgressEntry(
            date: midnight.addingTimeInterval(5),
            done: progress.done,
            total: progress.total,
            bonus: progress.bonus,
            isCurrentDay: false
        )

        // Build the timeline: now -> midnight reset. After that, WidgetKit will ask again.
        let timeline = Timeline(entries: [currentEntry, rolloverEntry], policy: .atEnd)
        completion(timeline)
    }

    private func nextMidnight(after date: Date) -> Date {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        return cal.date(byAdding: .day, value: 1, to: startOfDay) ?? date.addingTimeInterval(24 * 60 * 60)
    }
}

// 3) What the widget looks like
struct TodayProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    var entry: TodayProgressEntry
    
    private let glowAccent = Color(red: 0.63, green: 0.24, blue: 0.93)
    private let completedAccent = Color(red: 0.10, green: 0.62, blue: 0.52)
    private let warmAccent = Color(red: 1.0, green: 0.66, blue: 0.20)
    private let tilePrimary = Color.white
    private let tileSecondary = Color.white.opacity(0.68)
    
    // Clamp percent so the ring never overfills
    private var percent: Double {
        if entry.total == 0 && entry.bonus > 0 {
            return 1
        }
        guard entry.total > 0 else { return 0 }
        let raw = Double(entry.done) / Double(entry.total)
        return min(max(raw, 0), 1)
    }
    
    // Reached today's goal?
    private var isComplete: Bool {
        entry.total > 0 && entry.done >= entry.total
    }

    private var countText: String {
        entry.isCurrentDay ? "\(entry.done)/\(entry.total)" : "Sync"
    }

    private var statusTitle: String {
        if !entry.isCurrentDay {
            return "Open Glow"
        }
        if entry.total == 0 {
            return entry.bonus > 0 ? "Bonus day" : "Clear day"
        }
        if entry.done >= entry.total {
            return "DONE"
        }
        if entry.done == 0 {
            return "READY"
        }
        return "Today"
    }

    private var statusDetail: String {
        if !entry.isCurrentDay {
            return "Refresh today's habits"
        }
        if entry.total == 0 {
            return entry.bonus > 0 ? "\(entry.bonus) bonus practice" : "No practices scheduled"
        }
        if entry.done >= entry.total {
            return entry.bonus > 0 ? "Goal met +\(entry.bonus) bonus" : "All practices done"
        }
        if entry.done == 0 {
            return "\(entry.total) practices due"
        }
        return "\(entry.done) checked in"
    }

    private var accessibilitySummary: String {
        if !entry.isCurrentDay {
            return "Glow needs to refresh today's habits."
        }
        if entry.total == 0 {
            return entry.bonus > 0
            ? "Glow today: \(entry.bonus) bonus practice completed."
            : "Glow today: no practices scheduled."
        }
        return "Glow today: \(entry.done) of \(entry.total) practices complete. \(Int(percent * 100)) percent."
    }

    @ViewBuilder
    private var widgetBackground: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.07, blue: 0.13),
                    Color(red: 0.08, green: 0.16, blue: 0.15),
                    Color(red: 0.18, green: 0.10, blue: 0.23)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    glowAccent.opacity(0.52),
                    .clear
                ],
                center: .topLeading,
                startRadius: 4,
                endRadius: family == .systemSmall ? 130 : 190
            )
            .blendMode(.screen)

            RadialGradient(
                colors: [
                    completedAccent.opacity(0.34),
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 8,
                endRadius: family == .systemSmall ? 120 : 180
            )
            .blendMode(.screen)
        }
    }

    @ViewBuilder
    private func practiceMarks(height: CGFloat = 9) -> some View {
        if entry.isCurrentDay && entry.total > 0 && entry.total <= 7 {
            HStack(spacing: WidgetTokens.markSpacing) {
                ForEach(0..<entry.total, id: \.self) { index in
                    Capsule()
                        .fill(index < entry.done ? completedAccent : markBackground)
                        .overlay(
                            Capsule()
                                .stroke(index < entry.done ? Color.clear : markStroke, lineWidth: 1)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: height)
            .accessibilityHidden(true)
        } else {
            progressBar(height: height)
        }
    }

    private func progressBar(height: CGFloat = WidgetTokens.progressHeight) -> some View {
        GeometryReader { geo in
            let rawWidth = geo.size.width * percent
            let progressWidth = percent > 0 ? max(height, rawWidth) : 0

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(markBackground)

                if progressWidth > 0 {
                    Capsule()
                        .fill(completedAccent)
                        .frame(width: progressWidth)
                }
            }
            .frame(height: height)
            .mask(Capsule())
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private var markBackground: Color {
        Color.white.opacity(0.16)
    }

    private var markStroke: Color {
        Color.white.opacity(0.18)
    }

    private var gaugeView: some View {
        ZStack {
            Circle()
                .stroke(markBackground, lineWidth: 9)

            Circle()
                .trim(from: 0, to: CGFloat(percent))
                .stroke(
                    completedAccent,
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: -1) {
                Text(entry.isCurrentDay ? "\(entry.done)" : "!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(tilePrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(entry.isCurrentDay ? "/\(entry.total)" : "sync")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tileSecondary)
                    .lineLimit(1)
            }
        }
        .accessibilityHidden(true)
    }

    private var syncBadge: some View {
        Image(systemName: "arrow.clockwise")
            .font(.caption.weight(.semibold))
            .foregroundStyle(glowAccent)
            .padding(7)
            .background(
                Circle()
                    .fill(Color.white.opacity(0.12))
            )
            .accessibilityHidden(true)
    }

    private var completionSeal: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.13))
            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(completedAccent)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    private var topLabel: some View {
        HStack(spacing: 6) {
            Text("Today")
                .font(.caption2.weight(.bold))
                .foregroundStyle(tileSecondary)

            Spacer(minLength: 4)

            if !entry.isCurrentDay {
                syncBadge
            }
        }
    }

    private var doneCountStack: some View {
        HStack(alignment: .lastTextBaseline, spacing: 4) {
            Text(entry.isCurrentDay ? "\(entry.done)" : "-")
                .font(.system(size: 72, weight: .black, design: .rounded))
                .foregroundStyle(tilePrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(entry.isCurrentDay ? "/\(entry.total)" : "")
                .font(.title2.weight(.bold))
                .foregroundStyle(tileSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private var detailLine: some View {
        HStack(spacing: 6) {
            if entry.isCurrentDay && entry.total > 0 && entry.done >= entry.total {
                completionSeal
                    .frame(width: 18, height: 18)
            } else if !entry.isCurrentDay {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(glowAccent)
            }

            Text(statusDetail)
                .font(.caption.weight(.medium))
                .foregroundStyle(tileSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private var bonusChip: some View {
        Group {
            if entry.isCurrentDay && entry.bonus > 0 {
                Text("+\(entry.bonus)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(warmAccent)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(warmAccent.opacity(colorScheme == .dark ? 0.18 : 0.14))
                    )
            }
        }
    }

    private var accessoryProgressMark: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 3)

            Circle()
                .trim(from: 0, to: entry.isCurrentDay ? CGFloat(percent) : 0)
                .stroke(completedAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if entry.isCurrentDay && isComplete {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(completedAccent)
            } else if entry.isCurrentDay {
                Text("\(entry.done)")
                    .font(.caption2)
            } else {
                Image(systemName: "arrow.clockwise")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(glowAccent)
            }
        }
        .accessibilityHidden(true)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            compactMainView
        case .accessoryRectangular:
            rectangularView
        case .accessoryCircular:
            circularView
        default:
            mainView
        }
    }
    
    // MARK: - Medium / regular home widget
    private var mainView: some View {
        HStack(alignment: .center, spacing: 14) {
            gaugeView
                .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 9) {
                topLabel

                Text(entry.isCurrentDay ? statusDetail : "Open Glow to refresh")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(tilePrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 8) {
                    practiceMarks(height: 10)
                    bonusChip
                }
            }
        }
        .padding(15)
        .applyWidgetBackground { widgetBackground }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
    
    // MARK: - Small home widget
    private var compactMainView: some View {
        VStack(alignment: .leading, spacing: 7) {
            topLabel

            Spacer(minLength: 0)

            doneCountStack

            detailLine

            practiceMarks(height: 9)
        }
        .padding(13)
        .applyWidgetBackground { widgetBackground }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
    
    // MARK: - Lock screen rectangular
    private var rectangularView: some View {
        HStack(spacing: 8) {
            accessoryProgressMark
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.isCurrentDay ? statusTitle : "Open Glow")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(entry.isCurrentDay ? countText : "Refresh today")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .applyWidgetBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
    
    // MARK: - Lock screen circular
    private var circularView: some View {
        accessoryProgressMark
        .applyWidgetBackground()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

// Helper to apply the iOS 17 container background but stay compatible with earlier iOS
private extension View {
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                Color.clear
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyWidgetBackground<Background: View>(
        @ViewBuilder _ background: () -> Background
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.containerBackground(for: .widget) {
                background()
            }
        } else {
            self
                .background(background())
                .clipShape(RoundedRectangle(cornerRadius: WidgetTokens.cornerRadius, style: .continuous))
        }
    }
}

// 4) The widget declaration
struct TodayProgressWidget: Widget {
    let kind: String = "TodayProgressWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayProgressProvider()) { entry in
            TodayProgressWidgetView(entry: entry)
        }
        .configurationDisplayName("Today’s Glow")
        .description("See your daily Glow progress.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular
        ])
    }
}

@main
struct GlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
    }
}
