import SwiftUI
import SwiftData
import Combine
import UIKit
import CoreData
import LinkPresentation

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @StateObject private var viewModel = HomeViewModel()

    // Add Sheet / New Practice fields
    @State private var listRefreshID = UUID()
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newSchedule: HabitSchedule = .daily
    @State private var newIconName: String = "checkmark.circle"

    // Reminder fields for creation
    @State private var newReminderEnabled = false
    @State private var newReminderTime: Date = HomeView.defaultReminderTime()

    // Edit / Delete state
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?
    @State private var monthCache: [String: MonthHeatmapModel] = [:]

    // Share
    @State private var showShare = false

    // Fires every 30s so we can notice when the day boundary changes.
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    @State private var pendingRefreshTask: Task<Void, Never>?

    // MARK: - body

    var body: some View {
        NavigationStack {
            contentList
                .navigationTitle("Today")
                .navigationBarTitleDisplayMode(.large)
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
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = HabitIconLibrary.guessIcon(for: newTitle)

                            newReminderEnabled = false
                            newReminderTime = HomeView.defaultReminderTime()

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
                    addSheet
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
        .glowScreenBackground()
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
    }

    // MARK: - Add Practice sheet
    private var addSheet: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $newTitle)
                        .accessibilityIdentifier("practiceTitleField") // UITest stable id
                        .textInputAutocapitalization(.words)
                        .onChange(of: newTitle) { _, newValue in
                            guard newValue.count > 2 else { return }
                            let guess = HabitIconLibrary.guessIcon(for: newValue)
                            if newIconName == "checkmark.circle" || newIconName.isEmpty {
                                newIconName = guess
                            }
                        }
                }

                Section("Schedule") {
                    SchedulePicker(selection: $newSchedule)
                }

                Section("Icon") {
                    IconPickerRow(selection: $newIconName)
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $newReminderEnabled)

                    if newReminderEnabled {
                        DatePicker(
                            "Time",
                            selection: $newReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .accessibilityLabel("Reminder time")
                    }
                }
            }
            .navigationTitle("New Practice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        let maxOrder = (habits.map { $0.sortOrder }.max() ?? 9_998)
                        let newOrder = maxOrder + 1

                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newReminderTime)
                        let hour = comps.hour
                        let minute = comps.minute

                        let h = Habit(
                            title: trimmed,
                            createdAt: .now,
                            isArchived: false,
                            schedule: newSchedule,
                            reminderEnabled: newReminderEnabled,
                            reminderHour: hour,
                            reminderMinute: minute,
                            iconName: newIconName.isEmpty
                                ? HabitIconLibrary.guessIcon(for: trimmed)
                                : newIconName,
                            sortOrder: newOrder
                        )

                        context.insert(h)
                        context.saveSafely()

                        if newReminderEnabled {
                            Task {
                                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                                if ok {
                                    await NotificationManager.scheduleNotifications(for: h)
                                }
                            }
                        }

                        showAdd = false
                        GlowTheme.tapHaptic()
                    }
                    .accessibilityIdentifier("savePracticeButton") // UITest stable id
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Midnight / new-day watcher
    private func checkForNewDay() {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: Date())
        if startOfNow != viewModel.todayStartOfDay {
            viewModel.advanceToToday(startOfNow)
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
                    ContentUnavailableView(
                        "No practices yet",
                        systemImage: "sparkles",
                        description: Text("Tap + to add your first practice")
                    )
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section("Due Today") {
                    if viewModel.dueButNotDoneToday.isEmpty {
                        Text("Nothing due right now.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.dueButNotDoneToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                }

                Section("Completed Today") {
                    if viewModel.completedToday.isEmpty {
                        Text("No completed habits yet.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.completedToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                }

                Section("Coming Up") {
                    if viewModel.notDueToday.isEmpty {
                        Text("No upcoming habits.")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(viewModel.notDueToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
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
        .listSectionSpacing(.compact)
        .listStyle(.insetGrouped)
        .id(listRefreshID)
    }

    // MARK: - Row builder
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
        let completed = isCompletedToday(habit)

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

                    Text(habit.schedule.isScheduled(on: viewModel.todayStartOfDay) ? "Due today" : "Not due today")
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
        let bonus = viewModel.bonusCompletedToday.count
        let completedCount = doneScheduled + bonus
        let percent = totalScheduled == 0
            ? (bonus > 0 ? 100 : 0)
            : Int((Double(completedCount) / Double(totalScheduled) * 100).rounded())
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
                Label("\(completedCount) done", systemImage: "checkmark.circle.fill")
                Label("\(totalScheduled) due", systemImage: "calendar")
                Label("\(currentStreak)d streak", systemImage: "flame.fill")
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(GlowTheme.textSecondary)

            Text(summarySupportingLine(done: completedCount, total: totalScheduled, streak: currentStreak, bestStreak: bestStreak))
                .font(.footnote)
                .foregroundStyle(GlowTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily summary")
        .accessibilityValue("\(completedCount) completed, \(totalScheduled) due, \(percent) percent, current streak \(currentStreak) days, best streak \(bestStreak) days")
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

    private func isCompletedToday(_ habit: Habit) -> Bool {
        let cal = Calendar.current
        let today = viewModel.todayStartOfDay
        return (habit.logs ?? []).contains { log in
            cal.startOfDay(for: log.date) == today && log.completed
        }
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

    private func toggleArchive(_ habit: Habit, archived: Bool) {
        habit.isArchived = archived
        GlowTheme.tapHaptic()
        do { try context.save() } catch {
            print("SwiftData save error:", error)
        }
        viewModel.updateHabits(Array(habits))
        Task {
            if archived {
                await NotificationManager.cancelNotifications(for: habit)
            } else if habit.reminderEnabled {
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok {
                    await NotificationManager.scheduleNotifications(for: habit)
                }
            }
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
    // MARK: - Static helpers
    private static func defaultReminderTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        if let eightPM = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            return eightPM
        }
        return now
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
