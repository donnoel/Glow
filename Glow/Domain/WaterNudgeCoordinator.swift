import Combine
import CoreData
import Foundation
import OSLog
import SwiftData
import UIKit

extension Notification.Name {
    static let glowWaterNudgeSettingsDidChange = Notification.Name("glowWaterNudgeSettingsDidChange")
}

/// Reads the UI-owned SwiftData context, then sends value snapshots to the scheduler actor.
@MainActor
final class WaterNudgeCoordinator {
    static let phoneEnabledKey = "water.quietPhoneNudgesEnabled"
    private let context: ModelContext
    private let scheduler = WaterNudgeScheduler()
    private var subscriptions: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?
    private var refreshRevision: UInt64 = 0
    private let logger = Logger(subsystem: "movie.Glow", category: "WaterNudges")

    init(container: ModelContainer) { context = container.mainContext }

    func start() {
        guard subscriptions.isEmpty,
              !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        for name in [ModelContext.didSave, .glowDataDidChange, .glowWaterNudgeSettingsDidChange,
                     .NSPersistentStoreRemoteChange, UIApplication.didBecomeActiveNotification,
                     UIApplication.significantTimeChangeNotification] {
            NotificationCenter.default.publisher(for: name).sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleRefresh() }
            }.store(in: &subscriptions)
        }
        scheduleRefresh()
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshRevision &+= 1
        let revision = refreshRevision
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Glow water reminders") { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, refreshRevision == revision else { return }
                refreshTask?.cancel()
            }
        }
        refreshTask = Task { [weak self] in
            defer {
                if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
            }
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                let now = Date()
                let water = try WatchWaterAction.snapshot(in: context, now: now)
                let input = WaterNudgeInput(
                    day: water.day, totalMilliliters: water.entries.reduce(0) { $0 + $1.milliliters },
                    goalMilliliters: water.goalMilliliters,
                    lastDrinkAt: water.entries.compactMap(\.timestamp).max(),
                    unit: WaterUnit(rawValue: water.unitRaw ?? "") ?? .ounces
                )
                // This switch is device-local: disabling the phone never disables Watch taps.
                let defaults = UserDefaults.standard
                let phoneEnabled = defaults.object(forKey: Self.phoneEnabledKey) == nil
                    || defaults.bool(forKey: Self.phoneEnabledKey)
                await scheduler.sync(input: input, settings: water.nudges ?? WaterNudgeSettings(),
                                     enabledOnDevice: phoneEnabled, haptic: false, now: now,
                                     nextGoalMilliliters: water.nextGoalMilliliters)
            } catch is CancellationError {
                return
            } catch {
                self?.logger.error("Water nudge refresh failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
