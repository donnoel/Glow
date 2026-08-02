import SwiftUI
import SwiftData

@main
struct GlowApp: App {
    @AppStorage("hasSeenGlowOnboarding") private var hasSeenGlowOnboarding = false
    private static let settingsVersionKey = "app_version_display"

    init() {
        Self.updateSettingsVersionDisplay()

        let arguments = CommandLine.arguments

        #if DEBUG
        if arguments.contains("-resetDataForUITests") {
            Self.resetPersistentDataForUITests()
        }

        if arguments.contains("-showOnboardingForUITests") {
            UserDefaults.standard.set(false, forKey: "hasSeenGlowOnboarding")
        } else if arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }
        #else
        // Skip onboarding during UI tests so Home is visible immediately.
        if arguments.contains("--uitesting") {
            UserDefaults.standard.set(true, forKey: "hasSeenGlowOnboarding")
        }
        #endif

        Self.upgradeLegacyHabitIcons()
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

    private static func upgradeLegacyHabitIcons() {
        let context = modelContainer.mainContext

        do {
            let habits = try context.fetch(FetchDescriptor<Habit>())
            var didChange = false

            for habit in habits {
                guard let upgradedIcon = HabitIconLibrary.upgradedIcon(
                    for: habit.title,
                    currentIcon: habit.iconName
                ) else {
                    continue
                }

                habit.iconName = upgradedIcon
                didChange = true
            }

            guard didChange else { return }
            guard context.saveSafelyReturningSuccess() else {
                context.rollback()
                return
            }
        } catch {
            #if DEBUG
            print("⚠️ Legacy habit icon upgrade failed: \(error)")
            #endif
        }
    }

    #if DEBUG
    private static func resetPersistentDataForUITests() {
        let context = modelContainer.mainContext

        do {
            let logs = try context.fetch(FetchDescriptor<HabitLog>())
            for log in logs {
                context.delete(log)
            }

            let habits = try context.fetch(FetchDescriptor<Habit>())
            for habit in habits {
                context.delete(habit)
            }

            try context.save()
            SharedProgressStore.resetToday()
        } catch {
            assertionFailure("Failed to reset UI test data: \(error)")
            context.rollback()
        }
    }
    #endif

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
