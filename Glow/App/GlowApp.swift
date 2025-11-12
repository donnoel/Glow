import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    init() {
        // Skip onboarding during UI tests so Home is visible immediately
        if CommandLine.arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }
    }
    private let container: ModelContainer = {
        let schema = Schema([Habit.self, HabitLog.self])
        do {
            let config = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private("iCloud.movie.Glow")
            )
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("CloudKit model container failed: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(container)
    }
}
