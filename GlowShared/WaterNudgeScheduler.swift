import Foundation
import OSLog
import UserNotifications

nonisolated struct WaterNudgePendingNotification: Equatable, Sendable {
    let identifier: String
    let fireDate: Date
}

/// Only Sendable values cross the scheduler's boundary; system notification objects stay in the client.
nonisolated protocol WaterNudgeNotificationClient: Sendable {
    func isAuthorized() async -> Bool
    func pending() async -> [WaterNudgePendingNotification]
    func add(_ item: WaterNudgePlanItem, haptic: Bool) async throws
    func remove(_ identifiers: [String]) async
}

nonisolated struct SystemWaterNudgeNotificationClient: WaterNudgeNotificationClient {
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied, .notDetermined: return false
        @unknown default: return false
        }
    }

    func pending() async -> [WaterNudgePendingNotification] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { request in
            let fireDate: Date
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                fireDate = trigger.nextTriggerDate() ?? .distantFuture
            } else if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                fireDate = trigger.nextTriggerDate() ?? .distantFuture
            } else {
                // Keep unknown request types visible to prefix-scoped cancellation.
                fireDate = .distantFuture
            }
            return WaterNudgePendingNotification(identifier: request.identifier, fireDate: fireDate)
        }
    }

    func add(_ item: WaterNudgePlanItem, haptic: Bool) async throws {
        try await UNUserNotificationCenter.current().add(Self.request(for: item, haptic: haptic))
    }

    static func request(for item: WaterNudgePlanItem, haptic: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.threadIdentifier = "water.nudge"
        content.interruptionLevel = haptic ? .active : .passive
        content.sound = haptic ? .default : nil
        var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.fireDate)
        components.timeZone = .current
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        return UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
    }

    func remove(_ identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
}

