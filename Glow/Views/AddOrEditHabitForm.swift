import SwiftUI
import SwiftData

struct AddOrEditHabitForm: View {
    enum Mode { case add, edit }

    let mode: Mode
    let habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var title: String
    @State private var schedule: HabitSchedule
    @State private var isArchived: Bool

    // M7: reminders
    @State private var remindMe: Bool
    @State private var reminderTime: Date

    init(mode: Mode, habit: Habit? = nil) {
        self.mode = mode
        self.habit = habit

        _title = State(initialValue: habit?.title ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)
        _isArchived = State(initialValue: habit?.isArchived ?? false)

        let cal = Calendar.current
        let defaultTime: Date = cal.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        _remindMe = State(initialValue: habit?.reminderEnabled ?? false)
        if let h = habit, let comps = h.reminderTimeComponents,
           let date = cal.date(from: comps) {
            _reminderTime = State(initialValue: date)
        } else {
            _reminderTime = State(initialValue: defaultTime)
        }
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
                Section("Reminder") {
                    Toggle("Remind me", isOn: $remindMe)
                    if remindMe {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
                if mode == .edit {
                    Section { Toggle("Archived", isOn: $isArchived) }
                }
            }
            .navigationTitle(mode == .add ? "New Habit" : "Edit Habit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .add ? "Save" : "Done") { Task { await handleSave() } }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func applyReminderFields(to habit: Habit) {
        habit.reminderEnabled = remindMe
        if remindMe {
            habit.setReminderTime(from: reminderTime)
        } else {
            habit.reminderHour = nil
            habit.reminderMinute = nil
        }
    }

    private func saveAndDismiss() {
        try? context.save()
        dismiss()
    }

    private func handleSave() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let newHabit = Habit(title: trimmed, schedule: schedule)
            context.insert(newHabit)
            // write reminders after insert to ensure an id exists
            applyReminderFields(to: newHabit)
            try? context.save()

            if newHabit.reminderEnabled {
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok { await NotificationManager.scheduleNotifications(for: newHabit) }
            }

        case .edit:
            guard let habit else { return }
            habit.title = trimmed
            habit.schedule = schedule
            habit.isArchived = isArchived

            let wasEnabled = habit.reminderEnabled
            applyReminderFields(to: habit)
            try? context.save()

            if habit.isArchived {
                await NotificationManager.cancelNotifications(for: habit)
            } else if habit.reminderEnabled {
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok { await NotificationManager.scheduleNotifications(for: habit) }
            } else if wasEnabled && !habit.reminderEnabled {
                await NotificationManager.cancelNotifications(for: habit)
            }
        }

        dismiss()
    }
}

// === Local compact weekday picker (unchanged API) ===
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
                        .frame(minWidth: 28)
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
