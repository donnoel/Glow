import SwiftData
import SwiftUI

struct WaterHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var entries: [WaterEntry]
    @Query private var goals: [WaterDayGoal]
    @Query(sort: [SortDescriptor(\WaterPreferences.updatedAt, order: .reverse), SortDescriptor(\WaterPreferences.id)])
    private var preferences: [WaterPreferences]
    @StateObject private var viewModel = WaterTrackerViewModel()
    @State private var editingEntry: WaterEntry?
    private let day: Date

    init(day: Date) {
        self.day = day
        let key = WaterAnalytics.dayKey(day)
        _entries = Query(filter: #Predicate<WaterEntry> { $0.dayKey == key }, sort: \WaterEntry.timestamp, order: .reverse)
        _goals = Query(filter: #Predicate<WaterDayGoal> { $0.dayKey == key })
    }

    private var unit: WaterUnit { preferences.first?.unit ?? .ounces }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    let total = entries.reduce(0) { $0 + $1.milliliters }
                    let goal = viewModel.goal(for: WaterAnalytics.dayKey(day), goals: goals, preferences: preferences.first)
                    LabeledContent("Logged", value: unit.label(total))
                        .accessibilityIdentifier("waterHistoryTotal")
                    LabeledContent("Saved goal", value: unit.label(goal))
                }

                Section("Entries") {
                    if entries.isEmpty {
                        Text("No water logged for this day.").foregroundStyle(.secondary)
                    }
                    ForEach(entries) { entry in
                        Button { editingEntry = entry } label: {
                            HStack {
                                Label(unit.label(entry.milliliters), systemImage: "drop")
                                    .foregroundStyle(GlowTheme.textPrimary)
                                Spacer()
                                Text(entry.timestamp, style: .time).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                        .accessibilityLabel("\(unit.label(entry.milliliters)), \(entry.timestamp.formatted(date: .omitted, time: .shortened))")
                        .accessibilityHint("Edit this water entry. Swipe to delete.")
                        .swipeActions {
                            Button("Delete", role: .destructive) { viewModel.delete(entry, context: context) }
                        }
                    }
                    .onDelete { offsets in
                        let removing = offsets.map { entries[$0] }
                        for entry in removing { viewModel.delete(entry, context: context) }
                    }
                }
            }
            .navigationTitle(Calendar.current.isDateInToday(day) ? "Water today" : day.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editingEntry) { entry in
                WaterAmountSheet(title: "Edit water", unit: unit, initialMilliliters: entry.milliliters) { amount in
                    viewModel.update(entry, milliliters: amount, context: context)
                }
                .waterSaveAlert(viewModel)
            }
            .waterSaveAlert(viewModel)
        }
        .glowTint()
    }
}
