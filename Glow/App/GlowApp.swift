import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    @AppStorage("hasSeenGlowOnboarding") private var hasSeenGlowOnboarding = false

    init() {
        // Skip onboarding during UI tests so Home is visible immediately
        if CommandLine.arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }
    }

    // MARK: - Shared SwiftData + CloudKit container
    
    private static let modelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitLog.self
        ])

        let cloudKitID = "iCloud.movie.Glow"

        let config = ModelConfiguration(
            "GlowStore",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitID)
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            #if DEBUG
            assertionFailure("❌ Failed to create CloudKit ModelContainer: \(error)")
            #else
            print("⚠️ Failed to create CloudKit-backed ModelContainer, falling back to local store: \(error)")
            #endif

            // Fallback to a local-only store so the app still runs without CloudKit
            do {
                return try ModelContainer(for: schema)
            } catch {
                // At this point even the local store cannot be created; this is a fatal configuration issue.
                fatalError("❌ Failed to create fallback local ModelContainer: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            if !hasSeenGlowOnboarding {
                GlowOnboardingView(
                    isPresented: Binding(
                        get: { !hasSeenGlowOnboarding },
                        set: { isPresented in
                            // When onboarding is dismissed (isPresented == false),
                            // mark that the user has seen onboarding.
                            hasSeenGlowOnboarding = !isPresented
                        }
                    )
                )
            } else {
                HomeView()
            }
        }
        .modelContainer(Self.modelContainer)
    }
}
