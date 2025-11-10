import SwiftUI
import SwiftData

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // only archived habits
    @Query(
        filter: #Predicate<Habit> { $0.isArchived == true },
        sort: [SortDescriptor(\Habit.title, order: .forward)]
    )
    private var archivedHabits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                if archivedHabits.isEmpty {
                    ContentUnavailableView(
                        "No archived practices",
                        systemImage: "archivebox",
                        description: Text("Practices you archive will show up here.")
                    )
                } else {
                    ForEach(archivedHabits) { habit in
                        HStack {
                            HabitRowGlass(habit: habit) {
                                // no toggle from archive
                            }
                            .disabled(true)

                            Button {
                                unarchive(habit)
                            } label: {
                                Image(systemName: "arrow.uturn.left.circle.fill")
                                    .imageScale(.large)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GlowTheme.bgSurface.ignoresSafeArea())
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func unarchive(_ habit: Habit) {
        habit.isArchived = false
        do {
            try context.save()
        } catch {
            print("Unarchive save error:", error)
        }
    }
}
