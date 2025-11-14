import SwiftUI
import SwiftData
import CoreData

struct ArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    // only archived habits
    @Query(
        filter: #Predicate<Habit> { $0.isArchived == true },
        sort: [SortDescriptor(\Habit.title, order: .forward)]
    )
    private var archivedHabits: [Habit]

    @State private var selectedHabit: Habit?

    var body: some View {
        GlowModalScaffold(
            title: "Archived",
            // subtitle: "Practices you’ve tucked away. Bring them back any time."
        ) {
            if archivedHabits.isEmpty {
                ContentUnavailableView(
                    "No archived practices",
                    systemImage: "archivebox",
                    description: Text("Practices you archive will show up here.")
                )
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(glassCard)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 4)
            } else {
                VStack(spacing: 14) {
                    ForEach(archivedHabits) { habit in
                        HStack(spacing: 10) {
                            // matches Home look
                            HabitRowGlass(habit: habit, isArchived: true) {
                                // no toggle in archive
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .onTapGesture {
                                selectedHabit = habit
                            }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("View details for \(habit.title)")

                            Button {
                                unarchive(habit)
                            } label: {
                                Image(systemName: "arrow.uturn.left.circle.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(GlowTheme.accentPrimary)
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Unarchive \(habit.title)")
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .sheet(item: $selectedHabit) { habit in
            HabitDetailView(
                habit: habit,
                prewarmedMonth: MonthHeatmapModel(habit: habit, month: Date())
            )
        }
    }

    private var glassCard: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        Color.white.opacity(colorScheme == .dark ? 0.15 : 0.28),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.08),
                radius: 20,
                y: 12
            )
    }

    private func unarchive(_ habit: Habit) {
        habit.isArchived = false
        do {
            try context.save()
            // Notify any listeners (e.g., HomeView) that data changed and that the SwiftData context emitted changes
            NotificationCenter.default.post(name: .glowDataDidChange, object: nil)
            NotificationCenter.default.post(name: .NSManagedObjectContextObjectsDidChange, object: context)
        } catch {
            print("Unarchive save error:", error)
        }
    }
}
