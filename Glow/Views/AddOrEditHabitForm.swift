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
    @State private var remindMe: Bool
    @State private var reminderTime: Date

    // MARK: - Init
    init(mode: Mode, habit: Habit? = nil) {
        self.mode = mode
        self.habit = habit

        _title = State(initialValue: habit?.title ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)
        _isArchived = State(initialValue: habit?.isArchived ?? false)

        let initialIcon = habit?.iconName ?? Habit.guessIconName(for: habit?.title ?? "")
        _iconName = State(initialValue: initialIcon)

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.words)
                        .onChange(of: title) { _, newValue in
                            guard mode == .add else { return }
                            let freshGuess = Habit.guessIconName(for: newValue)

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

                Section("Schedule") {
                    SchedulePicker(selection: $schedule)
                }

                Section("Icon") {
                    IconPickerRow(selection: $iconName)
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $remindMe)
                    if remindMe {
                        DatePicker("Time",
                                   selection: $reminderTime,
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .accessibilityLabel("Reminder time")
                    }
                }

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

    // MARK: - Save

    private func handleSave() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let newHabit = createHabit(from: trimmed)
            context.insert(newHabit)
            context.saveSafelyReturningSuccess()
            await applyNotificationsAfterAdd(for: newHabit)

        case .edit:
            guard let habit else { break }
            let wasEnabled = habit.reminderEnabled
            update(habit: habit, with: trimmed)
            context.saveSafelyReturningSuccess()
            await applyNotificationsAfterEdit(for: habit, wasEnabled: wasEnabled)
        }

        dismiss()
    }

    // MARK: - Build / Update

    private func createHabit(from trimmedTitle: String) -> Habit {
        let sortOrder = nextSortOrder()
        let comps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let hour = comps.hour
        let minute = comps.minute

        return Habit(
            title: trimmedTitle,
            createdAt: .now,
            isArchived: false,
            schedule: schedule,
            reminderEnabled: remindMe,
            reminderHour: hour,
            reminderMinute: minute,
            iconName: iconName.isEmpty ? Habit.guessIconName(for: trimmedTitle) : iconName,
            sortOrder: sortOrder
        )
    }

    private func update(habit: Habit, with trimmedTitle: String) {
        habit.title = trimmedTitle
        habit.schedule = schedule
        habit.isArchived = isArchived
        habit.iconName = iconName.isEmpty ? Habit.guessIconName(for: trimmedTitle) : iconName
        applyReminderFields(to: habit)
    }

    // MARK: - Notifications

    private func applyReminderFields(to habit: Habit) {
        habit.reminderEnabled = remindMe
        if remindMe {
            habit.setReminderTime(from: reminderTime)
        } else {
            habit.reminderHour = nil
            habit.reminderMinute = nil
        }
    }

    private func applyNotificationsAfterAdd(for habit: Habit) async {
        guard remindMe else { return }
        let ok = await NotificationManager.requestAuthorizationIfNeeded()
        if ok {
            await NotificationManager.scheduleNotifications(for: habit)
        }
    }

    private func applyNotificationsAfterEdit(for habit: Habit, wasEnabled: Bool) async {
        if habit.isArchived {
            await NotificationManager.cancelNotifications(for: habit)
        } else if habit.reminderEnabled {
            let ok = await NotificationManager.requestAuthorizationIfNeeded()
            if ok {
                await NotificationManager.scheduleNotifications(for: habit)
            }
        } else if wasEnabled && !habit.reminderEnabled {
            await NotificationManager.cancelNotifications(for: habit)
        }
    }

    // MARK: - Helpers

    private func nextSortOrder() -> Int {
        var descriptor = FetchDescriptor<Habit>()
        descriptor.sortBy = [SortDescriptor(\Habit.sortOrder, order: .reverse)]
        descriptor.fetchLimit = 1
        let topHabit = (try? context.fetch(descriptor))?.first
        let maxOrder = topHabit?.sortOrder ?? 9_998
        return maxOrder + 1
    }

    private static func defaultReminderTime() -> Date {
        let cal = Calendar.current
        let now = Date()
        return cal.date(bySettingHour: 20, minute: 0, second: 0, of: now) ?? now
    }
}
