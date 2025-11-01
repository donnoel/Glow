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
    @State private var timerCancellable: AnyCancellable?

    // Bottom dock selection (Home / Stats / Settings)
    @State private var selectedDockTab: DockTab = .home

    // MARK: - Derived Collections

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    // All habits scheduled today
    private var scheduledTodayHabits: [Habit] {
        let today = Date()
        return activeHabits
            .filter { $0.schedule.isScheduled(on: today) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Completed today
    private var completedToday: [Habit] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        return scheduledTodayHabits.filter { habit in
            habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }

    // Due today but not done
    private var dueButNotDoneToday: [Habit] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        return scheduledTodayHabits.filter { habit in
            !habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }

    // Not scheduled today
    private var notDueToday: [Habit] {
        let today = Date()
        return activeHabits
            .filter { !$0.schedule.isScheduled(on: today) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }

    // Hero numbers
    private var todayCompletion: (done: Int, total: Int, percent: Double) {
        let total = scheduledTodayHabits.count
        let done = completedToday.count
        let pct = total == 0 ? 0.0 : Double(done) / Double(total)
        return (done, total, pct)
    }

    // MARK: - body

    var body: some View {
        NavigationStack {
            contentList
                .navigationTitle("Glow")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
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
                }
                // Add
                .sheet(isPresented: $showAdd) {
                    addSheet
                }
                // Edit
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
                // Delete confirm
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
        .onAppear { startMidnightWatcher() }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        // frosted-tinted app background (yours)
        .glowTint()
        .glowScreenBackground()
        // floating dock sitting over content
        .safeAreaInset(edge: .bottom) {
            GlowDock(selected: $selectedDockTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
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
                            // live icon guess
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

                        // give new practice a sortOrder after the current max
                        let maxOrder = (habits.map { $0.sortOrder }.max() ?? 9_998)
                        let newOrder = maxOrder + 1

                        // pull hour/minute from the chosen reminder time
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newReminderTime)
                        let hour = comps.hour
                        let minute = comps.minute

                        // build the Habit model
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

                        // if reminders are on, request permission + schedule now
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

    private func startMidnightWatcher() {
        guard timerCancellable == nil else { return }

        let cal = Calendar.current
        timerCancellable = Timer
            .publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let startOfNow = cal.startOfDay(for: Date())
                if startOfNow != todayAnchor {
                    todayAnchor = startOfNow
                }
            }
    }

    // MARK: - List Content

    private var contentList: some View {
        List {
            // HERO
            Section {
                HeroCardGlass(
                    done: todayCompletion.done,
                    total: todayCompletion.total,
                    percent: todayCompletion.percent
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 16, trailing: 16))
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
                // Completed Today
                if !completedToday.isEmpty {
                    Section("Completed Today") {
                        ForEach(completedToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                }

                // Due Today
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

                // Not Today
                if !notDueToday.isEmpty {
                    Section("Not Today") {
                        ForEach(notDueToday) { habit in
                            rowCell(habit: habit, isArchived: false)
                        }
                    }
                }

                // Archived
                if !archivedHabits.isEmpty {
                    Section("Archived") {
                        ForEach(archivedHabits) { habit in
                            rowCell(habit: habit, isArchived: true)
                        }
                    }
                }
            }
            // bottom spacer so last row clears the floating dock
            Section {
                Color.clear
                    .frame(height: 120) // should be >= dock height
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
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
        let today = cal.startOfDay(for: Date())

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

// MARK: - NavAddButton

private struct NavAddButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .imageScale(.large)
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

// MARK: - HabitRowGlass
// A single practice row rendered as a frosted capsule with habit tint.

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

    // Text ink
    private var rowTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }

    // tiny colored chip bg behind SF Symbol
    private var iconBubbleColor: Color {
        habit.accentColor.opacity(colorScheme == .dark ? 0.32 : 0.22)
    }

    // ring color for incomplete circle
    private var incompleteRingColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.45)
        : GlowTheme.borderMuted.opacity(0.8)
    }

    // frosted capsule behind row content
    private var glassCapsule: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial) // base blur
            .overlay(
                // whisper of habit tint across the glass
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        habit.accentColor
                            .opacity(colorScheme == .dark ? 0.16 : 0.08)
                    )
                    .blendMode(.plusLighter)
            )
            .overlay(
                // hairline stroke that picks up the tint
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
            // icon chip
            ZStack {
                Circle()
                    .fill(iconBubbleColor)
                    .frame(width: 32, height: 32)

                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(habit.accentColor)
            }

            // title
            Text(habit.title)
                .foregroundStyle(rowTextColor)

            Spacer(minLength: 8)

            // completion toggle
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

            // chevron is provided by NavigationLink cell style automatically
            // so we don't draw another arrow here
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(glassCapsule)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        // higher hit target for a11y
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap for details")
    }
}

// MARK: - HeroCardGlass
// Frosted summary card with ring progress.
// Sits at the top of the list and sets the visual language.

private struct HeroCardGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    let done: Int
    let total: Int
    let percent: Double

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
        // use the app accent for the hero (keeps brand cohesion)
        GlowTheme.accentPrimary
    }

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
                radius: 24, y: 12
            )
    }

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
            }
            .frame(width: 76, height: 76)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)

                Text("\(done) of \(total) complete")
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

// MARK: - GlowDock
// Floating iOS-style home-screen dock bar.
// (Visual only for now — feels like “Glow is an OS for your habits”.)

private enum DockTab: String {
    case home
    case stats
    case settings
}

private struct GlowDock: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selected: DockTab

    private var dockBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        Color.white
                            .opacity(colorScheme == .dark ? 0.12 : 0.3),
                        lineWidth: 0.5
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.05),
                radius: 20, y: 8
            )
    }

    var body: some View {
        HStack(spacing: 28) {
            DockButton(
                icon: "house.fill",
                label: "Home",
                isSelected: selected == .home
            ) { selected = .home }

            DockButton(
                icon: "chart.bar",
                label: "Stats",
                isSelected: selected == .stats
            ) { selected = .stats }

            DockButton(
                icon: "gearshape.fill",
                label: "Settings",
                isSelected: selected == .settings
            ) { selected = .settings }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(dockBackground)
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }
}

// MARK: - DockButton

private struct DockButton: View {
    @Environment(\.colorScheme) private var colorScheme

    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    private var fgColor: Color {
        if isSelected {
            return GlowTheme.accentPrimary
        } else {
            return colorScheme == .dark
            ? .white.opacity(0.8)
            : GlowTheme.textPrimary
        }
    }

    private var capsuleBG: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        GlowTheme.accentPrimary
                            .opacity(colorScheme == .dark ? 0.22 : 0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                GlowTheme.accentPrimary
                                    .opacity(colorScheme == .dark ? 0.4 : 0.3),
                                lineWidth: 1
                            )
                    )
            } else {
                Color.clear
            }
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(fgColor)

                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(fgColor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(capsuleBG)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
    /// Deterministically assigns a color from our practice palette
    /// so each practice keeps its same tint forever.
    var accentColorName: String {
        switch abs(id.hashValue) % 5 {
        case 0: return "PracticeBlueAccent"
        case 1: return "PracticeGreenAccent"
        case 2: return "PracticePurpleAccent"
        case 3: return "PracticeOrangeAccent"
        default: return "PracticePinkAccent"
        }
    }

    var accentColor: Color {
        Color(accentColorName)
    }
}
