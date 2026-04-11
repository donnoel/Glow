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
    @State private var iconName: String
    @State private var remindMe: Bool
    @State private var reminderTime: Date

    // MARK: - Init
    init(mode: Mode, habit: Habit? = nil) {
        self.mode = mode
        self.habit = habit

        _title = State(initialValue: habit?.title ?? "")
        _schedule = State(initialValue: habit?.schedule ?? .daily)

        let initialIcon = habit?.iconName ?? HabitIconLibrary.guessIcon(for: habit?.title ?? "")
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
                Section {
                    TextField("Title", text: $title)
                        .accessibilityIdentifier("practiceTitleField")
                        .font(.title3.weight(.semibold))
                        .padding(.vertical, 4)
                        .submitLabel(.done)
                        .textInputAutocapitalization(.words)
                        .onChange(of: title) { _, newValue in
                            guard mode == .add else { return }
                            // avoid running the guesser on every keystroke like "a" or "to"
                            guard newValue.count > 2 else { return }

                            let freshGuess = HabitIconLibrary.guessIcon(for: newValue)

                            // consider the icon "not customized" if it's the default or empty
                            let notCustomized: Bool = {
                                if iconName == "checkmark.circle" { return true }
                                if iconName.isEmpty { return true }
                                return false
                            }()

                            if notCustomized {
                                iconName = freshGuess
                            }
                        }

                    Text("Choose a clear name you can recognize at a glance.")
                        .font(.footnote)
                        .foregroundStyle(GlowTheme.textSecondary)
                } header: {
                    GlowSectionHeader("Title")
                }

                Section {
                    Text(schedulePreviewText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(GlowTheme.textPrimary)

                    Text(scheduleDuePreviewText)
                        .font(.footnote)
                        .foregroundStyle(GlowTheme.textSecondary)

                    SchedulePicker(selection: $schedule)
                } header: {
                    GlowSectionHeader("Schedule")
                }

                Section {
                    Text("Selected: \(selectedIconLabel)")
                        .font(.footnote)
                        .foregroundStyle(GlowTheme.textSecondary)
                    IconPickerRow(selection: $iconName)
                } header: {
                    GlowSectionHeader("Icon")
                }

                Section {
                    LabeledContent("Status", value: remindMe ? "On" : "Off")
                        .font(.subheadline.weight(.medium))

                    Toggle("Remind me", isOn: $remindMe)
                        .accessibilityHint("Turns reminder notifications on or off for this habit")
                    if remindMe {
                        DatePicker("Reminder time",
                                   selection: $reminderTime,
                                   displayedComponents: .hourAndMinute)
                            .datePickerStyle(.compact)
                            .accessibilityLabel("Reminder time")

                        Text(reminderPreviewText)
                            .font(.footnote)
                            .foregroundStyle(GlowTheme.textSecondary)
                            .accessibilityLabel(reminderPreviewText)
                    } else {
                        Text("Reminder is off.")
                            .font(.footnote)
                            .foregroundStyle(GlowTheme.textSecondary)
                    }

                    if isEditingArchivedHabit {
                        Text("Archived habits pause reminders until unarchived.")
                            .font(.footnote)
                            .foregroundStyle(GlowTheme.textSecondary)
                    }
                } header: {
                    GlowSectionHeader("Reminder")
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
                    .accessibilityIdentifier("savePracticeButton")
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .glowTint()
        .glowScreenBackground()
    }

    // MARK: - Save

    private func handleSave() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            let newHabit = createHabit(from: trimmed)
            context.insert(newHabit)
            let didSave = context.saveSafelyReturningSuccess()
            if didSave {
                await NotificationManager.syncAfterCreate(for: newHabit)
            }

        case .edit:
            guard let habit else { break }
            let wasEnabled = habit.reminderEnabled
            update(habit: habit, with: trimmed)
            let didSave = context.saveSafelyReturningSuccess()
            if didSave {
                await NotificationManager.syncAfterEdit(for: habit, wasReminderEnabled: wasEnabled)
            }
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
            iconName: iconName.isEmpty ? HabitIconLibrary.guessIcon(for: trimmedTitle) : iconName,
            sortOrder: sortOrder
        )
    }

    private func update(habit: Habit, with trimmedTitle: String) {
        habit.title = trimmedTitle
        habit.schedule = schedule
        habit.iconName = iconName.isEmpty ? HabitIconLibrary.guessIcon(for: trimmedTitle) : iconName
        applyReminderFields(to: habit)
    }

    private func applyReminderFields(to habit: Habit) {
        habit.reminderEnabled = remindMe
        if remindMe {
            habit.setReminderTime(from: reminderTime)
        }
    }

    // MARK: - Helpers

    private var isEditingArchivedHabit: Bool {
        mode == .edit && (habit?.isArchived ?? false)
    }

    private var selectedIconLabel: String {
        HabitIconLibrary.all.first(where: { $0.name == iconName })?.label ?? iconName
    }

    private var schedulePreviewText: String {
        SchedulePresentation.summaryText(for: schedule)
    }

    private var scheduleDuePreviewText: String {
        SchedulePresentation.dueStatusText(
            for: schedule,
            isArchived: isEditingArchivedHabit
        )
    }

    private var reminderPreviewText: String {
        ReminderPresentation.statusText(
            reminderEnabled: remindMe,
            reminderTime: reminderTime,
            schedule: schedule,
            isArchived: isEditingArchivedHabit
        )
    }

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
