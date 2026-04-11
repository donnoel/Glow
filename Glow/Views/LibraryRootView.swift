import SwiftUI
import SwiftData

struct LibraryRootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Query(sort: [
        SortDescriptor(\Habit.sortOrder, order: .forward),
        SortDescriptor(\Habit.createdAt, order: .reverse)
    ])
    private var habits: [Habit]

    @State private var showAddHabit = false
    @State private var habitToEdit: Habit?

    private var isIPadRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private var activeHabits: [Habit] {
        habits.filter { !$0.isArchived }
    }
    
    private var archivedHabits: [Habit] {
        habits.filter { $0.isArchived }
    }

    private var activeReminderCount: Int {
        activeHabits.filter {
            $0.reminderEnabled
                && $0.reminderHour != nil
                && $0.reminderMinute != nil
        }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if activeHabits.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "No active habits",
                                systemImage: "checkmark.circle",
                                description: Text("Add one habit to get your daily loop started.")
                            )
                            .frame(maxWidth: .infinity, minHeight: 150)

                            Button {
                                showAddHabit = true
                            } label: {
                                Label("Add your first habit", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(activeHabits) { habit in
                            habitRow(habit: habit, isArchived: false)
                        }
                    }
                } header: {
                    GlowSectionHeader("Active Habits")
                }

                Section {
                    if archivedHabits.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("No archived habits yet", systemImage: "archivebox")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(GlowTheme.textPrimary)
                            Text("Archived habits will appear here when you want to pause one.")
                                .font(.footnote)
                                .foregroundStyle(GlowTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(archivedHabits) { habit in
                            habitRow(habit: habit, isArchived: true)
                        }
                    }
                } header: {
                    GlowSectionHeader("Archived Habits")
                }

                Section {
                    NavigationLink {
                        RemindersView()
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Label("Manage reminders", systemImage: "bell.badge")
                            Text(
                                activeReminderCount == 0
                                    ? "No reminders turned on yet."
                                    : "\(activeReminderCount) active reminder\(activeReminderCount == 1 ? "" : "s")"
                            )
                            .font(.footnote)
                            .foregroundStyle(GlowTheme.textSecondary)
                        }
                    }
                } header: {
                    GlowSectionHeader("Reminders")
                }
            }
            .glowCoreListRhythm()
            .navigationTitle("Library")
            .navigationBarTitleDisplayMode(isIPadRegularWidth ? .inline : .large)
            .glowIPadPageContainer(maxWidth: 860)
            .glowIPadListComposition(top: 4, bottom: 18)
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
                    Text(scheduleSubtitle(for: habit, isArchived: isArchived))
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
            await NotificationManager.syncAfterArchiveStateChange(for: habit)
        }
    }
    
    private func scheduleSubtitle(for habit: Habit, isArchived: Bool) -> String {
        SchedulePresentation.statusAndSummaryText(
            for: habit.schedule,
            isArchived: isArchived
        )
    }
}
