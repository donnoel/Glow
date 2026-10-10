import SwiftUI

struct GlowWatchTodayView: View {
    @ObservedObject var model: GlowWatchViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 60)) { timeline in
                let now = timeline.date
                let day = GlowWatchDay(date: now)
                let habits = model.state.snapshot?.habits ?? []
                let scheduled = habits.filter { $0.isScheduled(on: now) }
                let other = habits.filter { !$0.isScheduled(on: now) }
                List {
                    if model.state.snapshot == nil {
                        Section {
                            Text("Your habits are on their way")
                                .font(.headline)
                            Text("Open Glow on your paired iPhone to get started.")
                                .foregroundStyle(.secondary)
                        }
                    } else if habits.isEmpty {
                        Section {
                            Text("No active habits")
                                .font(.headline)
                            Text("Add a habit in Glow on your iPhone or iPad.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            let done = scheduled.filter { model.state.isCompleted($0.id, on: day) }.count
                            Label {
                                Text("\(done) of \(scheduled.count) done")
                            } icon: {
                                Image("GlowBrandIcon")
                                    .renderingMode(.original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                    .accessibilityHidden(true)
                            }
                                .font(.headline)
                                .foregroundStyle(.teal)
                                .accessibilityLabel("\(done) of \(scheduled.count) scheduled habits completed today")
                        }
                    }
                    GlowWatchWaterView(model: model, now: now)
                    if !scheduled.isEmpty {
                        Section("Today") {
                            ForEach(scheduled) { habit in row(habit, day: day) }
                        }
                    }
                    if !other.isEmpty {
                        Section(scheduled.isEmpty ? "Your habits" : "Other habits") {
                            ForEach(other) { habit in row(habit, day: day) }
                        }
                    }
                    Section {
                        if let error = model.errorMessage ?? model.state.syncError {
                            Text(error).foregroundStyle(.secondary)
                        } else if !model.state.pending.isEmpty {
                            Label("Saved on Watch · waiting to sync", systemImage: "arrow.triangle.2.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else if let snapshot = model.state.snapshot, snapshot.day != day {
                            Text("Showing saved habits. Refresh to check today's status.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Button("Refresh", systemImage: "arrow.clockwise") { model.refresh() }
                    }
                }
            }
            .navigationTitle("Glow")
        }
        .tint(.teal)
        .task { await model.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
    }

    private func row(_ habit: GlowWatchHabit, day: GlowWatchDay) -> some View {
        let completed = model.state.isCompleted(habit.id, on: day)
        return Button {
            let tappedDay = GlowWatchDay(date: Date())
            let wasCompleted = model.state.isCompleted(habit.id, on: tappedDay)
            Task { await model.setCompleted(!wasCompleted, habitID: habit.id, day: tappedDay) }
        } label: {
            HStack(spacing: 10) {
                HabitIconSymbol(name: habit.iconName, size: 20)
                    .foregroundStyle(.teal)
                    .accessibilityHidden(true)
                Text(habit.title)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(completed ? Color.teal : Color.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isSaving)
        .accessibilityLabel(habit.title)
        .accessibilityValue(completed ? "Completed today" : "Not completed today")
        .accessibilityHint(completed ? "Marks this habit incomplete today" : "Marks this habit done today")
    }
}
