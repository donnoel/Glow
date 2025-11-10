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

// 2) Where the widget gets its data (for now: hardcoded)
struct TodayProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayProgressEntry {
        // placeholder can stay fake
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

// 3) What the widget looks like (home screen version)
struct TodayProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: TodayProgressEntry

    private let glowAccent = Color(red: 0.63, green: 0.24, blue: 0.93)

    // convenience
    private var percent: Double {
        guard entry.total > 0 else { return 0 }
        return Double(entry.done) / Double(entry.total)
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

    private var statusTitle: String {
        if entry.total > 0 && entry.done >= entry.total {
            return "You’re glowing ✨"
        } else {
            return "Keep going"
        }
    }

    // MARK: - Home screen (small / medium)
    private var mainView: some View {
        ZStack {
            // subtle background so it feels more "Glow"
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    // app badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.purple.opacity(0.25))
                        Image(systemName: "sparkles")
                            .foregroundStyle(Color.purple)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today’s progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statusTitle)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Text("\(entry.done)/\(entry.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.black.opacity(0.05))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 999)
                            .fill(Color.purple)
                            .frame(width: max(6, geo.size.width * percent), height: 6)
                            .animation(.easeOut(duration: 0.25), value: percent)
                    }
                }
                .frame(height: 6)

                if entry.total == 0 {
                    Text("No practices scheduled")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .applyWidgetBackground()
    }

    private var compactMainView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white, Color.white.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Today")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.done)/\(entry.total)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(statusTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 999)
                        .fill(Color.purple)
                        .frame(width: nil, height: 5)
                        .overlay(
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(Color.purple)
                                    .frame(width: max(5, geo.size.width * percent))
                            }
                        )
                }
                .frame(height: 5)
            }
            .padding(10)
        }
        .applyWidgetBackground()
    }

    // MARK: - Lock screen rectangular
    private var rectangularView: some View {
        HStack {
            Text("Today")
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
                .stroke(.primary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
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
