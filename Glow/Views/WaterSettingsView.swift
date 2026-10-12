import SwiftData
import SwiftUI
import UIKit

struct WaterSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var viewModel: WaterTrackerViewModel
    @State private var profile: WaterGoalProfile
    @State private var unit: WaterUnit
    @State private var goalText: String
    @State private var presetTexts: [String]
    @State private var nudges: WaterNudgeSettings
    @State private var phoneNudges: Bool
    @State private var phoneAuthorization = WaterNudgeAuthorizationStatus.notDetermined
    @State private var isSaving = false
    @State private var permissionError: String?
    let preferences: WaterPreferences?
    let goals: [WaterDayGoal]

    init(preferences: WaterPreferences?, goals: [WaterDayGoal], viewModel: WaterTrackerViewModel) {
        self.preferences = preferences
        self.goals = goals
        self.viewModel = viewModel
        let draft = WaterSettingsDraft(preferences: preferences)
        _profile = State(initialValue: draft.profile)
        _unit = State(initialValue: draft.unit)
        _goalText = State(initialValue: draft.unit.inputNumber(draft.goalMilliliters))
        _presetTexts = State(initialValue: draft.presets.map(draft.unit.inputNumber))
        _nudges = State(initialValue: WaterNudgeSettings(isEnabled: draft.nudges.isEnabled))
        let defaults = UserDefaults.standard
        _phoneNudges = State(initialValue: defaults.object(forKey: WaterNudgeCoordinator.phoneEnabledKey) == nil
                            || defaults.bool(forKey: WaterNudgeCoordinator.phoneEnabledKey))
    }

    private var valid: Bool {
        unit.parse(goalText) != nil && presetTexts.allSatisfy { unit.parse($0) != nil }
            && (!nudges.isEnabled || nudges.isValid)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    Picker("Goal suggestion", selection: $profile) {
                        ForEach(WaterGoalProfile.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("waterGoalProfile")
                    Picker("Units", selection: $unit) {
                        ForEach(WaterUnit.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("waterUnits")
                    LabeledContent("Goal (\(unit.symbol))") {
                        TextField("Goal", text: $goalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Daily water goal in \(unit.title)")
                            .accessibilityIdentifier("waterGoalField")
                    }
                    Text("Male starts at 100 fl oz; Female starts at 75 fl oz. You can adjust either goal.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Quick amounts") {
                    ForEach(presetTexts.indices, id: \.self) { index in
                        LabeledContent("Amount \(index + 1) (\(unit.symbol))") {
                            TextField("Amount", text: $presetTexts[index])
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .accessibilityLabel("Quick amount \(index + 1) in \(unit.title)")
                                .accessibilityIdentifier("waterPresetField\(index)")
                        }
                    }
                }

                Section {
                    Toggle("Gentle water nudges", isOn: $nudges.isEnabled)
                        .accessibilityIdentifier("waterNudgesEnabled")
                    if nudges.isEnabled {
                        Toggle("Quiet phone notifications", isOn: $phoneNudges)
                            .accessibilityHint("Keeps a quiet copy in this device’s Notification Center. Watch taps stay enabled.")
                            .accessibilityIdentifier("waterPhoneNudgesEnabled")
                        if phoneNudges && phoneAuthorization == .denied {
                            Text("Phone notifications are blocked in system Settings. Watch taps can still be enabled on your Watch.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Link("Open notification settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                        }
                    }
                } header: {
                    Text("A little encouragement")
                } footer: {
                    Text("Glow chooses when to nudge based on your logged water and how much of the day remains. Up to three gentle Watch taps a day, several hours apart, with quiet time after a drink and overnight. Reaching your goal clears today’s nudges. Open Glow on your Watch to allow notifications. Phone copies stay quiet in Notification Center and can be switched off separately.")
                }

                Section {
                    Text("These are rounded starting points for fluids from all drinks. Food also contributes water. If you log only plain water, choose a personal goal that accounts for your other drinks and needs.")
                    Text("Needs vary with activity, weather and health. Follow any fluid guidance from your clinician.")
                    Link("About the hydration guidance", destination: URL(string: "https://www.nationalacademies.org/read/10925/chapter/6")!)
                } header: { Text("Choosing your goal") }
                    .font(.footnote)

                if goals.contains(where: { $0.dayKey == WaterAnalytics.dayKey(.now) }) {
                    Section {
                        Text("Today keeps the goal saved with your first entry. A new goal applies to the next day you log water; past days keep their original goals.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Water settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveSettings() } }
                    .disabled(!valid || isSaving)
                    .accessibilityIdentifier("waterSettingsSave")
                }
            }
            .onChange(of: profile) { _, newValue in
                if let goal = newValue.suggestedMilliliters { goalText = unit.inputNumber(goal) }
            }
            .onChange(of: unit) { oldValue, newValue in
                if let goal = oldValue.parse(goalText) { goalText = newValue.inputNumber(goal) }
                presetTexts = presetTexts.map { oldValue.parse($0).map(newValue.inputNumber) ?? $0 }
            }
            .waterSaveAlert(viewModel)
            .task { phoneAuthorization = await WaterNudgeAuthorization.status() }
            .alert("Phone notifications", isPresented: Binding(
                get: { permissionError != nil }, set: { if !$0 { permissionError = nil } }
            )) {
                Button("OK") { permissionError = nil }
            } message: { Text(permissionError ?? "") }
        }
        .glowTint()
    }

    private func saveSettings() async {
        guard let goal = unit.parse(goalText), valid else { return }
        isSaving = true
        defer { isSaving = false }
        var draft = WaterSettingsDraft()
        draft.profile = profile
        draft.unit = unit
        draft.goalMilliliters = goal
        draft.presets = presetTexts.compactMap { unit.parse($0) }
        draft.nudges = nudges
        guard viewModel.saveSettings(draft, preferences: preferences, context: context) else { return }
        UserDefaults.standard.set(phoneNudges, forKey: WaterNudgeCoordinator.phoneEnabledKey)
        if nudges.isEnabled && phoneNudges {
            do {
                if await WaterNudgeAuthorization.status() == .notDetermined {
                    _ = try await WaterNudgeAuthorization.request()
                }
                phoneAuthorization = await WaterNudgeAuthorization.status()
            } catch {
                permissionError = "Your water settings are saved, but notification permission couldn’t be checked. Please try again."
            }
        }
        NotificationCenter.default.post(name: .glowWaterNudgeSettingsDidChange, object: nil)
        if permissionError == nil { dismiss() }
    }
}
