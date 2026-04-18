import SwiftUI
import SwiftData
import Combine
import UIKit
import CoreData
import LinkPresentation

// MARK: - HomeView

struct HomeView: View {
    private struct CompletionUndoChange {
        let habitID: String
        let previousCompleted: Bool
        let createdNewLog: Bool
    }

    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var viewModel = HomeViewModel()

    // Add Sheet / New Practice fields
    @State private var listRefreshID = UUID()
    @State private var showAdd = false

    // Edit / Delete state
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?
    @State private var monthCache: [String: MonthHeatmapModel] = [:]

    // Share
    @State private var showShare = false

    // Fires every 30s so we can notice when the day boundary changes.
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    @State private var pendingRefreshTask: Task<Void, Never>?
    @State private var undoAutoDismissTask: Task<Void, Never>?
    @State private var completionUndoChange: CompletionUndoChange?
    @State private var completionUndoMessage = ""
    @State private var showCompletionUndo = false

    private var isIPadRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    private var hasOnlyArchivedHabits: Bool {
        viewModel.activeHabits.isEmpty && !viewModel.archivedHabits.isEmpty
    }

    // MARK: - body

    var body: some View {
        NavigationStack {
            contentList
                .navigationTitle("Today")
                .navigationBarTitleDisplayMode(isIPadRegularWidth ? .inline : .large)
                .glowIPadPageContainer(maxWidth: 860)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            showShare = true
                            GlowTheme.tapHaptic()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share Glow")
                        .accessibilityHint("Opens the system share sheet")

                        Button {
                            showAdd = true
                            GlowTheme.tapHaptic()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add practice")
                        .accessibilityIdentifier("addPracticeButton")
                    }
                }
                .sheet(
                    isPresented: Binding(
                        get: { habitToEdit != nil },
                        set: { if !$0 { habitToEdit = nil } }
                    )
                ) {
                    if let habitToEdit {
                        AddOrEditHabitForm(mode: .edit, habit: habitToEdit)
                            .presentationDetents([.large])
                            .presentationDragIndicator(.visible)
                    }
                }
                .sheet(isPresented: $showAdd) {
                    AddOrEditHabitForm(mode: .add)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
                .confirmationDialog(
                    "Delete practice?",
                    isPresented: Binding(
                        get: { habitToDelete != nil },
                        set: { if !$0 { habitToDelete = nil } }
                    ),
                    presenting: habitToDelete
                ) { h in
                    Button("Delete “\(h.title)”", role: .destructive) {
                        GlowTheme.tapHaptic()
                        Task { await NotificationManager.cancelNotifications(for: h) }
                        context.delete(h)
                        do { try context.save() } catch {
                            print("SwiftData save error:", error)
                        }
                        habitToDelete = nil
                    }
                    Button("Cancel", role: .cancel) { habitToDelete = nil }
                }
        }
        .glowTint()
        .background {
            if isIPadRegularWidth {
                Color(uiColor: .systemGroupedBackground).ignoresSafeArea()
            } else {
                GlowTheme.bgPrimary.ignoresSafeArea()
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showCompletionUndo {
                completionUndoBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(dayTimer) { _ in
            checkForNewDay()
        }
        .onAppear {
            refreshFromHabits()
        }
        .onChange(of: habits) { _, _ in
            scheduleRefresh()
        }
        // Refresh when app returns to foreground (fixes stale lists/state after backgrounding)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let startOfNow = Calendar.current.startOfDay(for: Date())
            viewModel.advanceToToday(startOfNow)
            scheduleRefresh()
        }
        // React to DST/manual time change or midnight rollover while app is running
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            checkForNewDay()
            scheduleRefresh()
        }
        // React to our custom "data changed" signal
        .onReceive(NotificationCenter.default.publisher(for: .glowDataDidChange)) { _ in
            scheduleRefresh(reloadListID: true)
        }
        // React to any SwiftData save (including CloudKit merges)
        .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
            scheduleRefresh(reloadListID: true)
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(message: "")
        }
        .onDisappear {
            undoAutoDismissTask?.cancel()
        }
    }

