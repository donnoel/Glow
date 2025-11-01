import SwiftUI
import SwiftData
import Combine

// MARK: - HomeView

struct HomeView: View {
    @Environment(\.modelContext) private var context
    
    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
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
    
    // Fires every 30s so we can notice when the day boundary changes.
    private let dayTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
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
            .sorted { $0.createdAt > $1.createdAt }
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
    
    // MARK: - body
    
    var body: some View {
        ZStack {
            NavigationStack {
                homeRoot
                    .navigationBarHidden(true)
                    .sheet(isPresented: $showAdd) { addSheet }
                    .sheet(
                        isPresented: Binding(
                            get: { habitToEdit != nil },
                            set: { if !$0 { habitToEdit = nil } }
                        )
                    ) {
                        if let habitToEdit {
                            AddOrEditHabitForm(mode: .edit, habit: habitToEdit)
                        }
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
                // This is the new sheet for Trends
                TrendsView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowTrends)) { _ in
                // Sidebar said "show Trends"
                showTrends = true
            }
            .sheet(isPresented: $showAbout) {
                AboutGlowView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glowShowAbout)) { _ in
                showAbout = true
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
                        .onChange(of: newTitle) { newValue in
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
                        try? context.save()
                        
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
        .presentationDetents([.medium])
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
                    done: todayCompletion.done,
                    total: todayCompletion.total,
                    percent: todayCompletion.percent,
                    bonus: bonusCompletedToday.count,
                    allDone: todayCompletion.done + bonusCompletedToday.count
                )
                .padding(.top, 36) // slightly tighter to status bar (8pt less)
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
                    Section("Completed Today") {
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
                    Section("Due Today") {
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
                    Section("Not Today") {
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
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Row builder (NavigationLink wrapper with our glass row content)
    
    @ViewBuilder
    private func rowCell(habit: Habit, isArchived: Bool) -> some View {
        NavigationLink {
            HabitDetailView(habit: habit)
        } label: {
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
        try? context.save()
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
// Small frosted circle in the top-left to open the sidebar.

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
// (unchanged visuals, still our floating +)

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
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                                radius: 20, y: 10)
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

// Dimmed backdrop + sliding glass drawer

private enum SidebarTab: String {
    case home = "Home"
    case progress = "Trends"
    case settings = "You"
}

// MARK: - SidebarOverlay
// Dimmed backdrop + floating glass drawer (inset, lighter, with streak footer)

private struct SidebarOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: SidebarTab
    let close: () -> Void

    // slide animation state
    @State private var offsetX: CGFloat = -320
    
    @Environment(\.openURL) private var openURL

    private func sendFeedback() {
        // This is where replies will land
        let toAddress = "donnoel@icloud.com"

        // Subject + body with light prefill
        let subject = "Glow Feedback"
        let body = """
    Hi there 👋

    I'd love to share some feedback about Glow:

    """

        // URL encode
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        if let url = URL(string: "mailto:\(toAddress)?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
        }

        // close the sidebar after launching Mail
        closeWithSlideOut()
    }

    // layout tuning
    private var sidebarWidth: CGFloat { 260 }
    private var verticalInset: CGFloat { 40 } // float, not full height

    var body: some View {
        ZStack(alignment: .leading) {
            // Dim behind
            Color.black
                .opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    closeWithSlideOut()
                }

            // Floating glass panel
            VStack(alignment: .leading, spacing: 0) {

                // ===== MAIN NAV =====
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "house.fill",
                        label: "Home",
                        isSelected: selectedTab == .home,
                        colorScheme: colorScheme
                    ) {
                        selectedTab = .home
                        closeWithSlideOut()
                    }

                    SidebarRow(
                        icon: "chart.bar",
                        label: "Trends",
                        isSelected: selectedTab == .progress,
                        colorScheme: colorScheme
                    ) {
                        selectedTab = .progress
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowTrends, object: nil)
                    }

                    SidebarRow(
                        icon: "gearshape.fill",
                        label: "You",
                        isSelected: selectedTab == .settings,
                        colorScheme: colorScheme
                    ) {
                        selectedTab = .settings
                        closeWithSlideOut()
                    }
                }
                .padding(.top, 20)

                // subtle glassy divider
                sidebarDivider

                // ===== SECONDARY NAV =====
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "bell.badge",
                        label: "Reminders",
                        isSelected: false,
                        colorScheme: colorScheme
                    ) {
                        closeWithSlideOut()
                    }

                    SidebarRow(
                        icon: "archivebox.fill",
                        label: "Archived",
                        isSelected: false,
                        colorScheme: colorScheme
                    ) {
                        closeWithSlideOut()
                    }
                }

                // push helper section + streak card to bottom
                Spacer(minLength: 20)

                // another soft divider for the "info / meta" stuff
                sidebarDivider
                    .padding(.bottom, 8)

                // ===== ABOUT / FEEDBACK =====
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "sparkles",
                        label: "About Glow",
                        isSelected: false,
                        colorScheme: colorScheme
                    ) {
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowAbout, object: nil)
                    }
                    
                    SidebarRow(
                        icon: "paperplane.fill",
                        label: "Send Feedback",
                        isSelected: false,
                        colorScheme: colorScheme
                    ) {
                        sendFeedback()
                    }
                }
                .padding(.bottom, 12)

            
            }
            .frame(width: sidebarWidth, alignment: .leading)
            .padding(.vertical, verticalInset)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    // softer frost wash, slightly lighter than before
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.05 : 0.20),
                                Color.white.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    // thinner highlight edge so it's more "float glass", less "card"
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                Color.white
                                    .opacity(colorScheme == .dark ? 0.16 : 0.30),
                                lineWidth: 0.75
                            )
                            .blendMode(.plusLighter)
                    )
                    // deeper drop shadow for lift, but slightly wider + softer
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.7 : 0.15),
                        radius: 40,
                        y: 20
                    )
            )
            .offset(x: offsetX)
        }
        .onAppear {
            // Always default highlight to Home when opening
            selectedTab = .home

            // start off-screen
            offsetX = -sidebarWidth - 40
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offsetX = 0
            }
        }
    }

    // MARK: - tiny helper views

    private var sidebarDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.20 : 0.35),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
    }

    private func closeWithSlideOut() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            offsetX = -sidebarWidth - 40
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            close()
        }
    }
}

