import SwiftUI
import SwiftData

struct AddOrEditHabitForm: View {
    enum Mode { case add, edit }

    let mode: Mode
    let habit: Habit?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // MARK: - Form State

    @State private var title: String
    @State private var schedule: HabitSchedule
    @State private var isArchived: Bool

    @State private var iconName: String

    // Reminder state
    @State private var remindMe: Bool
    @State private var reminderTime: Date

    // MARK: - Init

    init(mode: Mode, habit: Habit? = nil) {
        self.mode = mode
        self.habit = habit

        // Title / schedule / archive
        _title = State(initialValue: habit?.title ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)
        _isArchived = State(initialValue: habit?.isArchived ?? false)

        // Icon guess / existing icon
        let initialIcon = habit?.iconName
            ?? Habit.guessIconName(for: habit?.title ?? "")
        _iconName = State(initialValue: initialIcon)

        // Reminder toggle + time
        let cal = Calendar.current
        let defaultTime = AddOrEditHabitForm.defaultReminderTime()
        let habitHasReminder = habit?.reminderEnabled ?? false

        _remindMe = State(initialValue: habitHasReminder)

        if let h = habit,
           let comps = h.reminderTimeComponents,
           let dateFromHabit = cal.date(from: comps) {
            _reminderTime = State(initialValue: dateFromHabit)
        } else {
            _reminderTime = State(initialValue: defaultTime)
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // DETAILS
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .onChange(of: title) { newValue in
                            guard mode == .add else { return }

                            // Predict an icon from the updated title
                            let freshGuess = Habit.guessIconName(for: newValue)

                            // Only auto-update if we think the user hasn't manually chosen an icon.
                            let userHasNotCustomizedIcon =
                                iconName == "checkmark.circle" ||
                                iconName == Habit.guessIconName(for: "") ||
                                iconName == Habit.guessIconName(for: title) ||
                                iconName == Habit.guessIconName(for: newValue)

                            if userHasNotCustomizedIcon {
                                iconName = freshGuess
                            }
                        }
                }

                // SCHEDULE
                Section("Schedule") {
                    // Match creation UI
                    SchedulePicker(selection: $schedule)
                }

                // ICON
                Section("Icon") {
                    IconPickerRow(selection: $iconName)
                }

                // REMINDER
                Section("Reminder") {
                    Toggle("Remind me", isOn: $remindMe)

                    if remindMe {
                        DatePicker(
                            "Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .accessibilityLabel("Reminder time")
                    }
                }

                // ARCHIVE (edit only)
                if mode == .edit {
                    Section {
                        Toggle("Archived", isOn: $isArchived)
                    }
                }
            }
            .navigationTitle(mode == .add ? "New Practice" : "Edit Practice")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(mode == .add ? "Save" : "Done") {
                        Task { await handleSave() }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .glowTint()
        .glowScreenBackground()
        .presentationDetents([.medium])
    }

    // MARK: - Save / Helpers

    /// Copy reminder-related fields into the Habit model.
    private func applyReminderFields(to habit: Habit) {
        habit.reminderEnabled = remindMe
        if remindMe {
            habit.setReminderTime(from: reminderTime)
        } else {
            habit.reminderHour = nil
            habit.reminderMinute = nil
        }
    }

    /// Compute the next sortOrder so new practices show at the bottom.
    private func nextSortOrder() -> Int {
        let descriptor = FetchDescriptor<Habit>()
        let allHabits = (try? context.fetch(descriptor)) ?? []
        let maxOrder = (allHabits.map { $0.sortOrder }.max() ?? 9_998)
        return maxOrder + 1
    }

    private func handleSave() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {

        case .add:
            // Build a brand new Habit using our form state
            let sortOrder = nextSortOrder()

            let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let hour = comps.hour
            let minute = comps.minute

            let newHabit = Habit(
                title: trimmed,
                createdAt: .now,
                isArchived: false,
                schedule: schedule,
                reminderEnabled: remindMe,
                reminderHour: hour,
                reminderMinute: minute,
                iconName: iconName.isEmpty
                    ? Habit.guessIconName(for: trimmed)
                    : iconName,
                sortOrder: sortOrder
            )

            context.insert(newHabit)
            try? context.save()

            // Schedule notifications for a brand new practice
            if remindMe {
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok {
                    await NotificationManager.scheduleNotifications(for: newHabit)
                }
            }

        case .edit:
            guard let habit else { break }

            // Update existing Habit with new values
            habit.title = trimmed
            habit.schedule = schedule
            habit.isArchived = isArchived
            habit.iconName = iconName.isEmpty
                ? Habit.guessIconName(for: trimmed)
                : iconName

            let wasEnabled = habit.reminderEnabled
            applyReminderFields(to: habit)

            try? context.save()

            // Handle notifications depending on new state
            if habit.isArchived {
                // Turn off if archived
                await NotificationManager.cancelNotifications(for: habit)
            } else if habit.reminderEnabled {
                // Active + reminders ON
                let ok = await NotificationManager.requestAuthorizationIfNeeded()
                if ok {
                    await NotificationManager.scheduleNotifications(for: habit)
                }
            } else if wasEnabled && !habit.reminderEnabled {
                // Reminders used to be ON, now OFF
                await NotificationManager.cancelNotifications(for: habit)
            }
        }

        dismiss()
    }

    /// Default reminder time (8:00 PM local) for new practices.
    private static func defaultReminderTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        if let eightPM = cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) {
            return eightPM
        }
        return now
    }
}
