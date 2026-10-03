import Foundation
import SwiftData
import WatchConnectivity
import UIKit
import Combine
import OSLog

private actor GlowWatchReceiptStore {
    private let url: URL
    private var receipts: [String: GlowWatchReceipt]?

    init(url: URL) { self.url = url }

    func load() throws -> [String: GlowWatchReceipt] {
        if let receipts { return receipts }
        let loaded: [String: GlowWatchReceipt]
        if FileManager.default.fileExists(atPath: url.path) {
            loaded = try JSONDecoder().decode([String: GlowWatchReceipt].self, from: Data(contentsOf: url))
        } else {
            loaded = [:]
        }
        receipts = loaded
        return loaded
    }

    func record(_ receipt: GlowWatchReceipt) throws -> [String: GlowWatchReceipt] {
        var updated = try load()
        updated[receipt.command.receiptKey] = receipt
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: url, options: .atomic)
        receipts = updated
        return updated
    }
}

/// Main-actor ownership is required by the app's SwiftData context and widget/UI refresh.
@MainActor
final class GlowPhoneWatchSync {
    private let context: ModelContext
    private let receiptStore: GlowWatchReceiptStore
    private var receipts: [String: GlowWatchReceipt] = [:]
    private var transport: GlowWatchTransport?
    private var subscriptions: Set<AnyCancellable> = []
    private var commands: [GlowWatchCommand] = []
    private var processing: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "movie.Glow", category: "WatchSync")

    init(container: ModelContainer) {
        context = container.mainContext
        let root = URL.applicationSupportDirectory.appendingPathComponent("GlowWatch", isDirectory: true)
        receiptStore = GlowWatchReceiptStore(url: root.appendingPathComponent("receipts.json"))
    }

    func start() {
        guard transport == nil, WCSession.isSupported(),
              !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        let connection = GlowWatchTransport { [weak self] event in
            Task { @MainActor [weak self] in self?.receive(event) }
        }
        transport = connection
        for name in [ModelContext.didSave, .glowDataDidChange,
                     UIApplication.didBecomeActiveNotification, UIApplication.significantTimeChangeNotification] {
            NotificationCenter.default.publisher(for: name).sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.scheduleSnapshot() }
            }.store(in: &subscriptions)
        }
        connection.activate()
    }

    private func receive(_ event: GlowWatchTransportEvent) {
        switch event {
        case .activated, .reachabilityChanged:
            scheduleSnapshot()
        case .packet(let packet):
            switch packet.body {
            case .requestSnapshot: scheduleSnapshot()
            case .completion(let command):
                commands.append(command)
                processCommands()
            case .snapshot: break
            }
        }
    }

    private func processCommands() {
        guard processing == nil else { return }
        processing = Task { [weak self] in
            guard let self else { return }
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Glow Watch check-in") { [weak self] in
                Task { @MainActor [weak self] in self?.processing?.cancel() }
            }
            defer {
                if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask) }
                processing = nil
            }
            while !commands.isEmpty && !Task.isCancelled {
                let command = commands.removeFirst()
                do {
                    receipts = try await receiptStore.load()
                    if let previous = receipts[command.receiptKey], previous.command.sequence >= command.sequence {
                        try publishSnapshot(acknowledging: command)
                        continue
                    }
                    let rejection = try apply(command)
                    receipts = try await receiptStore.record(GlowWatchReceipt(command: command, rejection: rejection))
                    try publishSnapshot(acknowledging: command)
                } catch {
                    // No acknowledgement on failure: the durable Watch outbox retries on activation.
                    logger.error("Completion delivery failed: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func apply(_ command: GlowWatchCommand) throws -> String? {
        guard let day = command.day.date(), day <= Calendar.current.startOfDay(for: Date()) else {
            return "This check-in has an invalid date. Please check your Watch clock."
        }
        let habitID = command.habitID
        let descriptor = FetchDescriptor<Habit>(predicate: #Predicate { $0.id == habitID })
        guard let habit = try context.fetch(descriptor).first, !habit.isArchived else {
            return "This habit is no longer available. Refresh Glow on your iPhone."
        }
        HabitCompletionAction.setCompleted(command.completed, for: habit, on: day, in: context)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        let habits = try context.fetch(FetchDescriptor<Habit>())
        let home = HomeViewModel()
        home.updateHabits(habits)
        home.syncProgressToWidget()
        NotificationCenter.default.post(name: .glowDataDidChange, object: nil)
        logger.info("Saved Watch check-in for the requested day.")
        return nil
    }

    private func scheduleSnapshot() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(150))
                guard let self else { return }
                receipts = try await receiptStore.load()
                try publishSnapshot()
            } catch is CancellationError {
                return
            } catch {
                self?.logger.error("Snapshot failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func publishSnapshot(acknowledging command: GlowWatchCommand? = nil) throws {
        let now = Date()
        let habits = try context.fetch(FetchDescriptor<Habit>())
            .filter { !$0.isArchived }
            .sorted { $0.sortOrder == $1.sortOrder ? $0.title < $1.title : $0.sortOrder < $1.sortOrder }
        // Keep the context packet small. A retry for an older queued day gets its
        // own receipt included, even when it is outside the recent receipt window.
        var recentReceipts = Array(receipts.values.sorted { $0.command.sequence > $1.command.sequence }.prefix(64))
        if let command, let receipt = receipts[command.receiptKey],
           !recentReceipts.contains(where: { $0.command.receiptKey == command.receiptKey }) {
            recentReceipts.append(receipt)
        }
        let snapshot = GlowWatchSnapshot(
            generatedAt: now, day: GlowWatchDay(date: now),
            habits: habits.map { habit in
                GlowWatchHabit(
                    id: habit.id, title: habit.title, iconName: habit.iconName,
                    weekdays: habit.schedule.kind == .daily ? Set(1...7) : Set(habit.schedule.days.map(\.rawValue)),
                    completed: (habit.logs ?? []).contains { $0.completed && Calendar.current.isDate($0.date, inSameDayAs: now) }
                )
            },
            receipts: recentReceipts
        )
        transport?.publish(snapshot)
        if command != nil { transport?.send(GlowWatchPacket(body: .snapshot(snapshot)), durable: true) }
        logger.info("Published Watch snapshot with \(snapshot.habits.count) active habits.")
    }
}
