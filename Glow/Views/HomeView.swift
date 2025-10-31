import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    // Add Sheet / New Habit fields
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newSchedule: HabitSchedule = .daily
    @State private var newIconName: String = "checkmark.circle"

    // Edit / Delete state
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?

    // Reorder mode for "Due Today"
    @State private var isEditingOrder = false

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
                    ToolbarItem(placement: .topBarLeading) {
                        // "Edit" / "Done" to control reordering mode
                        if !scheduledTodayHabits.isEmpty {
                            Button(isEditingOrder ? "Done" : "Edit") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingOrder.toggle()
                                }
                            }
                            .accessibilityLabel(isEditingOrder ? "Stop Reordering" : "Reorder habits")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        NavAddButton {
                            // reset form state
                            newTitle = ""
                            newSchedule = .daily
                            newIconName = Habit.guessIconName(for: newTitle)
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
        .glowTint()
        .glowScreenBackground()
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
                        ForEach(dueButNotDoneToday) { habit in
                            row(for: habit)
                        }
                        // Reorder only when we're in edit mode
                        .onMove { indices, newOffset in
                            handleMove(indices: indices,
                                       newOffset: newOffset,
                                       sourceArray: dueButNotDoneToday)
                        }
                        .environment(\.editMode,
                                     .constant(isEditingOrder ? .active : .inactive))
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

                        let h = Habit(
                            title: trimmed,
                            schedule: newSchedule,
                            iconName: newIconName.isEmpty
                                ? Habit.guessIconName(for: trimmed)
                                : newIconName,
                            sortOrder: newOrder
                        )

                        context.insert(h)
                        try? context.save()
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
    let habit: Habit
    let toggle: () -> Void

    @State private var tappedBounce: Bool = false

    private var doneToday: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return habit.logs.first(where: { cal.startOfDay(for: $0.date) == today })?.completed == true
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge
            ZStack {
                Circle()
                    .fill(GlowTheme.borderMuted.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: habit.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(GlowTheme.textPrimary)
            }

            // Title
            Text(habit.title)
                .foregroundStyle(GlowTheme.textPrimary)

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
                        ? GlowTheme.accentPrimary
                        : GlowTheme.borderMuted.opacity(0.8)
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
        .listRowBackground(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 2, y: 1)
        )
    }
}

// MARK: - HeroCard

private struct HeroCard: View {
    let done: Int
    let total: Int
    let percent: Double

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // Progress ring
            ZStack {
                Circle()
                    .stroke(GlowTheme.borderMuted.opacity(0.4), lineWidth: 12)

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
                    .foregroundStyle(GlowTheme.textPrimary)
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.headline)
                    .foregroundStyle(GlowTheme.textPrimary)

                Text("\(done) of \(total) complete")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(GlowTheme.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 3, y: 2)
        )
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
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Every day", isOn: Binding(
                get: { !isCustom },
                set: { isCustom = !$0; updateSelection() }
            ))

            if isCustom {
                HStack {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let active = setDays.contains(day)

                        Button(dayShortLabel(day)) {
                            if active {
                                setDays.remove(day)
                            } else {
                                setDays.insert(day)
                            }
                            updateSelection()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(
                            active
                            ? GlowTheme.accentPrimary
                            : GlowTheme.borderMuted.opacity(0.6)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 28)
                        .accessibilityLabel("Toggle \(dayFullLabel(day))")
                    }
                }
            }
        }
        .onAppear {
            isCustom = selection.kind == .custom
            setDays = selection.days
        }
    }

    private func updateSelection() {
        selection = isCustom ? .weekdays(Array(setDays)) : .daily
    }

    private func dayShortLabel(_ day: Weekday) -> String {
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

    private func dayFullLabel(_ day: Weekday) -> String {
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
