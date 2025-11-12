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
}

private func loadTodayProgress() -> (done: Int, total: Int, bonus: Int) {
    let defaults = UserDefaults(suiteName: appGroupID)
    let done = defaults?.integer(forKey: "today_done") ?? 0
    let total = defaults?.integer(forKey: "today_total") ?? 0
    let bonus = defaults?.integer(forKey: "today_bonus") ?? 0
    let savedDate = defaults?.string(forKey: "today_date")
    
    // compare to today; if mismatched, return last known values if present (avoid showing stale zeros)
    let today = Calendar.current.startOfDay(for: Date())
    let formatter = DateFormatter()
    formatter.calendar = Calendar.current
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    let todayString = formatter.string(from: today)
    
    if let savedDate, savedDate == todayString {
        return (done, total, bonus)
    } else if (done > 0 || total > 0 || bonus > 0) {
        // show last known values even if the saved date mismatched (fallback)
        return (done, total, bonus)
    } else {
        return (0, 0, 0)
    }
}

// 1) The data the widget shows
struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let done: Int
    let total: Int
    let bonus: Int
}

// 2) Where the widget gets its data
struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: Date(), done: 2, total: 3, bonus: 0)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> ()) {
        let progress = loadTodayProgress()
        completion(TodayProgressEntry(date: Date(), done: progress.done, total: progress.total, bonus: progress.bonus))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: appGroupID)
        let done = defaults?.integer(forKey: "today_done") ?? 0
        let total = defaults?.integer(forKey: "today_total") ?? 0
        let bonus = defaults?.integer(forKey: "today_bonus") ?? 0
        let savedStamp = defaults?.integer(forKey: "today_stamp") ?? 0

        let now = Date()
        let todayStamp = yyyyMMddStamp(for: now)

        // If the saved stamp matches today, use saved counts; otherwise reset to 0s.
        let currentEntry: TodayProgressEntry
        if savedStamp == todayStamp {
            currentEntry = TodayProgressEntry(date: now, done: done, total: total, bonus: bonus)
        } else {
            currentEntry = TodayProgressEntry(date: now, done: 0, total: 0, bonus: 0)
        }

        // Always schedule an automatic rollover entry at the next midnight so the widget resets
        // even if the app hasn't been launched yet.
        let midnight = nextMidnight(after: now)
        let rolloverEntry = TodayProgressEntry(date: midnight.addingTimeInterval(5), done: 0, total: 0, bonus: 0)

        // Build the timeline: now -> midnight reset. After that, WidgetKit will ask again.
        let timeline = Timeline(entries: [currentEntry, rolloverEntry], policy: .atEnd)
        completion(timeline)
    }

    private func yyyyMMddStamp(for date: Date) -> Int {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return (c.year ?? 0) * 10_000 + (c.month ?? 0) * 100 + (c.day ?? 0)
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
    
    // Glow-ish palette — gentle but colorful
    private let glowAccent = Color(red: 0.63, green: 0.24, blue: 0.93)
    private let glowSoft = Color(red: 0.96, green: 0.92, blue: 1.0)
    
    private var percent: Double {
        guard entry.total > 0 else { return 0 }
        return Double(entry.done) / Double(entry.total)
    }
    
    private func message(compact: Bool) -> String {
        // Nothing scheduled
        if entry.total == 0 {
            return compact ? "Rest day" : "Nothing scheduled"
        }
        
        // All scheduled done
        if entry.done >= entry.total {
            if entry.bonus > 0 {
                // Bonus wins beyond the plan
                return compact ? "Bonus +\(entry.bonus) 🔥" : "Bonus wins +\(entry.bonus)"
            } else {
                return compact ? "Glow day ✨" : "All done — nice."
            }
        }
        
        // Not started
        if entry.done == 0 {
            return compact ? "Ready to start…" : "Ready to start…"
        }
        
        // In progress — rotate through short, non-corny nudges
        let long = [
            "Nice first step",
            "Keep the rhythm",
            "Momentum building",
            "Looking good",
            "Halfway there",
            "Past halfway",
            "Almost there",
            "One more to go"
        ]
        let short = [
            "Nice start",
            "Keep going",
            "Momentum up",
            "Looking good",
            "Halfway",
            "Past halfway",
            "Almost there",
            "One to go"
        ]
        let idx = max(0, min(entry.done - 1, long.count - 1))
        return compact ? short[idx] : long[idx]
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
        ZStack {
            RoundedRectangle(cornerRadius: WidgetTokens.cornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [glowSoft, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            if colorScheme == .dark {
                RadialGradient(
                    colors: [glowAccent.opacity(0.55), .clear],
                    center: .topLeading,
                    startRadius: 6,
                    endRadius: 160
                )
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: WidgetTokens.cornerRadius, style: .continuous))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                // top bar
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(glowAccent.opacity(0.16))
                        Image(systemName: "leaf.fill")
                            .foregroundStyle(glowAccent)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(width: 28, height: 28)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Glow • Today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(message(compact: false))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    Spacer()
                    
                    // pill for the count — softened to 0.32 to match app glass
                    Text("\(entry.done)/\(entry.total)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, WidgetTokens.pillPaddingH)
                        .padding(.vertical, WidgetTokens.pillPaddingV)
                        .background(
                            Capsule()
                                .fill(
                                    colorScheme == .dark
                                    ? Color.white.opacity(0.12)
                                    : Color.white.opacity(0.32)
                                )
                        )
                        .foregroundStyle(
                            colorScheme == .dark ? Color.white.opacity(0.85) : .secondary
                        )
                }
                
                // progress bar
                GeometryReader { geo in
                    let progressWidth = max(7, geo.size.width * percent)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.04)
                            )
                        Capsule()
                            .fill(glowAccent)
                            .frame(width: progressWidth)
                    }
                    .frame(height: WidgetTokens.progressHeight)
                    .mask(Capsule())
                }
                .frame(height: WidgetTokens.progressHeight)
                
                if entry.total == 0 {
                    Text("No practices scheduled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            // slightly more breathing room — 12 feels closer to your Home
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .applyWidgetBackground()
    }
    
    // MARK: - Small home widget
    private var compactMainView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WidgetTokens.cornerRadius, style: .continuous)
                .fill(
                    colorScheme == .dark
                    ? LinearGradient(
                        colors: [Color.black, Color.black.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    : LinearGradient(
                        colors: [glowSoft, Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            if colorScheme == .dark {
                RadialGradient(
                    colors: [glowAccent.opacity(0.5), .clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 120
                )
                .blendMode(.screen)
                .clipShape(RoundedRectangle(cornerRadius: WidgetTokens.cornerRadius, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.done)/\(entry.total)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                
                Text(message(compact: true))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                GeometryReader { geo in
                    let progressWidth = max(5, geo.size.width * percent)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.black.opacity(0.04)
                            )
                        Capsule()
                            .fill(glowAccent)
                            .frame(width: progressWidth)
                    }
                    .frame(height: WidgetTokens.progressHeight - 1)
                    .mask(Capsule())
                }
                .frame(height: WidgetTokens.progressHeight - 1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .applyWidgetBackground()
    }
    
    // MARK: - Lock screen rectangular
    private var rectangularView: some View {
        HStack {
            Text("Glow")
            Spacer()
            Text("\(entry.done)/\(entry.total)")
        }
        .applyWidgetBackground()
    }
    
    // MARK: - Lock screen circular
    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: entry.total > 0 ? CGFloat(percent) : 0)
                .stroke(glowAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(entry.done)")
                .font(.caption2)
        }
        .applyWidgetBackground()
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
