import SwiftUI
import SwiftData
import Combine

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    // Add Sheet / New Habit fields
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newSchedule: HabitSchedule = .daily
    @State private var newIconName: String = "checkmark.circle"

    // 🔔 New reminder fields for creation
    @State private var newReminderEnabled = false
    @State private var newReminderTime: Date = HomeView.defaultReminderTime()

    // Edit / Delete state
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?

    // MARK: - Day rollover support
    // We remember "today at midnight" and we update it if the day changes.
    @State private var todayAnchor: Date = Calendar.current.startOfDay(for: Date())
    @State private var timerCancellable: AnyCancellable?

    // MARK: - Derived Collections

    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }

    // All habits that are *scheduled today*
    private var scheduledTodayHabits: [Habit] {
        let today = Date()
        return activeHabits
            .filter { $0.schedule.isScheduled(on: today) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    // Subset: completed today
    private var completedToday: [Habit] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        return scheduledTodayHabits.filter { habit in
            habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }

    // Subset: due today but not done
    private var dueButNotDoneToday: [Habit] {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        return scheduledTodayHabits.filter { habit in
            !habit.logs.contains { log in
                cal.startOfDay(for: log.date) == todayStart && log.completed
            }
        }
    }

    // Habits NOT on today's schedule
    private var notDueToday: [Habit] {
        let today = Date()
        return activeHabits
            .filter { !$0.schedule.isScheduled(on: today) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // hero card numbers
    private var todayCompletion: (done: Int, total: Int, percent: Double) {
        let total = scheduledTodayHabits.count
        let done = completedToday.count
        let pct = total == 0 ? 0.0 : Double(done) / Double(total)
        return (done, total, pct)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            contentList
                .navigationTitle("Glow")
                .toolbar {
                    // NOTE: We removed the .topBarLeading Edit/Done button.
                    ToolbarItem(placement: .topBarTrailing) {
                        NavAddButton {
                            // reset form state when + is tapped
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = Habit.guessIconName(for: newTitle)

                            // reset reminder state
                            newReminderEnabled = false
                            newReminderTime = HomeView.defaultReminderTime()

                            showAdd = true
                        }
                    }
                }
                // ADD SHEET
                .sheet(isPresented: $showAdd) {
                    addSheet
                }
                // EDIT SHEET
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
                // DELETE CONFIRM
                .confirmationDialog(
                    "Delete habit?",
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
                    Button("Cancel", role: .cancel) {
                        habitToDelete = nil
                    }
                }
        }
        .onAppear {
            startMidnightWatcher()
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .glowTint()
        .glowScreenBackground()
    }

    // MARK: - Midnight / new-day watcher

    /// Sets up a 60s heartbeat. If calendar day rolled over,
    /// update `todayAnchor`, which invalidates all the computed views.
    private func startMidnightWatcher() {
        // Avoid double-registering if view appears again
        if timerCancellable != nil { return }

        let cal = Calendar.current

        timerCancellable = Timer
            .publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                let startOfNow = cal.startOfDay(for: Date())
                if startOfNow != todayAnchor {
                    // Day changed (past midnight)
                    todayAnchor = startOfNow
                }
            }
    }

    // MARK: - List content

    private var contentList: some View {
        List {
            heroSection

            if activeHabits.isEmpty {
                ContentUnavailableView(
                    "No habits yet",
                    systemImage: "sparkles",
                    description: Text("Tap + to add your first habit")
                )
            } else {
                // Completed Today
                if !completedToday.isEmpty {
                    Section("Completed Today") {
                        ForEach(completedToday) { habit in
                            row(for: habit)
                                .disabled(false) // we still let you tap detail if you want
                        }
                    }
                }

                // Due Today (not yet done)
                if !dueButNotDoneToday.isEmpty {
                    Section("Due Today") {
                        // Reorderable list of habits due today
                        ForEach(dueButNotDoneToday) { habit in
                            row(for: habit)
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
                            row(for: habit)
                        }
                    }
                }

                // Archived
                let archived = habits.filter { $0.isArchived }
                if !archived.isEmpty {
                    Section("Archived") {
                        ForEach(archived) { habit in
                            row(for: habit, isArchived: true)
                        }
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        Section {
            HeroCard(
                done: todayCompletion.done,
                total: todayCompletion.total,
                percent: todayCompletion.percent
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    // MARK: - Add Habit sheet

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

                // 🔔 NEW: Reminder setup at creation
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
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showAdd = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }

                        // give new habit a sortOrder after the current max
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

    // MARK: - Row builder

    @ViewBuilder
    private func row(for habit: Habit, isArchived: Bool = false) -> some View {
        NavigationLink {
            HabitDetailView(habit: habit)
        } label: {
            HabitRow(habit: habit) {
                toggleToday(habit)
            }
        }
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

    /// Handles dragging rows in "Due Today".
    /// We:
    /// 1. Build a mutable copy of dueButNotDoneToday
    /// 2. Apply the move
    /// 3. Write each habit.sortOrder = its index
    /// 4. Save
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

    /// Default reminder time when creating a new habit (8:00 PM local).
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
                .accessibilityLabel("Add habit")
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

// MARK: - HabitRow

private struct HabitRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let habit: Habit
    let toggle: () -> Void

    @State private var tappedBounce: Bool = false

    private var doneToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return habit.logs.first(where: { cal.startOfDay(for: $0.date) == today })?.completed == true
    }

    // text/icon color for the row
    private var rowTextColor: Color {
        colorScheme == .dark ? Color.white : GlowTheme.textPrimary
    }

    // background for the row tile
    private var rowBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
            }
        }
    }

    // circle behind the habit icon
    private var iconBubbleColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.12)
        } else {
            return GlowTheme.borderMuted.opacity(0.15)
        }
    }

    // ring color for the checkmark circle when it's NOT done yet
    private var incompleteRingColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.4)
        } else {
            return GlowTheme.borderMuted.opacity(0.8)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(iconBubbleColor)
                    .frame(width: 32, height: 32)

                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(rowTextColor)
            }

            // Title
            Text(habit.title)
                .foregroundStyle(rowTextColor)

            Spacer()

            // Complete toggle
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
                        ? GlowTheme.accentPrimary // this pops on both light & dark
                        : incompleteRingColor
                    )
                    .scaleEffect(tappedBounce ? 1.08 : 1.0)
                    .accessibilityLabel(doneToday ? "Mark incomplete" : "Mark complete")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .onChange(of: doneToday) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8).delay(0.05)) {
                    tappedBounce = false
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(rowBackground)
    }
}

