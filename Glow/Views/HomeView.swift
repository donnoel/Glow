import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newSchedule: HabitSchedule = .daily

    // NEW: track which habit we’re editing
    @State private var habitToEdit: Habit?
    @State private var habitToDelete: Habit?

    private var activeHabits: [Habit] { habits.filter { !$0.isArchived } }

    private var dueToday: [Habit] {
        let today = Date()
        return activeHabits.filter { $0.schedule.isScheduled(on: today) }
    }
    private var notDueToday: [Habit] {
        let today = Date()
        return activeHabits.filter { !$0.schedule.isScheduled(on: today) }
    }

    var body: some View {
        NavigationStack {
            List {
                if activeHabits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "sparkles",
                        description: Text("Tap + to add your first habit")
                    )
                } else {
                    if !dueToday.isEmpty {
                        Section("Due Today") {
                            ForEach(dueToday) { habit in
                                row(for: habit)
                            }
                        }
                    }
                    if !notDueToday.isEmpty {
                        Section("Not Today") {
                            ForEach(notDueToday) { habit in
                                row(for: habit)
                            }
                        }
                    }

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
            .navigationTitle("Glow")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        newTitle = ""
                        newSchedule = .daily
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill").imageScale(.large)
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            // Add sheet (unchanged)
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        Section("Details") {
                            TextField("Title", text: $newTitle)
                                .textInputAutocapitalization(.words)
                        }
                        Section("Schedule") {
                            SchedulePicker(selection: $newSchedule)
                        }
                    }
                    .navigationTitle("New Habit")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showAdd = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !title.isEmpty else { return }
                                context.insert(Habit(title: title, schedule: newSchedule))
                                try? context.save()
                                showAdd = false
                            }
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            // NEW: Edit sheet (presents AddOrEditHabitForm in edit mode)
            .sheet(isPresented: Binding(get: { habitToEdit != nil },
                                        set: { if !$0 { habitToEdit = nil } })) {
                if let habitToEdit {
                    AddOrEditHabitForm(mode: .edit, habit: habitToEdit)
                }
            }
            // Delete confirm (unchanged)
            .confirmationDialog("Delete habit?",
                                isPresented: Binding(get: { habitToDelete != nil },
                                                     set: { if !$0 { habitToDelete = nil } }),
                                presenting: habitToDelete) { h in
                Button("Delete “\(h.title)”", role: .destructive) {
                    context.delete(h)
                    try? context.save()
                    habitToDelete = nil
                }
                Button("Cancel", role: .cancel) { habitToDelete = nil }
            }
        }
    }

    @ViewBuilder
    private func row(for habit: Habit, isArchived: Bool = false) -> some View {
        NavigationLink {
            HabitDetailView(habit: habit)
        } label: {
            HabitRow(habit: habit) { toggleToday(habit) }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // NEW: Edit action
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

    private func toggleToday(_ habit: Habit) {
        let today = Date().startOfDay()
        if let log = habit.logs.first(where: { $0.date == today }) {
            log.completed.toggle()
        } else {
            let log = HabitLog(date: today, completed: true, habit: habit)
            context.insert(log)
        }
        try? context.save()
    }

    private func toggleArchive(_ habit: Habit, archived: Bool) {
        habit.isArchived = archived
        try? context.save()
    }
}

private struct HabitRow: View {
    let habit: Habit
    let toggle: () -> Void

    private var doneToday: Bool {
        let today = Date().startOfDay()
        return habit.logs.first(where: { $0.date == today })?.completed == true
    }

    var body: some View {
        HStack {
            Text(habit.title)
            Spacer()
            Button { toggle() } label: {
                Image(systemName: doneToday ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(doneToday ? Color.accentColor : Color.secondary)
                    .accessibilityLabel(doneToday ? "Mark incomplete" : "Mark complete")
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
        }
    }
}

// Compact, non-wrapping weekday picker used in Add sheet
private struct SchedulePicker: View {
    @Binding var selection: HabitSchedule
    @State private var isCustom: Bool = false
    @State private var setDays: Set<Weekday> = Set(Weekday.allCases)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Every day", isOn: Binding(
                get: { !isCustom },
                set: { isCustom = !$0; update() }
            ))
            if isCustom {
                HStack {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        let active = setDays.contains(day)
                        Button(compactLabel(for: day)) {
                            if active { setDays.remove(day) } else { setDays.insert(day) }
                            update()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(active ? .accentColor : .secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(minWidth: 28) // keeps "Th" from wrapping
                        .accessibilityLabel("Toggle \(fullLabel(for: day))")
                    }
                }
            }
        }
        .onAppear {
            isCustom = selection.kind == .custom
            setDays = selection.days
        }
    }

    private func compactLabel(for day: Weekday) -> String {
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
    private func update() {
        selection = isCustom ? .weekdays(Array(setDays)) : .daily
    }
}