// MARK: - GlowChipView
// Small branded pill under the top chrome. Gives Glow identity without yelling.

private struct GlowChipView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GlowTheme.accentPrimary)

            Text("Glow")
                .font(.headline.weight(.semibold))
                .foregroundStyle(
                    colorScheme == .dark
                    ? Color.white
                    : GlowTheme.textPrimary
                )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                // gentle tint wash
                .overlay(
                    GlowTheme.accentPrimary
                        .opacity(colorScheme == .dark ? 0.18 : 0.10)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                        )
                        .blendMode(.plusLighter)
                )
                // edge highlight / glass rim
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            GlowTheme.accentPrimary
                                .opacity(colorScheme == .dark ? 0.45 : 0.3),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                    radius: 20,
                    y: 10
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Glow")
    }
}

// MARK: - StreakCard
// small encouragement chip at the bottom of the drawer

private struct StreakCard: View {
    let colorScheme: ColorScheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(GlowTheme.accentPrimary)

            VStack(alignment: .leading, spacing: 2) {
                Text("You’re on a streak ✨")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        colorScheme == .dark
                        ? Color.white
                        : GlowTheme.textPrimary
                    )

                Text("4 days in a row")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(
                        colorScheme == .dark
                        ? Color.white.opacity(0.7)
                        : GlowTheme.textSecondary
                    )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    GlowTheme.accentPrimary
                        .opacity(colorScheme == .dark ? 0.15 : 0.10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            GlowTheme.accentPrimary
                                .opacity(colorScheme == .dark ? 0.4 : 0.3),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - SidebarRow
// Reusable glassy-ish row inside sidebar.

private struct SidebarRow: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let tap: () -> Void

    private var fgColor: Color {
        if isSelected {
            return GlowTheme.accentPrimary
        } else {
            return colorScheme == .dark
            ? .white
            : GlowTheme.textPrimary
        }
    }

    private var bgCapsule: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        GlowTheme.accentPrimary
                            .opacity(colorScheme == .dark ? 0.22 : 0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                GlowTheme.accentPrimary
                                    .opacity(colorScheme == .dark ? 0.5 : 0.4),
                                lineWidth: 1
                            )
                    )
            } else {
                Color.clear
            }
        }
    }

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(fgColor)

                Text(label)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fgColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(bgCapsule)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}

// MARK: - HabitRowGlass
// (unchanged except we keep the gorgeous tinted glass rows)

