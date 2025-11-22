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

    // Sidebar
    @State private var showSidebar = false
    @State private var selectedTab: SidebarTab = .home
    @State private var showTrends = false
    @State private var showAbout = false
    @State private var showYou = false
    @State private var showArchive = false
    @State private var showReminders = false

    // Fires every 30s so we can notice when the day boundary changes.
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    @State private var highlightTodayCard = false
    @State private var lastPercent: Double = 0.0

    // MARK: - body

    var body: some View {
        ZStack {
            NavigationStack {
                homeRoot
                    .navigationBarHidden(true)
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
                refreshFromHabits()
            }
            // Refresh when app returns to foreground (fixes stale lists/state after backgrounding)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let startOfNow = Calendar.current.startOfDay(for: Date())
                viewModel.advanceToToday(startOfNow)
                refreshFromHabits()
            }
            // React to DST/manual time change or midnight rollover while app is running
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                checkForNewDay()
                refreshFromHabits()
            }
            // React to our custom "data changed" signal
            .onReceive(NotificationCenter.default.publisher(for: .glowDataDidChange)) { _ in
                DispatchQueue.main.async {
                    refreshFromHabits(reloadListID: true)
                }
            }
            // React to any SwiftData save (including CloudKit merges)
            .onReceive(NotificationCenter.default.publisher(for: ModelContext.didSave)) { _ in
                DispatchQueue.main.async {
                    refreshFromHabits(reloadListID: true)
                }
            }

            // extra sheets
            .sheet(isPresented: $showTrends) {
                TrendsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowTrends)) { _ in
                showTrends = true
            }
            .sheet(isPresented: $showAbout) {
                AboutGlowView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowAbout)) { _ in
                showAbout = true
            }
            .sheet(isPresented: $showYou) {
                YouView(
                    currentStreak: viewModel.globalStreak.current,
                    bestStreak: viewModel.globalStreak.best,
                    favoriteTitle: viewModel.mostConsistentHabit.title,
                    favoriteHits: viewModel.mostConsistentHabit.hits,
                    favoriteWindow: viewModel.mostConsistentHabit.window,
                    checkInTime: viewModel.typicalCheckInTime,
                    recentActiveDays: viewModel.recentActiveDays,
                    lifetimeActiveDays: viewModel.lifetimeActiveDays,
                    lifetimeCompletions: viewModel.lifetimeCompletions
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowYou)) { _ in
                showYou = true
            }
            .sheet(isPresented: $showArchive) {
                ArchiveView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowArchive)) { _ in
                showArchive = true
            }
            .sheet(isPresented: $showReminders) {
                RemindersView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowReminders)) { _ in
                showReminders = true
            }

            if showSidebar {
                SidebarOverlay(
                    selectedTab: $selectedTab,
                    close: {
                        showSidebar = false   // overlay slides/fades, *then* we remove it
                    }
                )
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(message: "")
        }
    }

    // MARK: - Home Root View with Chrome Overlay
    private var homeRoot: some View {
        contentList
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SidebarHandleButton {
                            showSidebar = true     // let SidebarOverlay animate itself
                            GlowTheme.tapHaptic()
                        }
                        .accessibilityIdentifier("menuButton") // UITest stable id

                        Spacer()

                        NavShareButton {
                            showShare = true
                            GlowTheme.tapHaptic()
                        }

                        NavAddButton {
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = HabitIconLibrary.guessIcon(for: newTitle)

                            newReminderEnabled = false
                            newReminderTime = HomeView.defaultReminderTime()

                            showAdd = true
                            GlowTheme.tapHaptic()
                        }
                        .accessibilityLabel("Add practice")
                        .accessibilityIdentifier("addPracticeButton") // UITest stable id
                    }
                    .padding(.horizontal, chromeHorizontalPadding)
                    .padding(.top, 48)
                    Spacer()
                }
                .ignoresSafeArea()
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
            // HERO
            Section {
                HeroCardGlass(
                    highlightTodayCard: $highlightTodayCard,
                    lastPercent: $lastPercent,
                    done: viewModel.todayCompletion.done,
                    total: viewModel.todayCompletion.total,
                    percent: viewModel.todayCompletion.percent,
                    bonus: viewModel.bonusCompletedToday.count,
                    allDone: viewModel.todayCompletion.done + viewModel.bonusCompletedToday.count
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today’s progress")
                .accessibilityValue("\(viewModel.todayCompletion.done) of \(viewModel.todayCompletion.total) practices completed")
                .padding(.top, heroTopPadding)
                .listRowInsets(
                    EdgeInsets(
                        top: GlowTheme.Spacing.small,
                        leading: GlowTheme.Spacing.medium,
                        bottom: GlowTheme.Spacing.medium,
                        trailing: GlowTheme.Spacing.medium
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
                if !viewModel.completedToday.isEmpty {
                    Section("Today’s Wins") {
                        ForEach(viewModel.completedToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: viewModel.completedToday
                            )
                        }
                    }
                }

                if !viewModel.dueButNotDoneToday.isEmpty {
                    Section("Today’s Focus") {
                        ForEach(viewModel.dueButNotDoneToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: viewModel.dueButNotDoneToday
                            )
                        }
                    }
                }

                if !viewModel.notDueToday.isEmpty {
                    Section("Coming Up") {
                        ForEach(viewModel.notDueToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: viewModel.notDueToday
                            )
                        }
                    }
                }

                if !viewModel.archivedHabits.isEmpty {
                    Section("Archived") {
                        ForEach(viewModel.archivedHabits) { habit in
                            rowCell(habit: habit, isArchived: true)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: viewModel.archivedHabits
                            )
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
        .listSectionSpacing(.custom(10))
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .id(listRefreshID)
        .padding(.horizontal, contentHorizontalInset)
    }

    // MARK: - Row builder
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
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
            .accessibilityHidden(true)  // let HabitRowGlass handle VoiceOver

            // Our custom glass row UI
            HabitRowGlass(habit: habit, isArchived: isArchived) {
                toggleToday(habit)
            }
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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

    // MARK: - Row helpers
    private func handleMove(indices: IndexSet, newOffset: Int, sourceArray: [Habit]) {
        var working = sourceArray
        working.move(fromOffsets: indices, toOffset: newOffset)

        for (idx, habit) in working.enumerated() {
            habit.sortOrder = idx
        }

        do {
            try context.save()
        } catch {
            print("Reorder save error:", error)
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
    
    private func refreshFromHabits(reloadListID: Bool = false) {
        viewModel.updateHabits(habits)
        prewarmMonthCache()
        if reloadListID {
            listRefreshID = UUID()
        }
    }


    // MARK: - Layout helpers
    /// Extra top padding for the hero card.
    /// On iPad (regular width) we nudge it down a bit so it doesn’t crowd the nav chrome.
    private var heroTopPadding: CGFloat {
        horizontalSizeClass == .regular
        ? GlowTheme.Spacing.xlarge * 3.5
        : GlowTheme.Spacing.xlarge * 2
    }
    /// Horizontal inset for the main content column.
    /// On iPad (regular width) we match the Details screen with a ~1-inch gutter.
    /// On iPhone we leave it at 0 so the existing layout is unchanged.
    private var contentHorizontalInset: CGFloat {
        horizontalSizeClass == .regular ? 96 : 0
    }

    /// Horizontal padding for the nav chrome overlay.
    /// On iPad this aligns the buttons with the main content column.
    /// On iPhone we keep the original 16pt padding.
    private var chromeHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 96 : 16
    }

    // MARK: - Sidebar buttons (unchanged except identifiers)
    private struct SidebarHandleButton: View {
        @Environment(\.colorScheme) private var colorScheme
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(
                        colorScheme == .dark
                        ? GlowTheme.accentPrimary
                        : GlowTheme.textPrimary
                    )
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                                radius: 20, y: 10
                            )
                    )
            }
            .accessibilityLabel("Menu")
            .accessibilityHint("Opens Glow navigation")
        }
    }

    private struct NavAddButton: View {
        @Environment(\.colorScheme) private var colorScheme
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundStyle(navIconColor)
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                                radius: 20, y: 10
                            )
                    )
            }
            .accessibilityLabel("Add practice")
        }

        private var navIconColor: Color {
            switch colorScheme {
            case .light: return GlowTheme.textPrimary
            case .dark:  return GlowTheme.accentPrimary
            @unknown default: return GlowTheme.accentPrimary
            }
        }
    }

    private struct NavShareButton: View {
        @Environment(\.colorScheme) private var colorScheme
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Image(systemName: "square.and.arrow.up.circle")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(
                        colorScheme == .dark
                        ? GlowTheme.accentPrimary.opacity(0.75)
                        : GlowTheme.textSecondary
                    )
                    .padding(10)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .shadow(
                                color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                                radius: 20, y: 10
                            )
                    )
            }
            .accessibilityLabel("Share Glow")
            .accessibilityHint("Opens the system share sheet")
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
    static let glowShowArchive = Notification.Name("glowShowArchive")
    static let glowShowReminders = Notification.Name("glowShowReminders")
    static let glowDataDidChange = Notification.Name("glowDataDidChange")
}
