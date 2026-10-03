import Foundation
import WatchConnectivity
import OSLog
// Xcode's app metadata phase requires the system metadata framework to be linked.
import AppIntents

nonisolated enum GlowWatchTransportEvent: Sendable {
    case activated
    case reachabilityChanged
    case packet(GlowWatchPacket)
}

/// Delegate callbacks carry immutable, Sendable packets to the app's state owner.
/// No SwiftData objects or UI state cross the WatchConnectivity callback queue.
nonisolated final class GlowWatchTransport: NSObject, WCSessionDelegate {
    private let session: WCSession
    private let receive: @Sendable (GlowWatchTransportEvent) -> Void
    private let logger = Logger(subsystem: "movie.Glow", category: "WatchConnectivity")

    init(receive: @escaping @Sendable (GlowWatchTransportEvent) -> Void) {
        session = .default
        self.receive = receive
        super.init()
    }

    var isReachable: Bool { session.activationState == .activated && session.isReachable }
    var hasContentPending: Bool { session.hasContentPending }

    func activate() {
        session.delegate = self
        session.activate()
    }

    func send(_ packet: GlowWatchPacket, durable: Bool = false) {
        guard session.activationState == .activated,
              let data = try? packet.data() else { return }
        let payload: [String: Any] = [GlowWatchPacket.payloadKey: data]
        if isReachable {
            session.sendMessage(payload, replyHandler: nil) { [logger] error in
                logger.error("Foreground transfer failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if durable {
            if case .completion(let command) = packet.body {
                let alreadyQueued = session.outstandingUserInfoTransfers.contains { transfer in
                    guard let existingData = transfer.userInfo[GlowWatchPacket.payloadKey] as? Data,
                          let existing = GlowWatchPacket.decode(existingData),
                          case .completion(let queued) = existing.body else { return false }
                    return queued.id == command.id
                }
                guard !alreadyQueued else { return }
            }
            session.transferUserInfo(payload)
        }
    }

    func publish(_ snapshot: GlowWatchSnapshot) {
        guard session.activationState == .activated,
              let data = try? GlowWatchPacket(body: .snapshot(snapshot)).data() else { return }
        do {
            try session.updateApplicationContext([GlowWatchPacket.payloadKey: data])
            send(GlowWatchPacket(body: .snapshot(snapshot)))
        } catch {
            logger.error("Snapshot transfer failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            logger.error("Activation failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard activationState == .activated else { return }
        receive(.activated)
        decode(session.receivedApplicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) { receive(.reachabilityChanged) }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) { decode(message) }
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) { decode(applicationContext) }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) { decode(userInfo) }

    private func decode(_ payload: [String: Any]) {
        guard let data = payload[GlowWatchPacket.payloadKey] as? Data,
              let packet = GlowWatchPacket.decode(data) else { return }
        receive(.packet(packet))
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionWatchStateDidChange(_ session: WCSession) { receive(.activated) }
    #endif
}