private struct HabitRowGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    let habit: Habit
    let toggle: () -> Void

    @State private var tappedBounce = false

    // did user complete this habit today?
    private var doneToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return habit.logs.first(where: { cal.startOfDay(for: $0.date) == today })?.completed == true
    }

    private var rowTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }

    private var iconBubbleColor: Color {
        habit.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.22)
    }

    private var incompleteRingColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.45)
        : GlowTheme.borderMuted.opacity(0.8)
    }

    private var glassCapsule: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.16 : 0.08)
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.28 : 0.18),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.6 : 0.08),
                radius: 20, y: 10
            )
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconBubbleColor)
                    .frame(width: 32, height: 32)

                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.accentColor)
            }

            Text(habit.title)
                .foregroundStyle(rowTextColor)

            Spacer(minLength: 8)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    tappedBounce = true
                }
                GlowTheme.tapHaptic()
                toggle()
            } label: {
                Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(
                        doneToday
                        ? habit.accentColor
                        : incompleteRingColor
                    )
                    .scaleEffect(tappedBounce ? 1.08 : 1.0)
                    .accessibilityLabel(
                        doneToday
                        ? "Mark practice incomplete"
                        : "Mark practice complete"
                    )
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .onChange(of: doneToday) { _ in
                withAnimation(
                    .spring(response: 0.3, dampingFraction: 0.8)
                        .delay(0.05)
                ) {
                    tappedBounce = false
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(glassCapsule)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap for details")
    }
}

// MARK: - HeroCardGlass
// same hero vibe, this is your "Today" card

private struct HeroCardGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    // pulse animation for the percent label
    @State private var pulse = false

    // MARK: inputs
    // done / total drive the ring % math
    // bonus + allDone are just for display ("(+2 bonus)")
    let done: Int        // scheduled completed
    let total: Int       // scheduled total
    let percent: Double  // can be > 1.0 now
    let bonus: Int       // extra unscheduled completions
    let allDone: Int     // done + bonus

    // MARK: derived display text
    // If bonus == 0  → "6 of 6 complete"
    // If bonus  > 0  → "8 of 6 complete (+2 bonus)"
    private var statusLine: String {
        if bonus > 0 {
            return "\(allDone) of \(total) complete (+\(bonus) bonus)"
        } else {
            return "\(done) of \(total) complete"
        }
    }

    // MARK: colors
    private var primaryTextColor: Color {
        switch colorScheme {
        case .light: return GlowTheme.textPrimary
        case .dark:  return .white
        @unknown default: return GlowTheme.textPrimary
        }
    }

    private var secondaryTextColor: Color {
        switch colorScheme {
        case .light: return GlowTheme.textSecondary
        case .dark:  return Color.white.opacity(0.7)
        @unknown default: return GlowTheme.textSecondary
        }
    }

    private var ringTrackColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.18)
        : GlowTheme.borderMuted.opacity(0.45)
    }

    private var ringProgressColor: Color {
        GlowTheme.accentPrimary
    }

    // glass background for the whole card
    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        Color.white
                            .opacity(colorScheme == .dark ? 0.15 : 0.6),
                        lineWidth: colorScheme == .dark ? 0.5 : 1
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.7 : 0.07),
                radius: 24,
                y: 12
            )
    }

    // tiny helper to kick the pulse animation
    private func triggerPulse() {
        pulse = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pulse = false
        }
    }

    // MARK: body
    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // donut
            ZStack {
                Circle()
                    .stroke(ringTrackColor, lineWidth: 14)

                Circle()
                    .trim(from: 0, to: max(0, min(1, percent)))
                    .stroke(
                        ringProgressColor,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: percent)

                Text("\(Int(percent * 100))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(primaryTextColor)
                    .scaleEffect(pulse ? 1.07 : 1.0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.6),
                        value: pulse
                    )
                    // fire whenever percent changes
                    .onChange(of: percent) { newValue in
                        if newValue > 1.0 {
                            triggerPulse()
                        }
                    }
                    // also fire on first appear if already >100%
                    .onAppear {
                        if percent > 1.0 {
                            triggerPulse()
                        }
                    }
            }
            .frame(width: 76, height: 76)

            // right side text block
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)

                Text(statusLine)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(glassCardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today \(done) of \(total) practices complete, \(Int(percent * 100)) percent."
        )
    }
}
// MARK: - SchedulePicker / DayChip / Habit accent helpers

struct SchedulePicker: View {
    @Binding var selection: HabitSchedule

