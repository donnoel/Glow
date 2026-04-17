import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    @AppStorage("hasSeenGlowOnboarding") private var hasSeenGlowOnboarding = false
    private static let settingsVersionKey = "app_version_display"

    init() {
        Self.updateSettingsVersionDisplay()

        // Skip onboarding during UI tests so Home is visible immediately
        if CommandLine.arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }
    }

    private static func updateSettingsVersionDisplay() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        guard let version, !version.isEmpty else { return }

        let displayValue: String
        if let build, !build.isEmpty {
            displayValue = "\(version) (\(build))"
        } else {
            displayValue = version
        }

        UserDefaults.standard.set(displayValue, forKey: settingsVersionKey)
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
                RootTabShell()
            }
        }
        .modelContainer(Self.modelContainer)
    }
}
