import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    @AppStorage("hasSeenGlowOnboarding") private var hasSeenGlowOnboarding = false
    @State private var showOnboarding: Bool

    init() {
        // Skip onboarding during UI tests so Home is visible immediately
        if CommandLine.arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }

        // Seed initial onboarding state from UserDefaults *before* first frame
        let seen = UserDefaults.standard.bool(forKey: "hasSeenGlowOnboarding")
        _showOnboarding = State(initialValue: !seen)
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
            Group {
                if showOnboarding {
                    GlowOnboardingView(
                        isPresented: Binding(
                            get: { showOnboarding },
                            set: { newValue in
                                showOnboarding = newValue
                                if newValue == false {
                                    hasSeenGlowOnboarding = true
                                }
                            }
                        )
                    )
                } else {
                    HomeView()
                }
            }
        }
        .modelContainer(container)
    }
}
