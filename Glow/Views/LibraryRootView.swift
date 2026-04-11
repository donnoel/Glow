import SwiftUI
import SwiftData

struct LibraryRootView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @State private var showAddHabit = false
    @State private var habitToEdit: Habit?
    
    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }
    
    private var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active Habits") {
                    if activeHabits.isEmpty {
                        ContentUnavailableView(
                            "No active habits",
                            systemImage: "checkmark.circle",
                            description: Text("Add a habit to get started.")
                        )
                    } else {
                        ForEach(activeHabits) { habit in
                            habitRow(habit: habit, isArchived: false)
                        }
                    }
                }

                Section("Archived Habits") {
                    if archivedHabits.isEmpty {
                        Text("No archived habits")
                            .foregroundStyle(GlowTheme.textSecondary)
                    } else {
                        ForEach(archivedHabits) { habit in
                            habitRow(habit: habit, isArchived: true)
                        }
                    }
                }

                Section("Reminders") {
                    NavigationLink {
                        RemindersView()
                    } label: {
                        Label("Manage reminders", systemImage: "bell.badge")
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddHabit = true
                    } label: {
                        Label("Add habit", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddHabit) {
                AddOrEditHabitForm(mode: .add)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $habitToEdit) { habit in
                AddOrEditHabitForm(mode: .edit, habit: habit)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func habitRow(habit: Habit, isArchived: Bool) -> some View {
        NavigationLink {
            HabitDetailView(
                habit: habit,
                prewarmedMonth: MonthHeatmapModel(habit: habit, month: Date())
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: habit.iconName)
                    .foregroundStyle(habit.accentColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                    Text(scheduleDisplayLabel(for: habit.schedule))
                        .font(.footnote)
                        .foregroundStyle(GlowTheme.textSecondary)
                }

                Spacer()

                if habit.reminderEnabled {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(GlowTheme.accentPrimary)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                toggleArchive(habit: habit, isArchived: !isArchived)
            } label: {
                Label(isArchived ? "Unarchive" : "Archive", systemImage: isArchived ? "archivebox" : "archivebox.fill")
            }
            .tint(.blue)

            Button {
                habitToEdit = habit
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }
    }

    private func toggleArchive(habit: Habit, isArchived: Bool) {
        habit.isArchived = isArchived
        context.saveSafely()

        Task {
            if isArchived {
                await NotificationManager.cancelNotifications(for: habit)
            } else if habit.reminderEnabled {
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok {
                    await NotificationManager.scheduleNotifications(for: habit)
                }
            }
        }
    }
    
    private func scheduleDisplayLabel(for schedule: HabitSchedule) -> String {
        switch schedule.kind {
        case .daily:
            return "Every day"
        case .custom:
            if schedule.days.isEmpty {
                return "Custom"
            }
            let ordered = Weekday.allCases.filter { schedule.days.contains($0) }
            let names = ordered.map { shortName(for: $0) }
            return names.joined(separator: ", ")
        }
    }
    
    private func shortName(for weekday: Weekday) -> String {
        switch weekday {
        case .sun: return "Sun"
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        }
    }
}
