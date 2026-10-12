import Foundation
import SwiftData
import WatchConnectivity
import UIKit
import Combine
import CoreData
import OSLog

private actor GlowWatchReceiptStore<Receipt: Codable & Sendable> {
    private let url: URL
    private var receipts: [String: Receipt]?

    init(url: URL) { self.url = url }

    func load() throws -> [String: Receipt] {
        if let receipts { return receipts }
        let loaded: [String: Receipt]
        if FileManager.default.fileExists(atPath: url.path) {
            loaded = try JSONDecoder().decode([String: Receipt].self, from: Data(contentsOf: url))
        } else {
            loaded = [:]
        }
        receipts = loaded
        return loaded
    }

    func record(_ receipt: Receipt, key: String) throws -> [String: Receipt] {
        var updated = try load()
        updated[key] = receipt
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
    private let receiptStore: GlowWatchReceiptStore<GlowWatchReceipt>
    private let waterReceiptStore: GlowWatchReceiptStore<GlowWatchWaterReceipt>
    private var receipts: [String: GlowWatchReceipt] = [:]
    private var waterReceipts: [String: GlowWatchWaterReceipt] = [:]
    private var transport: GlowWatchTransport?
    private var subscriptions: Set<AnyCancellable> = []
    private var commands: [GlowWatchPacket.Body] = []
    private var processing: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "movie.Glow", category: "WatchSync")

    init(container: ModelContainer) {
        context = container.mainContext
        let root = URL.applicationSupportDirectory.appendingPathComponent("GlowWatch", isDirectory: true)
        receiptStore = GlowWatchReceiptStore(url: root.appendingPathComponent("receipts.json"))
        waterReceiptStore = GlowWatchReceiptStore(url: root.appendingPathComponent("water-receipts.json"))
    }

    func start() {
        guard transport == nil, WCSession.isSupported(),
              !ProcessInfo.processInfo.arguments.contains("--uitesting") else { return }
        let connection = GlowWatchTransport { [weak self] event in
            Task { @MainActor [weak self] in self?.receive(event) }
        }
        transport = connection
        for name in [ModelContext.didSave, .glowDataDidChange,
                     .NSPersistentStoreRemoteChange,
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
            case .completion, .water:
                commands.append(packet.body)
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
                    switch command {
                    case .completion(let habit):
                        receipts = try await receiptStore.load()
                        if receipts[habit.receiptKey].map({ $0.command.sequence < habit.sequence }) ?? true {
                            let rejection = try apply(habit)
                            receipts = try await receiptStore.record(GlowWatchReceipt(command: habit, rejection: rejection), key: habit.receiptKey)
                        }
                        try publishSnapshot(acknowledging: habit)
                    case .water(let drink):
                        waterReceipts = try await waterReceiptStore.load()
                        if waterReceipts[drink.receiptKey].map({ $0.command.sequence < drink.sequence }) ?? true {
                            let rejection = try WatchWaterAction.apply(drink, in: context)
                            waterReceipts = try await waterReceiptStore.record(GlowWatchWaterReceipt(command: drink, rejection: rejection), key: drink.receiptKey)
                            NotificationCenter.default.post(name: .glowDataDidChange, object: nil)
                        }
                        try publishSnapshot(waterCommand: drink)
                    case .requestSnapshot, .snapshot: break
                    }
                } catch {
                    // No acknowledgement on failure: the durable Watch outbox retries on activation.
                    logger.error("Watch delivery failed: \(error.localizedDescription, privacy: .public)")
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
                waterReceipts = try await waterReceiptStore.load()
                try publishSnapshot()
            } catch is CancellationError {
                return
            } catch {
                self?.logger.error("Snapshot failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func publishSnapshot(acknowledging command: GlowWatchCommand? = nil,
                                 waterCommand: GlowWatchWaterCommand? = nil) throws {
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
        var recentWaterReceipts = Array(waterReceipts.values.sorted { $0.command.sequence > $1.command.sequence }.prefix(64))
        if let waterCommand, let receipt = waterReceipts[waterCommand.receiptKey],
           !recentWaterReceipts.contains(where: { $0.command.receiptKey == waterCommand.receiptKey }) {
            recentWaterReceipts.append(receipt)
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
            receipts: recentReceipts,
            water: try WatchWaterAction.snapshot(in: context, now: now, receipts: recentWaterReceipts)
        )
        transport?.publish(snapshot)
        if command != nil || waterCommand != nil { transport?.send(GlowWatchPacket(body: .snapshot(snapshot)), durable: true) }
        logger.info("Published Watch snapshot with \(snapshot.habits.count) active habits.")
    }
}
