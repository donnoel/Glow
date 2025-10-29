import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [Habit.self, HabitLog.self])    }
}
