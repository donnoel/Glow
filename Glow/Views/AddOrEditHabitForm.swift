import SwiftUI
import SwiftData

/// Shared form for adding or editing a Habit.
/// Usage:
/// - Add:  AddOrEditHabitForm(mode: .add)
/// - Edit: AddOrEditHabitForm(mode: .edit, habit: someHabit)
struct AddOrEditHabitForm: View {
    enum Mode { case add, edit }

    let mode: Mode
    let habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var schedule: HabitSchedule
    @State private var isArchived: Bool

    init(mode: Mode, habit: Habit? = nil) {
        self.mode = mode
        self.habit = habit
        // Seed local state from the model (for edit) or sensible defaults (for add)
        _title = State(initialValue: habit?.title ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)
        _isArchived = State(initialValue: habit?.isArchived ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                }
                Section("Schedule") {
                    LocalSchedulePicker(selection: $schedule)
                }
                if mode == .edit {
                    Section {
                        Toggle("Archived", isOn: $isArchived)
                    }
                }
            }
            .navigationTitle(mode == .add ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .add ? "Save" : "Done") {
                        handleSave()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func handleSave() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let newHabit = Habit(title: trimmed, schedule: schedule)
            context.insert(newHabit)

        case .edit:
            guard let habit else { return }
            habit.title = trimmed
            habit.schedule = schedule
            habit.isArchived = isArchived
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Compact Weekday Picker (local to this file to avoid type collisions)
private struct LocalSchedulePicker: View {
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
