import SwiftUI
import SwiftData
import Combine

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var context
    
    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]
    
    // Add Sheet / New Practice fields
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
    
    // Day rollover watcher
    @State private var todayAnchor: Date = Calendar.current.startOfDay(for: Date())
    
    // Sidebar
    @State private var showSidebar = false
    @State private var selectedTab: SidebarTab = .home
    @State private var showTrends = false
    @State private var showAbout = false
    @State private var showYou = false
    
    // Fires every 30s so we can notice when the day boundary changes.
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    @State private var highlightTodayCard = false
    @State private var lastPercent: Double = 0.0
    
    // MARK: - Derived Collections
    
    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }
    
    // All habits scheduled today
    private var scheduledTodayHabits: [Habit] {
        activeHabits
            .filter { $0.schedule.isScheduled(on: todayStartOfDay) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }
    
    // Completed today
    private var completedToday: [Habit] {
        let cal = Calendar.current
        let todayStart = todayStartOfDay
        
        return scheduledTodayHabits.filter { habit in
            habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }
    
    // Due today but not done
    private var dueButNotDoneToday: [Habit] {
        let cal = Calendar.current
        let todayStart = todayStartOfDay
        
        return scheduledTodayHabits.filter { habit in
            !habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }
    
    // Not scheduled today
    private var notDueToday: [Habit] {
        activeHabits
            .filter { !$0.schedule.isScheduled(on: todayStartOfDay) }
            .sorted { $0.sortOrder < $1.sortOrder  }
    }
    
    // Completed today even though they were NOT scheduled today.
    // This is your "bonus work" that should count toward >100%.
    private var bonusCompletedToday: [Habit] {
        let cal = Calendar.current
        let todayStart = todayStartOfDay

        return notDueToday.filter { habit in
            habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }
    
    
    private var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }
    
    // Hero numbers
    private var todayCompletion: (done: Int, total: Int, percent: Double) {
        let totalScheduled = scheduledTodayHabits.count          // how many you "owe" today
        let doneScheduled = completedToday.count                 // how many of those you actually did
        let bonus = bonusCompletedToday.count                    // extra wins not scheduled today

        // percent can go above 1.0 now because we include bonus
        let percentValue: Double
        if totalScheduled == 0 {
            // Edge case: nothing was scheduled today.
            // If you still did stuff anyway, that should count as >100%.
            // So if you did 2 bonus habits on a "rest" day, that's 200%.
            percentValue = bonus == 0 ? 0.0 : Double(bonus)
        } else {
            percentValue = Double(doneScheduled + bonus) / Double(totalScheduled)
        }

        return (
            done: doneScheduled,
            total: totalScheduled,
            percent: percentValue
        )
    }
    
    
    // This is "today" for the whole screen. When this changes, the UI should refresh.
    private var todayStartOfDay: Date {
        todayAnchor
    }
    // MARK: - "You" summaries feeding YouView

    /// All logs, flattened from all habits.
    private var allLogs: [HabitLog] {
        habits.flatMap { $0.logs }
    }

    /// Current streak and best streak *across all habits*.
    /// We treat a "day counts" if you completed ANY habit that day.
    private var globalStreak: (current: Int, best: Int) {
        let cal = Calendar.current

        // collect all UNIQUE days where you completed something
        let groupedByDay = Dictionary(grouping: allLogs.filter { $0.completed }) {
            cal.startOfDay(for: $0.date)
        }

        // Turn those days into fake HabitLogs so we can reuse StreakEngine
        let synthetic: [HabitLog] = groupedByDay.keys.map { day in
            HabitLog(date: day, completed: true, habit: Habit.placeholder)
        }

        return StreakEngine.computeStreaks(logs: synthetic)
    }

    /// Which habit is "most consistent" in the last 14 days?
    /// We'll look at each habit and count how many distinct days it was completed.
    private var mostConsistentHabit: (title: String, hits: Int, window: Int) {
        let cal = Calendar.current
        let windowDays = 14
        let windowStart = cal.startOfDay(
            for: cal.date(byAdding: .day, value: -windowDays + 1, to: Date())!
        )

        var bestTitle: String = "—"
        var bestHits = 0

        for h in habits {
            // unique days this habit was done in that window
            let daysHit = Set(
                h.logs
                    .filter { $0.completed && $0.date >= windowStart }
                    .map { cal.startOfDay(for: $0.date) }
            )

            if daysHit.count > bestHits {
                bestHits = daysHit.count
                bestTitle = h.title
            }
        }

        return (title: bestTitle, hits: bestHits, window: windowDays)
    }

    /// Rough guess of "when you usually check in":
    /// We'll average all active reminder times, fallback to ~8pm.
    private var typicalCheckInTime: Date {
        let times: [Date] = activeHabits.compactMap { h in
            guard let hour = h.reminderHour,
                  let minute = h.reminderMinute else {
                return nil
            }
            return Calendar.current.date(
                bySettingHour: hour,
                minute: minute,
                second: 0,
                of: Date()
            )
        }

        // Fallback if you have no reminders set anywhere
        guard !times.isEmpty else {
            return Calendar.current.date(
                bySettingHour: 20,
                minute: 0,
                second: 0,
                of: Date()
            ) ?? Date()
        }

        // Average the minutes after midnight (so 9:30am = 570 mins, etc)
        let cal = Calendar.current
        let minutesArray = times.map { t in
            let comps = cal.dateComponents([.hour, .minute], from: t)
            return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        }

        let avgMins = minutesArray.reduce(0, +) / minutesArray.count
        let avgHour = avgMins / 60
        let avgMinute = avgMins % 60

        return cal.date(
            bySettingHour: avgHour,
            minute: avgMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
    
    
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

            // 👇👇 ADD THESE TWO HERE, still chained to the NavigationStack 👇👇

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
                    currentStreak: globalStreak.current,
                    bestStreak: globalStreak.best,
                    favoriteTitle: mostConsistentHabit.title,
                    favoriteHits: mostConsistentHabit.hits,
                    favoriteWindow: mostConsistentHabit.window,
                    checkInTime: typicalCheckInTime
                )
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowYou)) { _ in
                showYou = true
            }

            // 👆👆 END OF NEW BIT 👆👆

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
                        Spacer()
                        NavAddButton {
                            // reset form state when + is tapped
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = Habit.guessIconName(for: newTitle)
                            
                            newReminderEnabled = false
                            newReminderTime = HomeView.defaultReminderTime()
                            
                            showAdd = true
                        }
                        .accessibilityLabel("Add practice")
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
                        .textInputAutocapitalization(.words)
                        .onChange(of: newTitle) { _, newValue in
                            let guess = Habit.guessIconName(for: newValue)
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
                            ? Habit.guessIconName(for: trimmed)
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
                    .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Midnight / new-day watcher
    /// Called periodically to see if the calendar day rolled over.
    /// If it did, we update `todayAnchor`, which triggers the view to recompute.
    private func checkForNewDay() {
        let cal = Calendar.current
        let startOfNow = cal.startOfDay(for: Date())
        if startOfNow != todayAnchor {
            todayAnchor = startOfNow
        }
    }
    
    // MARK: - List Content
    
    private var contentList: some View {
        List {
            // HERO
            Section {
                // Add some top padding here so the hero visually sits just under
                // that floating chrome instead of jammed into the status bar.
                HeroCardGlass(
                    highlightTodayCard: $highlightTodayCard,
                    lastPercent: $lastPercent,
                    done: todayCompletion.done,
                    total: todayCompletion.total,
                    percent: todayCompletion.percent,
                    bonus: bonusCompletedToday.count,
                    allDone: todayCompletion.done + bonusCompletedToday.count
                )
                .padding(.top, 64) // sits lower, avoids overlap with chrome
                .listRowInsets(
                    EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            
            if activeHabits.isEmpty && archivedHabits.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No practices yet",
                        systemImage: "sparkles",
                        description: Text("Tap + to add your first practice")
                    )
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                if !completedToday.isEmpty {
                    Section("Your Wins Today") {
                        ForEach(completedToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: completedToday
                            )
                        }
                    }
                }
                
                if !dueButNotDoneToday.isEmpty {
                    Section("Practice For Today") {
                        ForEach(dueButNotDoneToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: dueButNotDoneToday
                            )
                        }
                    }
                }
                
                if !notDueToday.isEmpty {
                    Section("On The Horizon") {
                        ForEach(notDueToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: notDueToday
                            )
                        }
                    }
                }
                
                if !archivedHabits.isEmpty {
                    Section("Archived") {
                        ForEach(archivedHabits) { habit in
                            rowCell(habit: habit, isArchived: true)
                        }
                        .onMove { indices, newOffset in
                            handleMove(
                                indices: indices,
                                newOffset: newOffset,
                                sourceArray: archivedHabits
                            )
                        }
                    }
                }
            }
            
            // comfy bottom spacer so last row never slams into bottom edge
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
    }
    
    // MARK: - Row builder (NavigationLink wrapper with our glass row content)
    
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
        ZStack {
            NavigationLink {
                HabitDetailView(habit: habit)
            } label: {
                EmptyView()
            }
            .opacity(0)
            .accessibilityHidden(true)

            HabitRowGlass(habit: habit) {
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
    
    // MARK: - Reorder handler
    
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
    
    // MARK: - Actions
    
    private func toggleToday(_ habit: Habit) {
        let cal = Calendar.current
        let today = todayStartOfDay
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            if let log = habit.logs.first(where: { cal.startOfDay(for: $0.date) == today }) {
                log.completed.toggle()
            } else {
                let log = HabitLog(date: today, completed: true, habit: habit)
                context.insert(log)
            }
        }
        
        GlowTheme.tapHaptic()
        context.saveSafely()
    }
    
    private func toggleArchive(_ habit: Habit, archived: Bool) {
        habit.isArchived = archived
        do { try context.save() } catch {
            print("SwiftData save error:", error)
        }
        
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
    
    // MARK: - Helpers
    
    /// Default reminder time when creating a new practice (8:00 PM local).
    private static func defaultReminderTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        if let eightPM = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            return eightPM
        }
        return now
    }
}


// MARK: - SidebarHandleButton
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
    }
}

// MARK: - NavAddButton
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
    }

    private var navIconColor: Color {
        switch colorScheme {
        case .light: return GlowTheme.textPrimary
        case .dark:  return GlowTheme.accentPrimary
        @unknown default: return GlowTheme.accentPrimary
        }
    }
}
