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

    // MARK: - Shared SwiftData + CloudKit container

    /// IMPORTANT:
    /// - The CloudKit identifier **must** match the one in Signing & Capabilities → iCloud.
    /// - Example: iCloud.com.yourteam.Glow
    private static let modelContainer: ModelContainer = {
        let schema = Schema([
            Habit.self,
            HabitLog.self
        ])

        // Replace this with the exact identifier from your entitlements
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
            #endif
            // Fallback to a local-only store so the app still runs in release
            return try! ModelContainer(for: schema)
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
        .modelContainer(Self.modelContainer)
    }
}