// MARK: - HeroCard

private struct HeroCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let done: Int
    let total: Int
    let percent: Double

    // Text colors that guarantee contrast on the card background
    private var primaryTextColor: Color {
        switch colorScheme {
        case .light: return GlowTheme.textPrimary          // dark ink
        case .dark:  return Color.white                    // pure white on dark card
        @unknown default: return GlowTheme.textPrimary
        }
    }

    private var secondaryTextColor: Color {
        switch colorScheme {
        case .light: return GlowTheme.textSecondary        // secondary ink
        case .dark:  return Color.white.opacity(0.7)       // dimmed white
        @unknown default: return GlowTheme.textSecondary
        }
    }

    // Card background (light vs dark)
    private var cardBackground: some View {
        Group {
            if colorScheme == .dark {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.8), radius: 20, y: 10)
            } else {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.04), radius: 3, y: 2)
            }
        }
    }

    // Ring track color in the progress donut
    private var ringTrackColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.15)
        : GlowTheme.borderMuted.opacity(0.4)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // Progress ring
            ZStack {
                Circle()
                    .stroke(ringTrackColor, lineWidth: 12)

                Circle()
                    .trim(from: 0, to: max(0, min(1, percent)))
                    .stroke(
                        GlowTheme.accentPrimary,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: percent)

                Text("\(Int(percent * 100))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(primaryTextColor)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)

                Text("\(done) of \(total) complete")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(secondaryTextColor)
            }

            Spacer()
        }
        .padding(16)
        .background(cardBackground)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today \(done) of \(total) habits complete, \(Int(percent * 100)) percent.")
    }
}

// MARK: - SchedulePicker

private struct SchedulePicker: View {
    @Binding var selection: HabitSchedule

    @State private var isCustom: Bool = false
    @State private var setDays: Set<Weekday> = Set(Weekday.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Card wrapper for the schedule controls
            VStack(alignment: .leading, spacing: 12) {
                // Top row: toggle between "Every day" vs custom days
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

                // Custom days row
                if isCustom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Which days?")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(GlowTheme.textPrimary)

                        // 7 evenly-sized chips in a row
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
            // reflect incoming binding -> local UI state
            isCustom = (selection.kind == .custom)
            setDays = selection.days
        }
    }

    // Push local edits (isCustom + setDays) back into the binding
    private func updateSelection() {
        if isCustom {
            selection = .weekdays(Array(setDays))
        } else {
            selection = .daily
            // keep local mirror in sync so if they flip back to custom
            // we don't accidentally lose previous custom picks
            setDays = Set(Weekday.allCases)
        }
    }

    // MARK: - Labels

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

// MARK: - DayChip

/// One little rounded chip for a weekday toggle.
/// Active = accent glow, inactive = subtle surface.
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
