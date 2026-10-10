import Charts
import Combine
import SwiftData
import SwiftUI

@MainActor
final class WaterReportViewModel: ObservableObject {
    @Published private(set) var days: [WaterDaySummary] = []

    func refresh(entries: [WaterEntryValue], goals: [WaterGoalValue], now: Date) {
        days = WaterAnalytics.summaries(entries: entries, goals: goals, days: 30, now: now)
    }

    func recent(_ count: Int) -> [WaterDaySummary] { Array(days.suffix(count)) }

    func story(_ count: Int) -> String {
        let recent = recent(count)
        let logged = recent.filter(\.isLogged).count
        guard logged > 0 else { return "Log water on Today to start seeing your daily rhythm." }
        let reached = recent.filter(\.reachedGoal).count
        return "You reached your saved water goal on \(reached) of the last \(count) days, with water logged on \(logged)."
    }
}

struct WaterInsightsView: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            WaterReportCard(now: timeline.date)
        }
    }
}

private struct WaterReportInput: Equatable {
    let entries: [WaterEntryValue]
    let goals: [WaterGoalValue]
    let dayKey: String
}

private struct WaterReportCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var entries: [WaterEntry]
    @Query private var goals: [WaterDayGoal]
    @Query(sort: [SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)])
    private var preferences: [WaterPreferences]
    @StateObject private var viewModel = WaterReportViewModel()
    @State private var range = 7
    @State private var historyDay: WaterDaySummary?
    let now: Date

    init(now: Date) {
        self.now = now
        let start = Calendar.current.date(byAdding: .day, value: -29, to: now) ?? now
        let firstKey = WaterAnalytics.dayKey(start)
        let lastKey = WaterAnalytics.dayKey(now)
        _entries = Query(filter: #Predicate<WaterEntry> { $0.dayKey >= firstKey && $0.dayKey <= lastKey })
        _goals = Query(filter: #Predicate<WaterDayGoal> { $0.dayKey >= firstKey && $0.dayKey <= lastKey })
    }

    private var unit: WaterUnit { preferences.first?.unit ?? .ounces }
    private var input: WaterReportInput {
        WaterReportInput(entries: entries.map { WaterEntryValue($0) }, goals: goals.map { WaterGoalValue($0) },
                         dayKey: WaterAnalytics.dayKey(now))
    }
    private var days: [WaterDaySummary] { viewModel.recent(range) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Water rhythm", systemImage: "drop.fill")
                .font(.headline).accessibilityAddTraits(.isHeader)
            Picker("Water reporting period", selection: $range) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("waterReportRange")

            Text(viewModel.story(range))
                .font(.subheadline).foregroundStyle(GlowTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("waterReportStory")

            if days.contains(where: \.isLogged) {
                chart
                let logged = days.filter(\.isLogged)
                let average = logged.reduce(0) { $0 + $1.milliliters } / Double(max(1, logged.count))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 24) { metrics(average: average, logged: logged.count) }
                    VStack(alignment: .leading, spacing: 12) { metrics(average: average, logged: logged.count) }
                }
            }

            DisclosureGroup("Daily history") {
                ForEach(days.reversed()) { day in
                    Button { historyDay = day } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.date, format: .dateTime.month(.abbreviated).day())
                                Spacer()
                                Text(day.isLogged ? unit.label(day.milliliters) : "No log")
                            }
                            if day.isLogged, let goal = day.goalMilliliters {
                                Label("Goal \(unit.label(goal))\(day.reachedGoal ? " · Reached" : "")",
                                      systemImage: day.reachedGoal ? "checkmark.circle.fill" : "circle")
                                    .font(.caption).foregroundStyle(GlowTheme.textSecondary)
                            }
                        }
                        .foregroundStyle(GlowTheme.textPrimary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Shows the entries for this day")
                    Divider()
                }
            }
            .font(.subheadline)
            .accessibilityIdentifier("waterDailyHistory")
        }
        .padding(20)
        .insightsSurfaceCard(cornerRadius: 20)
        .onChange(of: input, initial: true) { _, value in
            viewModel.refresh(entries: value.entries, goals: value.goals, now: now)
        }
        .sheet(item: $historyDay) { WaterHistoryView(day: $0.date) }
    }

    private var chart: some View {
        Chart(days) { day in
            if day.isLogged {
                BarMark(x: .value("Day", day.date, unit: .day), y: .value(unit.symbol, unit.value(from: day.milliliters)))
                    .foregroundStyle(GlowTheme.accentPrimary)
                    .cornerRadius(4)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("\(unit.label(day.milliliters)) logged\(day.reachedGoal ? ", goal reached" : "")")
                if let goal = day.goalMilliliters {
                    PointMark(x: .value("Day", day.date, unit: .day), y: .value(unit.symbol, unit.value(from: goal)))
                        .symbol(.diamond).symbolSize(24)
                        .foregroundStyle(GlowTheme.textSecondary)
                        .accessibilityLabel("Saved goal")
                        .accessibilityValue(unit.label(goal))
                }
            } else {
                PointMark(x: .value("Day", day.date, unit: .day), y: .value(unit.symbol, 0))
                    .symbol(.circle).symbolSize(12)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue("No water logged")
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in AxisValueLabel(format: .dateTime.day()) } }
        .chartYAxisLabel(unit.symbol)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 240 : 180)
        .overlay(alignment: .topLeading) {
            Text("◆ Saved goal").font(.caption2).foregroundStyle(GlowTheme.textSecondary)
        }
    }

    @ViewBuilder
    private func metrics(average: Double, logged: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(unit.label(average)).font(.title3.weight(.semibold))
            Text("Average on logged days").font(.caption).foregroundStyle(GlowTheme.textSecondary)
        }
        VStack(alignment: .leading, spacing: 4) {
            Text("\(logged) of \(range)").font(.title3.weight(.semibold))
            Text("Days with water logged").font(.caption).foregroundStyle(GlowTheme.textSecondary)
        }
    }
}