/// Serializes replacement plans, including notification-center calls that suspend.
actor WaterNudgeScheduler {
    private nonisolated static let prefix = "water.nudge."
    private nonisolated static let ledgerKey = "water.nudge.ledger.v1"
    private let client: any WaterNudgeNotificationClient
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "movie.Glow", category: "WaterNudges")
    private var ledger: [String: Date]
    private(set) var revision: UInt64 = 0
    private var latest: Update?
    private var isProcessing = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private struct Update: Sendable {
        let revision: UInt64
        let input: WaterNudgeInput?
        let settings: WaterNudgeSettings
        let enabledOnDevice: Bool
        let haptic: Bool
        let now: Date
        let calendar: Calendar
        let nextGoalMilliliters: Double?
    }

    init(client: any WaterNudgeNotificationClient = SystemWaterNudgeNotificationClient(),
         defaultsSuiteName: String? = nil) {
        self.client = client
        let storage = defaultsSuiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
        defaults = storage
        ledger = storage.data(forKey: Self.ledgerKey).flatMap {
            try? JSONDecoder().decode([String: Date].self, from: $0)
        } ?? [:]
    }

    func nextScheduledNudge(now: Date = .now) async -> Date? {
        await client.pending()
            .filter { $0.identifier.hasPrefix(Self.prefix) && $0.fireDate > now && $0.fireDate < .distantFuture }
            .map(\.fireDate).min()
    }

    func sync(input: WaterNudgeInput?, settings: WaterNudgeSettings, enabledOnDevice: Bool,
              haptic: Bool, now: Date = .now, calendar: Calendar = .current,
              nextGoalMilliliters: Double? = nil) async {
        // Water storage and Watch commands use Gregorian civil days, regardless of the display calendar.
        var waterCalendar = Calendar(identifier: .gregorian)
        waterCalendar.timeZone = calendar.timeZone
        revision &+= 1
        // Reminder times are automatic. Retain old payload fields for compatibility,
        // but stop using previously saved hours as a user-authored reminder schedule.
        latest = Update(revision: revision, input: input, settings: WaterNudgeSettings(isEnabled: settings.isEnabled),
                        enabledOnDevice: enabledOnDevice, haptic: haptic, now: now,
                        calendar: waterCalendar, nextGoalMilliliters: nextGoalMilliliters)
        if isProcessing {
            await withCheckedContinuation { waiters.append($0) }
            return
        }
        isProcessing = true
        while let update = latest {
            latest = nil
            await reconcile(update)
        }
        isProcessing = false
        let finished = waiters
        waiters.removeAll()
        for waiter in finished { waiter.resume() }
    }

    private func reconcile(_ update: Update) async {
        let authorized = await client.isAuthorized()
        guard update.revision == revision else { return }
        let allPending = await client.pending()
        guard update.revision == revision else { return }
        let pending = allPending.filter { $0.identifier.hasPrefix(Self.prefix) }
        // Conservatively reserve space for existing reminders before adding a water horizon.
        let capacity = max(0, 64 - allPending.filter { !$0.identifier.hasPrefix(Self.prefix) }.count)
        pruneLedger(now: update.now, calendar: update.calendar)

        let plan = authorized && update.enabledOnDevice ? makePlan(update) : []
        let nextAllowedFireDate = ledger.values.filter { $0 <= update.now }.max()?.addingTimeInterval(3 * 3_600)
        let eligible = Array(plan.filter { item in
            // A dismissed or delivered slot stays spent even if its next plan would move it later.
            !(ledger[item.identifier].map { $0 <= update.now } ?? false)
                && (nextAllowedFireDate.map { item.fireDate >= $0 } ?? true)
        }.sorted { left, right in
            left.fireDate == right.fireDate ? left.identifier < right.identifier : left.fireDate < right.fireDate
        }.prefix(capacity))
        let desired = Set(eligible.map(\.identifier))
        let known = Set(pending.map(\.identifier)).union(ledger.keys)
        let removed = known.subtracting(desired).sorted()
        if !removed.isEmpty {
            await client.remove(removed)
            for identifier in removed where ledger[identifier].map({ $0 > update.now }) == true {
                ledger[identifier] = nil
            }
            persistLedger()
        }
        guard update.revision == revision else { return }

        for item in eligible {
            guard update.revision == revision else { return }
            do {
                // Stable identifiers replace the prior request, including when its wording or time changes.
                try await client.add(item, haptic: update.haptic)
                ledger[item.identifier] = item.fireDate
                persistLedger()
            } catch {
                logger.error("Couldn't schedule a water nudge: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makePlan(_ update: Update) -> [WaterNudgePlanItem] {
        guard update.settings.isEnabled, update.settings.isValid else { return [] }
        let today = update.calendar.startOfDay(for: update.now)
        let todayKey = GlowWatchDay(date: update.now, calendar: update.calendar)
        let spent = Set(ledger.filter { $0.value <= update.now }.keys)
        let notBefore = ledger.values.filter { $0 <= update.now }.max()?.addingTimeInterval(3 * 3_600)
        var items: [WaterNudgePlanItem] = []
        let hasTodayInput = update.input?.day == todayKey
        if let input = update.input, hasTodayInput {
            items = WaterNudgePlanner.plan(input: input, settings: update.settings,
                                          now: update.now, calendar: update.calendar,
                                          existingFireDates: ledger, notBefore: notBefore,
                                          spentIdentifiers: spent)
        }
        guard let futureGoal = update.nextGoalMilliliters ?? update.input?.goalMilliliters,
              WaterUnit.isValidAmount(futureGoal) else { return items }
        // Without today's intake, keep a conditional fallback for today as well as later days.
        for offset in (hasTodayInput ? 1 : 0)...6 {
            guard let day = update.calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let input = WaterNudgeInput(day: GlowWatchDay(date: day, calendar: update.calendar),
                                       totalMilliliters: 0, goalMilliliters: futureGoal,
                                       lastDrinkAt: nil, unit: update.input?.unit ?? .ounces)
            let future = WaterNudgePlanner.plan(input: input, settings: update.settings,
                                                now: offset == 0 ? update.now : day, calendar: update.calendar,
                                                existingFireDates: ledger, notBefore: notBefore,
                                                spentIdentifiers: spent)
            items += future.map { item in
                WaterNudgePlanItem(identifier: item.identifier, fireDate: item.fireDate,
                                   title: "A little water break?",
                                   body: "If you haven't had water for a while, a small drink can help toward your daily goal. Open Glow to check today's progress.")
            }
        }
        return items
    }

    private func pruneLedger(now: Date, calendar: Calendar) {
        let cutoff = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) ?? now
        ledger = ledger.filter { $0.key.hasPrefix(Self.prefix) && $0.value >= cutoff }
        persistLedger()
    }

    private func persistLedger() {
        if let data = try? JSONEncoder().encode(ledger) { defaults.set(data, forKey: Self.ledgerKey) }
    }
}
