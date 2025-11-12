import SwiftUI
import SwiftData
import Combine
import UIKit
import CoreData   // ⬅️ to observe saves

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
    @AppStorage("hasSeenGlowOnboarding") private var hasSeenGlowOnboarding = false
    @State private var showOnboarding = false

    // Add Sheet / New Practice fields
    @State private var listRefreshID = UUID()
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newSchedule: HabitSchedule = .daily
    @State private var newIconName: String = "checkmark.circle"

    // 🔔 Reminder fields for creation
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
                viewModel.updateHabits(habits)
                prewarmMonthCache()
            }
            .onChange(of: habits) { _, newHabits in
                viewModel.updateHabits(newHabits)
                prewarmMonthCache()
            }
            // Refresh when app returns to foreground (fixes stale lists/state after backgrounding)
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                let startOfNow = Calendar.current.startOfDay(for: Date())
                viewModel.advanceToToday(startOfNow)
                viewModel.updateHabits(habits)
                prewarmMonthCache()
            }
            // React to DST/manual time change or midnight rollover while app is running
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                checkForNewDay()
                viewModel.updateHabits(habits)
            }
            // React to our custom "data changed" signal
            .onReceive(NotificationCenter.default.publisher(for: .glowDataDidChange)) { _ in
                DispatchQueue.main.async {
                    viewModel.updateHabits(habits)
                    prewarmMonthCache()
                    listRefreshID = UUID()
                }
            }
            // ✅ New: react to *any* SwiftData/Core Data save anywhere
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                DispatchQueue.main.async {
                    viewModel.updateHabits(habits)
                    prewarmMonthCache()
                    listRefreshID = UUID()
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
                    checkInTime: viewModel.typicalCheckInTime
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
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showSidebar = false
                        }
                    }
                )
                .transition(.identity)
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(activityItems: ["I’m tracking my practices in Glow ✨"])
        }
        .fullScreenCover(isPresented: $showOnboarding, onDismiss: {
            hasSeenGlowOnboarding = true
        }) {
            GlowOnboardingView(isPresented: $showOnboarding)
        }
        .onAppear {
            if hasSeenGlowOnboarding == false {
                showOnboarding = true
            }
        }
    }

    // MARK: - Home Root View with Chrome Overlay
    private var homeRoot: some View {
        contentList
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        SidebarHandleButton {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showSidebar = true
                            }
                            GlowTheme.tapHaptic()
                        }
                        .accessibilityIdentifier("menuButton") // ✅ UITest stable id

                        Spacer()

                        NavShareButton {
                            showShare = true
                        }

                        NavAddButton {
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = HabitIconLibrary.guessIcon(for: newTitle)

                            newReminderEnabled = false
                            newReminderTime = HomeView.defaultReminderTime()

                            showAdd = true
                        }
                        .accessibilityLabel("Add practice")
                        .accessibilityIdentifier("addPracticeButton") // ✅ UITest stable id
                    }
                    .padding(.horizontal, 16)
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
                        .accessibilityIdentifier("practiceTitleField") // ✅ UITest stable id
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
                    }
                    .accessibilityIdentifier("savePracticeButton") // ✅ UITest stable id
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
                let canShowBonus = viewModel.isTodayComplete

                HeroCardGlass(
                    highlightTodayCard: $highlightTodayCard,
                    lastPercent: $lastPercent,
                    done: viewModel.todayCompletion.done,
                    total: viewModel.todayCompletion.total,
                    percent: viewModel.todayCompletion.percent,
                    bonus: canShowBonus ? viewModel.bonusCompletedToday.count : 0,
                    allDone: viewModel.todayCompletion.done
                        + (canShowBonus ? viewModel.bonusCompletedToday.count : 0)
                )
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Today’s progress")
                .accessibilityValue("\(viewModel.todayCompletion.done) of \(viewModel.todayCompletion.total) practices completed")
                .padding(.top, GlowTheme.Spacing.xlarge * 2)
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
    }

    // MARK: - Row builder
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
        ZStack {
            NavigationLink {
                HabitDetailView(
                    habit: habit,
                    prewarmedMonth: monthCache[habit.id]
                )
            } label: {
                EmptyView()
            }
            .opacity(0)
            .accessibilityHidden(true)

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
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension Notification.Name {
    static let glowShowArchive = Notification.Name("glowShowArchive")
    static let glowShowReminders = Notification.Name("glowShowReminders")
    static let glowDataDidChange = Notification.Name("glowDataDidChange")
}
