import SwiftUI
import SwiftData

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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if archivedHabits.isEmpty {
                        ContentUnavailableView(
                            "No archived practices",
                            systemImage: "archivebox",
                            description: Text("Practices you archive will show up here.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 240)
                        .background(glassCard)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.top, 8)
                    } else {
                        ForEach(archivedHabits) { habit in
                            HStack(spacing: 10) {
                                // look identical to home rows
                                HabitRowGlass(habit: habit) {
                                    // disabled in archive
                                }
                                .disabled(true)

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
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .background(GlowTheme.bgSurface.ignoresSafeArea())
            .navigationTitle("Archived")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
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
        } catch {
            print("Unarchive save error:", error)
        }
    }
}