    @State private var isCustom: Bool = false
    @State private var setDays: Set<Weekday> = Set(Weekday.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { !isCustom },
                    set: { newValue in
                        isCustom = !newValue
                        updateSelection()
                    }
                )) {
                    Text("Every day")
                        .foregroundStyle(GlowTheme.textPrimary)
                }
                .toggleStyle(.switch)

                if isCustom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which days?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GlowTheme.textPrimary)

                        HStack(spacing: 8) {
                            ForEach(Weekday.allCases, id: \.self) { day in
                                let active = setDays.contains(day)

                                DayChip(
                                    label: shortLabel(for: day),
                                    active: active
                                ) {
                                    if active {
                                        setDays.remove(day)
                                    } else {
                                        setDays.insert(day)
                                    }
                                    updateSelection()
                                }
                                .accessibilityLabel("Toggle \(fullLabel(for: day))")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GlowTheme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 1)
            )
        }
        .onAppear {
            isCustom = (selection.kind == .custom)
            setDays = selection.days
        }
    }

    private func updateSelection() {
        if isCustom {
            selection = .weekdays(Array(setDays))
        } else {
            selection = .daily
            setDays = Set(Weekday.allCases)
        }
    }

    private func shortLabel(for day: Weekday) -> String {
        switch day {
        case .sun: return "S"
        case .mon: return "M"
        case .tue: return "T"
        case .wed: return "W"
        case .thu: return "Th"
        case .fri: return "F"
        case .sat: return "S"
        }
    }

    private func fullLabel(for day: Weekday) -> String {
        switch day {
        case .sun: return "Sunday"
        case .mon: return "Monday"
        case .tue: return "Tuesday"
        case .wed: return "Wednesday"
        case .thu: return "Thursday"
        case .fri: return "Friday"
        case .sat: return "Saturday"
        }
    }
}

private struct DayChip: View {
    let label: String
    let active: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    active
                    ? GlowTheme.accentPrimary
                    : GlowTheme.textPrimary
                )
                .frame(minWidth: 32, minHeight: 32)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            active
                            ? GlowTheme.accentPrimary.opacity(0.15)
                            : GlowTheme.borderMuted.opacity(0.15)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    active
                                    ? GlowTheme.accentPrimary
                                    : GlowTheme.borderMuted.opacity(0.4),
                                    lineWidth: active ? 2 : 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
        .accessibilityAddTraits(
            active ? [.isSelected] : []
        )
    }
}

// MARK: - Habit accent helper

extension Habit {
    var accentColorName: String {
        switch abs(id.hashValue) % 10 {
        case 0: return "PracticeBlueAccent"
        case 1: return "PracticeGreenAccent"
        case 2: return "PracticePurpleAccent"
        case 3: return "PracticeOrangeAccent"
        case 4: return "PracticePinkAccent"
        case 5: return "PracticeTealAccent"
        case 6: return "PracticeAmberAccent"
        case 7: return "PracticeCoralAccent"
        case 8: return "PracticeLavenderAccent"
        default: return "PracticeMintAccent"
        }
    }

    var accentColor: Color { Color(accentColorName) }
}

extension Notification.Name {
    static let glowShowTrends = Notification.Name("glowShowTrends")
    static let glowShowAbout  = Notification.Name("glowShowAbout")
}

// MARK: - AboutGlowView
// Lightweight "About" sheet. Lives in a card so it feels like Glow voice, not Settings.app.

private struct AboutGlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Fake version for now — you can wire this to Bundle.main later
    private let appVersion = "1.0 (Beta)"

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        Color.white
                            .opacity(colorScheme == .dark ? 0.18 : 0.4),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.7 : 0.12),
                radius: 32,
                y: 20
            )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Glow identity + version
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(GlowTheme.accentPrimary)

                        Text("Glow")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text("Version \(appVersion)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                colorScheme == .dark
                                ? Color.white.opacity(0.6)
                                : GlowTheme.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)

                    // Mission card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why Glow exists")
                            .font(.headline)
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text(
                            "Glow helps you show up for yourself every day. Not with guilt, not with streak anxiety — just gentle momentum.\n\nYou pick the practices that matter. Glow tracks them, celebrates the small wins, and keeps the rhythm going."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)

                    // Privacy card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your data")
                            .font(.headline)
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text(
                            "Your habits are yours. Glow keeps your practices on your device.\n\nWe’re working on optional iCloud sync so you can see them on iPad without creating an account."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)

                    // Credits / contact card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Made with care")
                            .font(.headline)
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text(
                            "Glow is being crafted by a tiny team that really cares about daily habits, mental energy, and showing up.\n\nWe’d love to hear what’s working (and what’s not)."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)

                        Button {
                            if let url = URL(string: "mailto:donnoel@icloud.com?subject=Glow%20Feedback") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Send Feedback")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(GlowTheme.accentPrimary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        GlowTheme.accentPrimary.opacity(
                                            colorScheme == .dark ? 0.18 : 0.12
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send feedback about Glow")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("About Glow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}
