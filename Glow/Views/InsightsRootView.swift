import SwiftData
import SwiftUI

struct InsightsRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var viewModel = InsightsViewModel()
    @State private var showAddHabit = false
    @State private var showsHistory = false

    private var isIPadRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    private var habitLabelWidth: CGFloat {
        isIPadRegularWidth ? 136 : 96
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if activeHabits.isEmpty {
                    emptyState
                } else if isIPadRegularWidth {
                    regularWidthContent
                } else {
                    compactContent
                }
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(isIPadRegularWidth ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddOrEditHabitForm(mode: .add)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                refreshInsights()
            }
            .onChange(of: habits) { _, _ in
                refreshInsights()
            }
            .background(screenBackground.ignoresSafeArea())
        }
        .background(screenBackground.ignoresSafeArea())
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            storyCard
            rhythmSection

            if !viewModel.highlights.isEmpty {
                highlightsSection
            }

            historySection
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    private var regularWidthContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            regularWidthStoryCard
            rhythmSection

            if !viewModel.highlights.isEmpty {
                highlightsSection
            }

            regularWidthHistorySection
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .padding(.bottom, 48)
        .frame(maxWidth: 1_120, alignment: .top)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var regularWidthStoryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Last 7 days", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(GlowTheme.accentPrimary)

                Spacer(minLength: 8)

                Text(viewModel.dateRangeText)
                    .font(.subheadline)
                    .foregroundStyle(GlowTheme.textSecondary)
            }

            HStack(alignment: .bottom, spacing: 36) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(viewModel.storyTitle)
                        .font(.title.weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)

                    Text(viewModel.storySummary)
                        .font(.body)
                        .foregroundStyle(GlowTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Label(viewModel.comparisonText, systemImage: comparisonSymbol)
                        .font(.subheadline)
                        .foregroundStyle(GlowTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let completionPercent = viewModel.completionPercent {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(completionPercent)%")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(GlowTheme.textPrimary)

                            Text("scheduled")
                                .font(.subheadline)
                                .foregroundStyle(GlowTheme.textSecondary)
                        }

                        ProgressView(
                            value: Double(viewModel.completedScheduled),
                            total: Double(max(viewModel.scheduled, 1))
                        )
                        .tint(GlowTheme.accentPrimary)
                    }
                    .frame(minWidth: 200, idealWidth: 280, maxWidth: 340, alignment: .leading)
                }
            }
        }
        .padding(24)
        .insightsSurfaceCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last seven days. \(viewModel.storyTitle). \(viewModel.storySummary) \(viewModel.comparisonText)")
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Label("Last 7 days", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlowTheme.accentPrimary)

                Spacer(minLength: 8)

                Text(viewModel.dateRangeText)
                    .font(.caption)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.storyTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                Text(viewModel.storySummary)
                    .font(.subheadline)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let completionPercent = viewModel.completionPercent {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(completionPercent)%")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(GlowTheme.textPrimary)

                        Text("of scheduled check-ins")
                            .font(.subheadline)
                            .foregroundStyle(GlowTheme.textSecondary)
                    }

                    ProgressView(
                        value: Double(viewModel.completedScheduled),
                        total: Double(max(viewModel.scheduled, 1))
                    )
                    .tint(GlowTheme.accentPrimary)
                }
            }

            Label(viewModel.comparisonText, systemImage: comparisonSymbol)
                .font(.footnote)
                .foregroundStyle(GlowTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .insightsSurfaceCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Last seven days. \(viewModel.storyTitle). \(viewModel.storySummary) \(viewModel.comparisonText)")
    }

    private var rhythmSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your rhythm")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                Text("Scheduled opportunities and the check-ins you made around them.")
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)
            }

            VStack(spacing: 0) {
                dayHeader
                    .padding(.bottom, 8)

                Divider()

                ForEach(Array(viewModel.habitRhythms.enumerated()), id: \.element.id) { index, rhythm in
                    rhythmRow(rhythm)

                    if index < viewModel.habitRhythms.count - 1 {
                        Divider()
                            .padding(.leading, habitLabelWidth)
                    }
                }
            }
            .padding(16)
            .insightsSurfaceCard(cornerRadius: 20)

            legend
        }
    }

    private var dayHeader: some View {
        HStack(spacing: 6) {
            Text("Habit")
                .font(.caption.weight(.semibold))
                .foregroundStyle(GlowTheme.textSecondary)
                .frame(width: habitLabelWidth, alignment: .leading)

            ForEach(viewModel.days) { day in
                VStack(spacing: 3) {
                    Text(day.date, format: .dateTime.weekday(.narrow))
                        .font(.caption2.weight(day.isToday ? .bold : .regular))

                    Text(day.date, format: .dateTime.day())
                        .font(.caption2.monospacedDigit())
                }
                .foregroundStyle(day.isToday ? GlowTheme.accentPrimary : GlowTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                .accessibilityAddTraits(day.isToday ? .isSelected : [])
            }
        }
    }

    private func rhythmRow(_ rhythm: InsightsViewModel.HabitRhythm) -> some View {
        NavigationLink {
            HabitDetailView(habit: rhythm.habit)
        } label: {
            HStack(spacing: 6) {
                HStack(spacing: 7) {
                    HabitIconSymbol(name: rhythm.habit.iconName, size: 15)
                        .foregroundStyle(rhythm.habit.accentColor)
                        .frame(width: 20)

                    Text(rhythm.habit.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(width: habitLabelWidth, alignment: .leading)

                ForEach(Array(rhythm.dayStates.enumerated()), id: \.offset) { _, state in
                    rhythmMark(state, tint: rhythm.habit.accentColor)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(minHeight: isIPadRegularWidth ? 58 : 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rhythm.accessibilitySummary)
        .accessibilityHint("Opens habit details")
    }

    @ViewBuilder
    private func rhythmMark(_ state: InsightsViewModel.DayState, tint: Color) -> some View {
        ZStack {
            switch state {
            case .completed:
                Circle()
                    .fill(tint)
                    .frame(width: 21, height: 21)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            case .open:
                Circle()
                    .stroke(GlowTheme.borderMuted, lineWidth: 2)
                    .frame(width: 19, height: 19)
            case .bonus:
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: 21, height: 21)
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(tint)
            case .notScheduled:
                Capsule()
                    .fill(GlowTheme.borderMuted.opacity(0.55))
                    .frame(width: 10, height: 2)
            }
        }
        .frame(width: 24, height: 28)
    }

    private var legend: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 112), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            legendItem(title: "Completed", state: .completed)
            legendItem(title: "Open", state: .open)
            legendItem(title: "Bonus", state: .bonus)
            legendItem(title: "Not scheduled", state: .notScheduled)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Legend. Filled checkmark, completed. Ring, scheduled but open. Plus, bonus check-in. Dash, not scheduled.")
    }

    private func legendItem(title: String, state: InsightsViewModel.DayState) -> some View {
        HStack(spacing: 7) {
            rhythmMark(state, tint: GlowTheme.accentPrimary)
                .scaleEffect(0.72)
                .frame(width: 18, height: 18)

            Text(title)
                .font(.caption)
                .foregroundStyle(GlowTheme.textSecondary)
        }
    }

    private var highlightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What stood out")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)

            Group {
                if isIPadRegularWidth {
                    HStack(alignment: .top, spacing: 16) {
                        highlightItems
                    }
                } else {
                    VStack(spacing: 10) {
                        highlightItems
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var highlightItems: some View {
        ForEach(viewModel.highlights) { highlight in
            if let habit = highlight.habit {
                NavigationLink {
                    HabitDetailView(habit: habit)
                } label: {
                    highlightLabel(highlight, tint: habit.accentColor, showsChevron: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens habit details")
                .frame(maxWidth: .infinity)
            } else {
                highlightLabel(highlight, tint: GlowTheme.accentPrimary, showsChevron: false)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var regularWidthHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Since you started", systemImage: "clock.arrow.circlepath")
                .font(.title3.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)

            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    historyMetricCard(
                        title: "Current streak",
                        value: "\(viewModel.globalStreak.current)d",
                        symbol: "flame.fill"
                    )
                    historyMetricCard(
                        title: "Best streak",
                        value: "\(viewModel.globalStreak.best)d",
                        symbol: "trophy.fill"
                    )
                }

                GridRow {
                    historyMetricCard(
                        title: "Check-ins",
                        value: "\(viewModel.lifetimeCompletions)",
                        symbol: "checkmark.circle.fill"
                    )
                    historyMetricCard(
                        title: "Active days",
                        value: "\(viewModel.lifetimeActiveDays)",
                        symbol: "calendar"
                    )
                }
            }
        }
    }

    private func historyMetricCard(title: String, value: String, symbol: String) -> some View {
        historyMetric(title: title, value: value, symbol: symbol)
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .insightsSurfaceCard(cornerRadius: 18)
    }

    private func highlightLabel(
        _ highlight: InsightsViewModel.Highlight,
        tint: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: highlight.kind.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(highlight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)

                Text(highlight.detail)
                    .font(.footnote)
                    .foregroundStyle(GlowTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 6)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlowTheme.textSecondary)
                    .padding(.top, 10)
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: isIPadRegularWidth ? 96 : 68,
            alignment: .leading
        )
        .contentShape(Rectangle())
        .insightsSurfaceCard(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }

    private var historySection: some View {
        DisclosureGroup(isExpanded: $showsHistory) {
            Divider()
                .padding(.vertical, 12)

            Grid(horizontalSpacing: 20, verticalSpacing: 16) {
                GridRow {
                    historyMetric(
                        title: "Current streak",
                        value: "\(viewModel.globalStreak.current)d",
                        symbol: "flame.fill"
                    )
                    historyMetric(
                        title: "Best streak",
                        value: "\(viewModel.globalStreak.best)d",
                        symbol: "trophy.fill"
                    )
                }

                GridRow {
                    historyMetric(
                        title: "Check-ins",
                        value: "\(viewModel.lifetimeCompletions)",
                        symbol: "checkmark.circle.fill"
                    )
                    historyMetric(
                        title: "Active days",
                        value: "\(viewModel.lifetimeActiveDays)",
                        symbol: "calendar"
                    )
                }
            }
        } label: {
            Label("Since you started", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)
        }
        .tint(GlowTheme.accentPrimary)
        .padding(16)
        .insightsSurfaceCard(cornerRadius: 18)
    }

    private func historyMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(GlowTheme.textSecondary)

            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(GlowTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            ContentUnavailableView(
                "Insights start with your first habit",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Add a habit and check in to begin seeing your weekly rhythm.")
            )

            Button {
                showAddHabit = true
            } label: {
                Label("Add your first habit", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 420)
        .padding(24)
    }

    private var comparisonSymbol: String {
        guard let change = viewModel.percentagePointChange else { return "minus" }
        if change > 0 { return "arrow.up.forward" }
        if change < 0 { return "arrow.down.forward" }
        return "equal"
    }

    private var screenBackground: Color {
        isIPadRegularWidth ? Color(uiColor: .systemGroupedBackground) : GlowTheme.bgPrimary
    }

    private func refreshInsights() {
        viewModel.recalc(habits: Array(habits), now: .now)
    }
}

private extension View {
    func insightsSurfaceCard(cornerRadius: CGFloat) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(GlowTheme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 12, y: 4)
    }
}
