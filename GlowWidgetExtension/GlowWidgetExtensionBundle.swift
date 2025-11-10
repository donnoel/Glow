import WidgetKit
import SwiftUI

// read today's progress from the shared app group
private let appGroupID = "group.movie.Glow"

private func loadTodayProgress() -> (done: Int, total: Int) {
    let defaults = UserDefaults(suiteName: appGroupID)
    let done = defaults?.integer(forKey: "today_done") ?? 0
    let total = defaults?.integer(forKey: "today_total") ?? 0
    return (done, total)
}

// 1) The data the widget shows
struct TodayProgressEntry: TimelineEntry {
    let date: Date
    let done: Int
    let total: Int
}

// 2) Where the widget gets its data
struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        TodayProgressEntry(date: Date(), done: 2, total: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayProgressEntry) -> ()) {
        let progress = loadTodayProgress()
        completion(TodayProgressEntry(date: Date(), done: progress.done, total: progress.total))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayProgressEntry>) -> ()) {
        let progress = loadTodayProgress()
        let entry = TodayProgressEntry(date: Date(), done: progress.done, total: progress.total)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// 3) What the widget looks like
struct TodayProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayProgressEntry

    // Glow-ish palette — gentle but colorful
    private let glowAccent = Color(red: 0.63, green: 0.24, blue: 0.93)
    private let glowSoft = Color(red: 0.96, green: 0.92, blue: 1.0)

    private var percent: Double {
        guard entry.total > 0 else { return 0 }
        return Double(entry.done) / Double(entry.total)
    }

    private var statusTitle: String {
        if entry.total > 0 && entry.done >= entry.total {
            return "You’re glowing ✨"
        } else {
            return "Keep going"
        }
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [glowSoft, Color.white],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
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
                        // small, quiet label so it doesn't fight the status line
                        Text("Glow • Today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(statusTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    // pill for the count
                    Text("\(entry.done)/\(entry.total)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.6))
                        )
                        .foregroundStyle(.secondary)
                }

                // progress bar
                GeometryReader { geo in
                    let progressWidth = max(7, geo.size.width * percent)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.04))
                        Capsule()
                            .fill(glowAccent)
                            .frame(width: progressWidth)
                    }
                    .frame(height: 7)
                    .mask(Capsule())
                }
                .frame(height: 7)

                if entry.total == 0 {
                    Text("No practices scheduled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
        }
        .applyWidgetBackground()
    }

    // MARK: - Small home widget
    private var compactMainView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [glowSoft, Color.white],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
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

                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                GeometryReader { geo in
                    let progressWidth = max(5, geo.size.width * percent)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.04))
                        Capsule()
                            .fill(glowAccent)
                            .frame(width: progressWidth)
                    }
                    .frame(height: 5)
                    .mask(Capsule())
                }
                .frame(height: 5)
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 4)
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

// 5) Entry point for the widget target
@main
struct GlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        TodayProgressWidget()
    }
}