    // MARK: - Midnight / new-day watcher
    private func checkForNewDay() {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: Date())
        if startOfNow != viewModel.todayStartOfDay {
            viewModel.advanceToToday(startOfNow)
            clearCompletionUndo(animated: false)
        }
    }

    // MARK: - List Content
    private var contentList: some View {
        List {
            Section {
                dailySummaryCard
            }

            if viewModel.activeHabits.isEmpty && viewModel.archivedHabits.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        ContentUnavailableView(
                            "No habits yet",
                            systemImage: "sparkles",
                            description: Text("Start with one small habit for today.")
                        )
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, minHeight: 180)

                        Button {
                            showAdd = true
                            GlowTheme.tapHaptic()
                        } label: {
                            Label("Add your first habit", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                if hasOnlyArchivedHabits {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("All habits are archived", systemImage: "archivebox")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GlowTheme.textPrimary)
                            Text("Unarchive a habit in Library or add a new one to continue today.")
                                .font(.footnote)
                                .foregroundStyle(GlowTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    if viewModel.dueButNotDoneToday.isEmpty {
                        Text("Nothing due right now. You’re caught up.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.dueButNotDoneToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                } header: {
                    GlowSectionHeader("Due Today")
                }

                Section {
                    if viewModel.completedToday.isEmpty {
                        Text("Complete a habit to see it here.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.completedToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                } header: {
                    GlowSectionHeader("Completed Today")
                }

                Section {
                    if viewModel.notDueToday.isEmpty {
                        Text("Upcoming habits will appear as their schedule approaches.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.notDueToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                } header: {
                    GlowSectionHeader("Coming Up")
                }
            }

            // footer spacer
            Section {
                Color.clear
                    .frame(height: 48)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listSectionSeparator(.hidden)
        .glowCoreListRhythm()
        .glowIPadListComposition(top: 4, bottom: 18)
        .id(listRefreshID)
    }

    // MARK: - Row builder
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
        let completed = viewModel.completedTodayHabitIDs.contains(habit.id)

        ZStack {
            // Invisible full-row tap target for navigation (no chevron)
            NavigationLink {
                HabitDetailView(
                    habit: habit,
                    prewarmedMonth: monthCache[habit.id]
                )
            } label: {
                EmptyView()
            }
            .opacity(0)                 // keep hit area, hide visuals
            .accessibilityHidden(true)

            HStack(spacing: 12) {
                Image(systemName: habit.iconName)
                    .foregroundStyle(habit.accentColor)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 3) {
                    Text(habit.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(GlowTheme.textPrimary)

                    Text(todayScheduleSubtitle(for: habit))
                        .font(.caption)
                        .foregroundStyle(GlowTheme.textSecondary)
                }

                Spacer()

                if !isArchived {
                    Button {
                        toggleToday(habit)
                    } label: {
                        Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(completed ? Color.green : GlowTheme.borderMuted)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(completed ? "Mark \(habit.title) not done today" : "Mark \(habit.title) done today")
                }
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleToday(habit)
            } label: {
                Label(completed ? "Undo" : "Complete", systemImage: completed ? "arrow.uturn.backward.circle" : "checkmark.circle")
            }
            .tint(.green)

            Button {
                habitToEdit = habit
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            if isArchived {
                Button {
                    toggleArchive(habit, archived: false)
                } label: {
                    Label("Unarchive", systemImage: "archivebox")
                }
            } else {
                Button {
                    toggleArchive(habit, archived: true)
                } label: {
                    Label("Archive", systemImage: "archivebox.fill")
                }
                .tint(.blue)
            }

            Button(role: .destructive) {
                habitToDelete = habit
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var dailySummaryCard: some View {
        let doneScheduled = viewModel.todayCompletion.done
        let totalScheduled = viewModel.todayCompletion.total
        let percent = totalScheduled == 0
            ? 0
            : Int((Double(doneScheduled) / Double(totalScheduled) * 100).rounded())
        let currentStreak = viewModel.globalStreak.current
        let bestStreak = viewModel.globalStreak.best

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Daily Summary")
                    .font(.headline)
                Spacer()
                Text("\(percent)%")
                    .font(.title3.monospacedDigit().weight(.semibold))
                    .foregroundStyle(GlowTheme.accentPrimary)
            }

            HStack(spacing: 16) {
                Label("\(doneScheduled) done", systemImage: "checkmark.circle.fill")
                Label("\(totalScheduled) due", systemImage: "calendar")
                Label("\(currentStreak)d streak", systemImage: "flame.fill")
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(GlowTheme.textSecondary)

            Text(summarySupportingLine(done: doneScheduled, total: totalScheduled, streak: currentStreak, bestStreak: bestStreak))
                .font(.footnote)
                .foregroundStyle(GlowTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily summary")
        .accessibilityValue("\(doneScheduled) completed, \(totalScheduled) due, \(percent) percent, current streak \(currentStreak) days, best streak \(bestStreak) days")
    }

    private func summarySupportingLine(done: Int, total: Int, streak: Int, bestStreak: Int) -> String {
        if total == 0 {
            return done > 0 ? "Bonus progress captured even without scheduled habits." : "No scheduled habits today."
        }
        if done >= total {
            return "All due habits complete today."
        }
        if streak > 0 {
            return "Current streak: \(streak) day\(streak == 1 ? "" : "s")."
        }
        return bestStreak > 0 ? "Best streak so far: \(bestStreak) days." : "One check-in starts your streak."
    }

    private func todayScheduleSubtitle(for habit: Habit) -> String {
        SchedulePresentation.statusAndSummaryText(
            for: habit.schedule,
            on: viewModel.todayStartOfDay
        )
    }

    private func toggleToday(_ habit: Habit) {
        let cal = Calendar.current
        let today = viewModel.todayStartOfDay

        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if let log = (habit.logs ?? []).first(where: { cal.startOfDay(for: $0.date) == today }) {
                log.completed.toggle()
            } else {
                let log = HabitLog(date: today, completed: true, habit: habit)
                context.insert(log)
            }
        }

        GlowTheme.tapHaptic()
        context.saveSafely()

        // tell the view model to recompute and push to the widget
        viewModel.updateHabits(Array(habits))
    }

    private var completionUndoBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.subheadline)

            Text(completionUndoMessage)
                .font(.subheadline)
                .foregroundStyle(GlowTheme.textPrimary)
                .lineLimit(2)

            Spacer(minLength: 8)

            Button("Undo") {
                undoLastCompletionChange()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(GlowTheme.borderMuted.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(completionUndoMessage). Undo.")
    }

    private func presentCompletionUndo(for habit: Habit, previousCompleted: Bool, createdNewLog: Bool) {
        completionUndoChange = CompletionUndoChange(
            habitID: habit.id,
            previousCompleted: previousCompleted,
            createdNewLog: createdNewLog
        )
        completionUndoMessage = previousCompleted
            ? "\(habit.title) marked not done."
            : "\(habit.title) completed."

        withAnimation(.easeInOut(duration: 0.2)) {
            showCompletionUndo = true
        }

        undoAutoDismissTask?.cancel()
        undoAutoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            clearCompletionUndo(animated: true)
        }
    }

    private func undoLastCompletionChange() {
        guard let change = completionUndoChange else { return }
        guard let habit = habits.first(where: { $0.id == change.habitID }) else {
            clearCompletionUndo(animated: true)
            return
        }

        let cal = Calendar.current
        let today = viewModel.todayStartOfDay
        let existingLog = (habit.logs ?? []).first { cal.startOfDay(for: $0.date) == today }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
            if change.createdNewLog {
                if let existingLog {
                    context.delete(existingLog)
                }
            } else if let existingLog {
                existingLog.completed = change.previousCompleted
            } else if change.previousCompleted {
                let restoredLog = HabitLog(date: today, completed: true, habit: habit)
                context.insert(restoredLog)
            }
        }

        GlowTheme.tapHaptic()
        context.saveSafely()
        viewModel.updateHabits(Array(habits))
        clearCompletionUndo(animated: true)
    }

    private func clearCompletionUndo(animated: Bool) {
        undoAutoDismissTask?.cancel()
        undoAutoDismissTask = nil
        completionUndoChange = nil
        completionUndoMessage = ""

        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCompletionUndo = false
            }
        } else {
            showCompletionUndo = false
        }
    }

    private func toggleArchive(_ habit: Habit, archived: Bool) {
        habit.isArchived = archived
        GlowTheme.tapHaptic()
        do { try context.save() } catch {
            print("SwiftData save error:", error)
        }
        viewModel.updateHabits(Array(habits))
        Task {
            await NotificationManager.syncAfterArchiveStateChange(for: habit)
        }
    }

    private func prewarmMonthCache() {
        let habitsToWarm = viewModel.activeHabits
        let anchor = Date()

        Task(priority: .utility) {
            var built: [String: MonthHeatmapModel] = [:]
            for habit in habitsToWarm {
                // build off-main
                let model = MonthHeatmapModel(habit: habit, month: anchor)
                built[habit.id] = model
            }
            await MainActor.run {
                for (id, model) in built {
                    if monthCache[id] == nil {
                        monthCache[id] = model
                    }
                }
            }
        }
    }
    
    private func scheduleRefresh(reloadListID: Bool = false) {
        // Coalesce rapid-fire triggers to avoid redundant recomputes during transitions.
        pendingRefreshTask?.cancel()
        pendingRefreshTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            refreshFromHabits(reloadListID: reloadListID)
        }
    }

    private func refreshFromHabits(reloadListID: Bool = false) {
        viewModel.updateHabits(habits)
        prewarmMonthCache()
        if reloadListID {
            listRefreshID = UUID()
        }
    }
}

// MARK: - ShareSheet helper
private struct ShareSheet: UIViewControllerRepresentable {
    let message: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let itemSource = GlowShareItemSource(
            message: message,
            appURL: URL(string: "https://apps.apple.com/us/app/glow-daily-practice/id6755254758")!
        )
        return UIActivityViewController(
            activityItems: [itemSource],
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private final class GlowShareItemSource: NSObject, UIActivityItemSource {
    private let message: String
    private let appURL: URL

    init(message: String, appURL: URL) {
        self.message = message
        self.appURL = appURL
    }

    // Placeholder shown while the system prepares the share sheet
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appURL.absoluteString : message
    }

    // Actual shared content: text + link
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            // Just share the App Store link, no leading message text.
            return appURL.absoluteString
        } else {
            return "\(message) \(appURL.absoluteString)"
        }
    }

    // Rich link preview metadata (for Messages, Mail, etc.)
    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Glow Daily Practice"

        // Keep the custom Glow icon as the preview image
        if let image = UIImage(named: "GlowShareIcon") {
            metadata.iconProvider = NSItemProvider(object: image)
        }

        // Do NOT set metadata.url or metadata.originalURL here.
        // The App Store link is still in the shared text, so it stays tappable,
        // but the preview uses our custom icon instead of the remote page preview.
        return metadata
    }
}

extension Notification.Name {
    static let glowDataDidChange = Notification.Name("glowDataDidChange")
}
