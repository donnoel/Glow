import SwiftData
import SwiftUI

struct WaterSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @ObservedObject var viewModel: WaterTrackerViewModel
    @State private var profile: WaterGoalProfile
    @State private var unit: WaterUnit
    @State private var goalText: String
    @State private var presetTexts: [String]
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
    }

    private var valid: Bool {
        unit.parse(goalText) != nil && presetTexts.allSatisfy { unit.parse($0) != nil }
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
                    Button("Save") {
                        guard let goal = unit.parse(goalText) else { return }
                        var draft = WaterSettingsDraft()
                        draft.profile = profile
                        draft.unit = unit
                        draft.goalMilliliters = goal
                        draft.presets = presetTexts.compactMap { unit.parse($0) }
                        if viewModel.saveSettings(draft, preferences: preferences, context: context) { dismiss() }
                    }
                    .disabled(!valid)
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
        }
        .glowTint()
    }
}
