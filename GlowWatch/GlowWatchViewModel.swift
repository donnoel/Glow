import SwiftUI
import Combine
import WatchConnectivity
import WatchKit
import OSLog

@MainActor
final class GlowWatchViewModel: ObservableObject {
    @Published private(set) var state = GlowWatchState()
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var phoneReachable = false
    @Published private(set) var waterNotificationStatus: WaterNudgeAuthorizationStatus = .notDetermined
    @Published private(set) var isRequestingWaterPermission = false
    private let store: GlowWatchStore
    private let waterNudgeScheduler = WaterNudgeScheduler()
    private var waterNudgeSyncTask: Task<Void, Never>?
    private var waterNudgeSyncRevision: UInt64 = 0
    private var transport: GlowWatchTransport?
    private var started = false
    private var activeDeliveries = 0
    private let logger = Logger(subsystem: "movie.Glow.watchkitapp", category: "WatchSync")

    init() {
        let root = URL.applicationSupportDirectory.appendingPathComponent("GlowWatch", isDirectory: true)
        store = GlowWatchStore(url: root.appendingPathComponent("state.json"))
    }

    func start() async {
        guard !started else { refresh(); return }
        started = true
        do { accept(try await store.load()) }
        catch { errorMessage = "Couldn't load your saved check-ins. Please try reopening Glow."; return }
        await waterNudgeSyncTask?.value
        guard WCSession.isSupported() else { return }
        let connection = GlowWatchTransport { [weak self] event in
            Task { @MainActor [weak self] in await self?.receive(event) }
        }
        transport = connection
        connection.activate()
    }

    func refresh() {
        phoneReachable = transport?.isReachable ?? false
        requestWaterNudgeSync()
        transport?.send(GlowWatchPacket(body: .requestSnapshot))
        for command in state.pending {
            transport?.send(GlowWatchPacket(body: .completion(command)), durable: true)
        }
        for command in state.pendingWater {
            transport?.send(GlowWatchPacket(body: .water(command)), durable: true)
        }
    }

    var waterNudgesEnabled: Bool {
        state.snapshot?.water?.nudges?.isEnabled == true
    }

    func enableWaterTaps() async {
        guard waterNudgesEnabled, !isRequestingWaterPermission else { return }
        isRequestingWaterPermission = true
        defer { isRequestingWaterPermission = false }
        do {
            _ = try await WaterNudgeAuthorization.request()
            waterNotificationStatus = await WaterNudgeAuthorization.status()
            requestWaterNudgeSync()
        } catch {
            errorMessage = "Couldn't enable water taps. Please try again."
        }
    }

    func setCompleted(_ completed: Bool, habitID: String, day: GlowWatchDay) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            accept(try await store.setCompleted(completed, habitID: habitID, day: day))
            errorMessage = nil
            WKInterfaceDevice.current().play(completed ? .success : .click)
            refresh()
        } catch {
            errorMessage = "Couldn't save this check-in. Please try again."
            logger.error("Local save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func addWater(ounces: Int) async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            accept(try await store.addWater(WaterUnit.ounces.milliliters(from: Double(ounces)), at: Date()))
            errorMessage = nil
            WKInterfaceDevice.current().play(.click)
            refresh()
            await waterNudgeSyncTask?.value
        } catch {
            errorMessage = "Couldn't save this drink. Please try again."
            logger.error("Local water save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func undoWater() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            accept(try await store.undoWater(on: GlowWatchDay.waterDay(date: Date())))
            errorMessage = nil
            WKInterfaceDevice.current().play(.click)
            refresh()
            await waterNudgeSyncTask?.value
        } catch {
            errorMessage = "Couldn't undo this drink. Please try again."
        }
    }

    func handleBackgroundDelivery() async {
        await start()
        // Let delegate events reach the actor before deciding the background task is done.
        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            if transport?.hasContentPending != true && activeDeliveries == 0 && waterNudgeSyncTask == nil { return }
        }
        await waterNudgeSyncTask?.value
    }

    private func receive(_ event: GlowWatchTransportEvent) async {
        switch event {
        case .activated, .reachabilityChanged: refresh()
        case .packet(let packet):
            guard case .snapshot(let snapshot) = packet.body else { return }
            activeDeliveries += 1
            defer { activeDeliveries -= 1 }
            do {
                accept(try await store.receive(snapshot))
                await waterNudgeSyncTask?.value
                logger.info("Received \(snapshot.habits.count) habits; \(self.state.pending.count) check-ins pending.")
            } catch {
                errorMessage = "Couldn't save the latest habits. Please try again."
            }
        }
    }

    private func accept(_ updated: GlowWatchState) {
        guard updated.revision >= state.revision else { return }
        state = updated
        requestWaterNudgeSync()
    }

    private func requestWaterNudgeSync() {
        waterNudgeSyncRevision += 1
        guard waterNudgeSyncTask == nil else { return }
        waterNudgeSyncTask = Task { [weak self] in
            await self?.syncWaterNudges()
        }
    }

    private func syncWaterNudges() async {
        // Coalesce local changes and incoming snapshots. If an update arrives while
        // the system is scheduling, immediately replace it with the newest totals.
        while !Task.isCancelled {
            let revision = waterNudgeSyncRevision
            let now = Date()
            let day = GlowWatchDay.waterDay(date: now)
            let water = state.snapshot?.water
            let settings = water?.nudges ?? WaterNudgeSettings()
            let hasToday = water?.day == day || state.pendingWater.contains { $0.day == day }
            let input: WaterNudgeInput?
            if hasToday, let goal = state.waterGoal(on: day), WaterUnit.isValidAmount(goal) {
                input = WaterNudgeInput(
                    day: day, totalMilliliters: state.waterTotal(on: day), goalMilliliters: goal,
                    lastDrinkAt: state.waterLastDrink(on: day),
                    unit: WaterUnit(rawValue: water?.unitRaw ?? "") ?? .ounces
                )
            } else {
                // Yesterday's cached intake cannot stand in for today's drinking.
                input = nil
            }
            let authorization = await WaterNudgeAuthorization.status()
            guard revision == waterNudgeSyncRevision else { continue }
            waterNotificationStatus = authorization
            await waterNudgeScheduler.sync(
                input: input, settings: settings, enabledOnDevice: authorization == .authorized,
                haptic: true, now: now, nextGoalMilliliters: water?.nextGoalMilliliters
            )
            if revision == waterNudgeSyncRevision { break }
        }
        waterNudgeSyncTask = nil
    }
}
