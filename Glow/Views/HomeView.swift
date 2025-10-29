import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context

    // Read directly from SwiftData; sort only (no filters/macros)
    @Query(sort: [SortDescriptor(\Habit.createdAt, order: .reverse)])
    private var habits: [Habit]

    @State private var showAdd = false
    @State private var newTitle = ""

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "sparkles",
                        description: Text("Tap + to add your first habit")
                    )
                } else {
                    ForEach(habits) { habit in
                        NavigationLink {
                            HabitDetailView(habit: habit)
                        } label: {
                            HabitRow(habit: habit) {
                                toggleToday(habit)
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
                        showAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill").imageScale(.large)
                    }
                    .accessibilityLabel("Add habit")
                }
            }
            .sheet(isPresented: $showAdd) {
                NavigationStack {
                    Form {
                        Section("Details") {
                            TextField("Title", text: $newTitle)
                                .textInputAutocapitalization(.words)
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
                                context.insert(Habit(title: title))
                                try? context.save()
                                showAdd = false
                            }
                            .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Toggle logic (no predicates)
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
}

// Simple row with trailing check button
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
            Button {
                toggle()
            } label: {
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
