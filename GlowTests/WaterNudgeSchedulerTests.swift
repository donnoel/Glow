import Foundation
import Testing
import UserNotifications
@testable import Glow

@MainActor
struct WaterNudgeSchedulerTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(hour: Int = 8, day: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }

    private func input(at now: Date, ounces: Double = 0) -> WaterNudgeInput {
        WaterNudgeInput(day: GlowWatchDay(date: now, calendar: calendar),
                        totalMilliliters: WaterUnit.ounces.milliliters(from: ounces),
                        goalMilliliters: WaterUnit.ounces.milliliters(from: 100),
                        lastDrinkAt: nil, unit: .ounces)
    }

    private var settings: WaterNudgeSettings {
        WaterNudgeSettings(isEnabled: true, startHour: 8, endHour: 21)
    }

    private func suite() -> String { "WaterNudgeSchedulerTests.\(UUID().uuidString)" }

    private func clear(_ suite: String) {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
    }

    actor Client: WaterNudgeNotificationClient {
        struct Added: Sendable {
            let item: WaterNudgePlanItem
            let haptic: Bool
        }
        private var allowed = true
        private var requests: [WaterNudgePendingNotification] = []
        private var additions: [Added] = []
        private var removals: [[String]] = []
        private var holdNextAddition = false
        private var pausedAddition: CheckedContinuation<Void, Never>?
        private var pauseWaiter: CheckedContinuation<Void, Never>?

        func isAuthorized() async -> Bool { allowed }
        func pending() async -> [WaterNudgePendingNotification] { requests }
        func add(_ item: WaterNudgePlanItem, haptic: Bool) async throws {
            if holdNextAddition {
                holdNextAddition = false
                await withCheckedContinuation { continuation in
                    pausedAddition = continuation
                    pauseWaiter?.resume()
                    pauseWaiter = nil
                }
            }
            requests.removeAll { $0.identifier == item.identifier }
            requests.append(WaterNudgePendingNotification(identifier: item.identifier, fireDate: item.fireDate))
            additions.append(Added(item: item, haptic: haptic))
        }
        func remove(_ identifiers: [String]) async {
            requests.removeAll { identifiers.contains($0.identifier) }
            removals.append(identifiers)
        }
        func authorize(_ value: Bool) { allowed = value }
        func seed(_ values: [WaterNudgePendingNotification]) { requests = values }
        func added() -> [Added] { additions }
        func removed() -> [[String]] { removals }
        func holdNextAdd() { holdNextAddition = true }
        func waitUntilAddIsPaused() async {
            if pausedAddition != nil { return }
            await withCheckedContinuation { pauseWaiter = $0 }
        }
        func resumeAdd() {
            pausedAddition?.resume()
            pausedAddition = nil
        }
    }

    @Test func cancellationPreservesHabitRemindersAndReenableRestoresUnspentSlots() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let habit = WaterNudgePendingNotification(identifier: "habit.read.weekday.2", fireDate: now.addingTimeInterval(3_600))
        await client.seed([habit])
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let initial = await client.pending()
        #expect(initial.count > 1)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: false, haptic: true, now: now, calendar: calendar)
        #expect(await client.pending() == [habit])
        #expect(await client.removed().flatMap { $0 }.allSatisfy { $0.hasPrefix("water.nudge.") })
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        #expect(Set(await client.pending().map(\.identifier)) == Set(initial.map(\.identifier)))
    }

    @Test func scheduleHasSevenDayHorizonAndConditionalFutureWording() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let added = await client.added()
        #expect(!added.isEmpty)
        #expect(added.count <= 21)
        let groups = Dictionary(grouping: added) { calendar.startOfDay(for: $0.item.fireDate) }
        #expect(groups.count == 7)
        #expect(groups.values.allSatisfy { $0.count <= 3 })
        let limit = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now))!
        #expect(added.allSatisfy { $0.item.fireDate > now && $0.item.fireDate < limit })
        for future in added where !calendar.isDate(future.item.fireDate, inSameDayAs: now) {
            #expect(future.item.body.hasPrefix("If you haven't had water"))
            #expect(!future.item.body.contains("100"))
            #expect(!future.item.body.contains("remaining"))
        }
    }

    @Test func eveningEnableQueuesTodayAndRefreshKeepsItsOriginalDeadline() async throws {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date(hour: 20)
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now, ounces: 40), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let expected = now.addingTimeInterval(300)
        #expect(await scheduler.nextScheduledNudge(now: now) == expected)
        let later = now.addingTimeInterval(120)
        await scheduler.sync(input: input(at: later, ounces: 40), settings: settings,
                             enabledOnDevice: true, haptic: true, now: later, calendar: calendar)
        #expect(await scheduler.nextScheduledNudge(now: later) == expected)
        let afterDelivery = expected.addingTimeInterval(60)
        await scheduler.sync(input: input(at: afterDelivery, ounces: 40), settings: settings,
                             enabledOnDevice: true, haptic: true, now: afterDelivery, calendar: calendar)
        #expect(await client.pending().allSatisfy { !calendar.isDate($0.fireDate, inSameDayAs: now) })
    }

    @Test func legacyHoursDoNotChooseReminderTimes() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now, ounces: 40),
                             settings: WaterNudgeSettings(isEnabled: true, startHour: 18, endHour: 23),
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        #expect(await scheduler.nextScheduledNudge(now: now) == now.addingTimeInterval(6.5 * 3_600))
    }

    @Test func existingHabitsReserveCapacityBeforeTheWaterHorizon() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let habits = (0..<62).map { index in
            WaterNudgePendingNotification(identifier: "habit.\(index).weekday.2",
                                          fireDate: now.addingTimeInterval(Double(index + 1) * 3_600))
        }
        await client.seed(habits)
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let pending = await client.pending()
        let water = pending.filter { $0.identifier.hasPrefix("water.nudge.") }
        #expect(water.count == 2)
        let earliest = WaterNudgePlanner.plan(input: input(at: now), settings: settings,
                                             now: now, calendar: calendar).sorted { $0.fireDate < $1.fireDate }.prefix(2)
        #expect(Set(water.map(\.identifier)) == Set(earliest.map(\.identifier)))
        #expect(Set(pending.filter { !$0.identifier.hasPrefix("water.nudge.") }.map(\.identifier)) == Set(habits.map(\.identifier)))
        #expect(await client.removed().flatMap { $0 }.allSatisfy { $0.hasPrefix("water.nudge.") })
    }

    @Test func reachedGoalClearsTodayButKeepsFutureDays() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        #expect(await client.pending().contains { calendar.isDate($0.fireDate, inSameDayAs: now) })
        await scheduler.sync(input: input(at: now, ounces: 100), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let pending = await client.pending()
        #expect(!pending.isEmpty)
        #expect(!pending.contains { calendar.isDate($0.fireDate, inSameDayAs: now) })
    }

    @Test func staleInputNeverMakesExactTodayClaims() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: yesterday, ounces: 20), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        #expect(await client.added().allSatisfy { $0.item.body.hasPrefix("If you haven't had water") })
        #expect(await client.added().allSatisfy { !$0.item.body.contains("20") })
        #expect(await client.pending().contains { calendar.isDate($0.fireDate, inSameDayAs: now) })
    }

    @Test func offlineNextDayRefreshKeepsTodaysConditionalFallback() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let tomorrow = date(day: 13)
        await scheduler.sync(input: nil, settings: settings,
                             enabledOnDevice: true, haptic: true, now: tomorrow, calendar: calendar,
                             nextGoalMilliliters: WaterUnit.ounces.milliliters(from: 100))
        #expect(await client.pending().contains { calendar.isDate($0.fireDate, inSameDayAs: tomorrow) })
        let additions = await client.added()
        let todays = additions.filter { calendar.isDate($0.item.fireDate, inSameDayAs: tomorrow) }
        #expect(todays.allSatisfy { $0.item.body.hasPrefix("If you haven't had water") })
    }

    @Test func nonGregorianDisplayCalendarKeepsGregorianWaterDayAndTimezone() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        var displayCalendar = Calendar(identifier: .buddhist)
        displayCalendar.timeZone = TimeZone(secondsFromGMT: 7 * 3_600)!
        var waterCalendar = Calendar(identifier: .gregorian)
        waterCalendar.timeZone = displayCalendar.timeZone
        let now = waterCalendar.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: 8))!
        let water = WaterNudgeInput(day: .waterDay(date: now, timeZone: displayCalendar.timeZone),
                                   totalMilliliters: 0, goalMilliliters: WaterUnit.ounces.milliliters(from: 100),
                                   lastDrinkAt: nil, unit: .ounces)
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: water, settings: settings, enabledOnDevice: true,
                             haptic: true, now: now, calendar: displayCalendar)
        let currentDay = await client.added().filter { waterCalendar.isDate($0.item.fireDate, inSameDayAs: now) }
        #expect(!currentDay.isEmpty)
        #expect(currentDay.allSatisfy { $0.item.identifier.hasPrefix("water.nudge.2026-10-12.") })
        #expect(currentDay.allSatisfy { !$0.item.body.hasPrefix("If you haven't had water") })
    }

    @Test func permissionBlockedCancelsWaterWithoutPromptingOrTouchingHabits() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let habit = WaterNudgePendingNotification(identifier: "habit.read.weekday.2", fireDate: now.addingTimeInterval(3_600))
        let water = WaterNudgePendingNotification(identifier: "water.nudge.2026-10-12.0", fireDate: now.addingTimeInterval(7_200))
        await client.seed([habit, water])
        await client.authorize(false)
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        #expect(await client.added().isEmpty)
        #expect(await client.pending() == [habit])
    }

    @Test func passedAndDismissedSlotStaysSpentAfterRelaunchAndReconfiguration() async throws {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let first = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await first.sync(input: input(at: now), settings: settings,
                         enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let initial = await client.pending()
        let passed = try #require(initial.filter { calendar.isDate($0.fireDate, inSameDayAs: now) }.min { $0.fireDate < $1.fireDate })
        let later = passed.fireDate.addingTimeInterval(60)
        // Simulate system delivery followed by dismissing the alert; pending requests no longer contain it.
        await client.seed(initial.filter { $0.identifier != passed.identifier })
        let relaunched = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        let changed = WaterNudgeSettings(isEnabled: true, startHour: 10, endHour: 23)
        await relaunched.sync(input: input(at: later), settings: changed,
                              enabledOnDevice: true, haptic: true, now: later, calendar: calendar)
        #expect(await client.pending().allSatisfy { $0.identifier != passed.identifier })
        await relaunched.sync(input: input(at: later), settings: changed,
                              enabledOnDevice: false, haptic: true, now: later, calendar: calendar)
        await relaunched.sync(input: input(at: later), settings: changed,
                              enabledOnDevice: true, haptic: true, now: later, calendar: calendar)
        #expect(await client.pending().allSatisfy { $0.identifier != passed.identifier })
    }

    @Test func deviceModeRequestsWatchHapticsAndQuietPhoneCopy() async {
        let watch = Client()
        let phone = Client()
        let watchStorage = suite()
        let phoneStorage = suite()
        defer { clear(watchStorage); clear(phoneStorage) }
        let now = date()
        await WaterNudgeScheduler(client: watch, defaultsSuiteName: watchStorage)
            .sync(input: input(at: now), settings: settings, enabledOnDevice: true,
                  haptic: true, now: now, calendar: calendar)
        await WaterNudgeScheduler(client: phone, defaultsSuiteName: phoneStorage)
            .sync(input: input(at: now), settings: settings, enabledOnDevice: true,
                  haptic: false, now: now, calendar: calendar)
        #expect(await watch.added().allSatisfy(\.haptic))
        #expect(await phone.added().allSatisfy { !$0.haptic })
    }

    @Test func nativeRequestsUseActiveWatchAndPassiveSilentPhonePresentation() throws {
        let item = WaterNudgePlanItem(identifier: "water.nudge.2026-10-12.0", fireDate: date(hour: 12),
                                     title: "A little water break?", body: "A small drink can help.")
        let watch = SystemWaterNudgeNotificationClient.request(for: item, haptic: true)
        let phone = SystemWaterNudgeNotificationClient.request(for: item, haptic: false)
        #expect(watch.content.interruptionLevel == .active)
        #expect(watch.content.sound == UNNotificationSound.default)
        #expect(phone.content.interruptionLevel == .passive)
        #expect(phone.content.sound == nil)
        #expect(watch.content.threadIdentifier == "water.nudge")
        #expect(watch.identifier == item.identifier)
        let trigger = try #require(watch.trigger as? UNCalendarNotificationTrigger)
        #expect(!trigger.repeats)
        #expect(trigger.dateComponents.timeZone == TimeZone.current)
        #expect(Calendar.current.date(from: trigger.dateComponents) == item.fireDate)
    }

    @Test func changedWindowKeepsThreeHoursAfterAConsumedSlot() async throws {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await scheduler.sync(input: input(at: now), settings: settings,
                             enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        let initial = await client.pending()
        let spent = try #require(initial.filter { calendar.isDate($0.fireDate, inSameDayAs: now) }.min { $0.fireDate < $1.fireDate })
        let later = spent.fireDate.addingTimeInterval(60)
        await client.seed(initial.filter { $0.identifier != spent.identifier })
        await scheduler.sync(input: input(at: later), settings: WaterNudgeSettings(isEnabled: true, startHour: 6, endHour: 19),
                             enabledOnDevice: true, haptic: true, now: later, calendar: calendar)
        #expect(await client.pending().allSatisfy { $0.fireDate >= spent.fireDate.addingTimeInterval(3 * 3_600) })
    }

    @Test func newerDisableWinsEvenWhenOlderAddCompletesLate() async {
        let client = Client()
        let storage = suite()
        defer { clear(storage) }
        let now = date()
        let scheduler = WaterNudgeScheduler(client: client, defaultsSuiteName: storage)
        await client.holdNextAdd()
        let initial = Task {
            await scheduler.sync(input: input(at: now), settings: settings,
                                 enabledOnDevice: true, haptic: true, now: now, calendar: calendar)
        }
        await client.waitUntilAddIsPaused()
        let disabled = Task {
            await scheduler.sync(input: input(at: now), settings: settings,
                                 enabledOnDevice: false, haptic: true, now: now, calendar: calendar)
        }
        // Await acceptance, rather than relying on timing, before completing the older system add.
        while await scheduler.revision < 2 { await Task.yield() }
        await client.resumeAdd()
        await initial.value
        await disabled.value
        #expect(await client.pending().isEmpty)
        #expect(await client.added().count == 1)
    }
}
