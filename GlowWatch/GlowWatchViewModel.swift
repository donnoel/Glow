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
    private let store: GlowWatchStore
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
        guard WCSession.isSupported() else { return }
        let connection = GlowWatchTransport { [weak self] event in
            Task { @MainActor [weak self] in await self?.receive(event) }
        }
        transport = connection
        connection.activate()
    }

    func refresh() {
        phoneReachable = transport?.isReachable ?? false
        transport?.send(GlowWatchPacket(body: .requestSnapshot))
        for command in state.pending {
            transport?.send(GlowWatchPacket(body: .completion(command)), durable: true)
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

    func handleBackgroundDelivery() async {
        await start()
        // Let delegate events reach the actor before deciding the background task is done.
        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            if transport?.hasContentPending != true && activeDeliveries == 0 { return }
        }
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
                logger.info("Received \(snapshot.habits.count) habits; \(self.state.pending.count) check-ins pending.")
            } catch {
                errorMessage = "Couldn't save the latest habits. Please try again."
            }
        }
    }

    private func accept(_ updated: GlowWatchState) {
        guard updated.revision >= state.revision else { return }
        state = updated
    }
}
