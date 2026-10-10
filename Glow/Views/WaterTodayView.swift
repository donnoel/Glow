import SwiftData
import SwiftUI

struct WaterTodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var hasWideCard = false
    @Query private var entries: [WaterEntry]
    @Query private var goals: [WaterDayGoal]
    @Query(sort: [SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)])
    private var preferences: [WaterPreferences]
    @ObservedObject var viewModel: WaterTrackerViewModel
    private let dayKey: String

    init(day: Date, viewModel: WaterTrackerViewModel) {
        self.viewModel = viewModel
        dayKey = WaterAnalytics.dayKey(day)
        let key = dayKey
        _entries = Query(filter: #Predicate<WaterEntry> { $0.dayKey == key }, sort: \WaterEntry.timestamp, order: .reverse)
        _goals = Query(filter: #Predicate<WaterDayGoal> { $0.dayKey == key })
    }

    private var settings: WaterPreferences? { preferences.first }
    private var unit: WaterUnit { settings?.unit ?? .ounces }
    private var total: Double { entries.reduce(0) { $0 + $1.milliliters } }
    private var goal: Double { viewModel.goal(for: dayKey, goals: goals, preferences: settings) }
    private var usesWideLayout: Bool {
        horizontalSizeClass == .regular && hasWideCard && !dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Water", systemImage: "drop.fill")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { viewModel.sheet = .settings } label: {
                    Image(systemName: "slider.horizontal.3")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Water settings")
                .accessibilityIdentifier("waterSettings")
            }

            if usesWideLayout {
                HStack(alignment: .center, spacing: 32) {
                    progressButton
                        .frame(maxWidth: .infinity)
                    loggingControls
                        .frame(maxWidth: .infinity)
                }
            } else {
                progressButton
                loggingControls
            }
        }
        .padding(.vertical, 4)
        .buttonStyle(.borderless)
        .onGeometryChange(for: Bool.self) { geometry in
            geometry.size.width >= 600
        } action: { hasWideCard = $0 }
    }

    private var progressButton: some View {
        Button { viewModel.sheet = .history } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(unit.number(total)) of \(unit.label(goal))")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(GlowTheme.textPrimary)
                ProgressView(value: min(total, goal), total: goal)
                    .tint(GlowTheme.accentPrimary)
                    .accessibilityHidden(true)
                HStack {
                    Text(total + 0.001 >= goal ? "Daily goal reached" : "\(unit.label(max(0, goal - total))) remaining")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .foregroundStyle(GlowTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Water today")
        .accessibilityValue("\(unit.label(total)) of \(unit.label(goal))")
        .accessibilityHint("Shows today’s water entries")
        .accessibilityIdentifier("waterProgress")
    }

    private var loggingControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: presetColumns, spacing: 8) {
                ForEach(Array((settings?.presets ?? WaterUnit.defaultPresets).enumerated()), id: \.offset) { index, amount in
                    let isLast = abs(amount - viewModel.lastAmount) < 0.001
                    Button {
                        if viewModel.add(amount, preferences: settings, goals: goals, context: context) {
                            GlowTheme.tapHaptic()
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("+\(unit.number(amount))").font(.headline)
                            Text(unit.symbol).font(.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: usesWideLayout ? 60 : 48)
                        .foregroundStyle(GlowTheme.textPrimary)
                        .background(isLast ? GlowTheme.accentPrimary.opacity(0.18) : Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            if isLast {
                                RoundedRectangle(cornerRadius: 12).stroke(GlowTheme.accentPrimary, lineWidth: 2)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(unit.label(amount)) of water")
                    .accessibilityValue(isLast ? "Last used amount" : "")
                    .accessibilityIdentifier("waterPreset\(index)")
                }
            }

            HStack {
                Button("Custom amount", systemImage: "plus") { viewModel.sheet = .custom }
                    .accessibilityIdentifier("waterCustom")
                    .frame(minHeight: 44)
                Spacer()
                if viewModel.undoEntryID != nil && viewModel.undoDayKey == dayKey {
                    Button("Undo", systemImage: "arrow.uturn.backward") { viewModel.undo(context: context) }
                        .accessibilityLabel("Undo last water entry")
                        .accessibilityIdentifier("waterUndo")
                        .frame(minHeight: 44)
                }
            }
            .font(.subheadline.weight(.medium))
        }
    }

    private var presetColumns: [GridItem] {
        if usesWideLayout {
            return Array(repeating: GridItem(.flexible()), count: 2)
        }
        return [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 140 : 76))]
    }
}

/// Presented outside Home's refreshed List, so saving doesn't dismiss history
/// or discard the card's undo state.
struct WaterSheetPresenter: ViewModifier {
    @Environment(\.modelContext) private var context
    @ObservedObject var viewModel: WaterTrackerViewModel
    @Query private var goals: [WaterDayGoal]
    @Query(sort: [SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)])
    private var preferences: [WaterPreferences]
    let day: Date

    init(day: Date, viewModel: WaterTrackerViewModel) {
        self.day = day
        self.viewModel = viewModel
        let key = WaterAnalytics.dayKey(day)
        _goals = Query(filter: #Predicate<WaterDayGoal> { $0.dayKey == key })
    }

    func body(content: Content) -> some View {
        content
            .sheet(item: $viewModel.sheet) { sheet in
                Group {
                    switch sheet {
                    case .settings:
                        WaterSettingsView(preferences: preferences.first, goals: goals, viewModel: viewModel)
                    case .history:
                        WaterHistoryView(day: day)
                    case .custom:
                        WaterAmountSheet(title: "Add water", unit: preferences.first?.unit ?? .ounces, initialMilliliters: nil) { amount in
                            viewModel.add(amount, preferences: preferences.first, goals: goals, context: context)
                        }
                    }
                }
                .waterSaveAlert(viewModel)
            }
            .waterSaveAlert(viewModel)
    }
}

struct WaterAmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    @State private var text: String
    let title: String
    let unit: WaterUnit
    let save: (Double) -> Bool

    init(title: String, unit: WaterUnit, initialMilliliters: Double?, save: @escaping (Double) -> Bool) {
        self.title = title
        self.unit = unit
        self.save = save
        _text = State(initialValue: initialMilliliters.map(unit.inputNumber) ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Amount (\(unit.symbol))") {
                        TextField("Amount", text: $text)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isFocused)
                            .accessibilityLabel("Water amount in \(unit.title)")
                            .accessibilityIdentifier("waterAmountField")
                    }
                } footer: { Text("Enter the amount you drank.") }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = unit.parse(text), save(amount) { dismiss() }
                    }
                    .disabled(unit.parse(text) == nil)
                    .accessibilityIdentifier("waterAmountSave")
                }
            }
            .onAppear { isFocused = true }
        }
        .glowTint()
    }
}

extension View {
    func waterSaveAlert(_ model: WaterTrackerViewModel) -> some View {
        alert("Couldn’t save water", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Please try again.") }
    }
}
