import Foundation

/// A civil day survives delayed delivery across midnight without becoming "today" again.
nonisolated struct GlowWatchDay: Codable, Hashable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year ?? 0
        month = parts.month ?? 0
        day = parts.day ?? 0
    }

    func date(calendar: Calendar = .current) -> Date? {
        guard let result = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self(date: result, calendar: calendar) == self else { return nil }
        return calendar.startOfDay(for: result)
    }
}

nonisolated struct GlowWatchHabit: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let iconName: String
    let weekdays: Set<Int>
    let completed: Bool

    func isScheduled(on date: Date, calendar: Calendar = .current) -> Bool {
        weekdays.contains(calendar.component(.weekday, from: date))
    }
}

nonisolated struct GlowWatchCommand: Codable, Equatable, Sendable {
    let id: UUID
    let clientID: UUID
    let sequence: UInt64
    let habitID: String
    let day: GlowWatchDay
    let completed: Bool

    var receiptKey: String {
        "\(clientID.uuidString)|\(habitID)|\(day.year)-\(day.month)-\(day.day)"
    }
}

nonisolated struct GlowWatchReceipt: Codable, Equatable, Sendable {
    let command: GlowWatchCommand
    let rejection: String?
}

nonisolated struct GlowWatchSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let day: GlowWatchDay
    let habits: [GlowWatchHabit]
    let receipts: [GlowWatchReceipt]
}

nonisolated struct GlowWatchPacket: Codable, Sendable {
    var version = 1
    let body: Body

    enum Body: Codable, Sendable {
        case requestSnapshot
        case snapshot(GlowWatchSnapshot)
        case completion(GlowWatchCommand)
    }

    static let payloadKey = "glowWatchPayload"

    func data() throws -> Data { try JSONEncoder().encode(self) }

    static func decode(_ data: Data) -> Self? {
        guard let packet = try? JSONDecoder().decode(Self.self, from: data),
              packet.version == 1 else { return nil }
        return packet
    }
}

nonisolated struct GlowWatchState: Codable, Sendable {
    var clientID = UUID()
    var nextSequence: UInt64 = 1
    var revision: UInt64 = 0
    var snapshot: GlowWatchSnapshot?
    var pending: [GlowWatchCommand] = []
    var syncError: String?

    func isCompleted(_ habitID: String, on day: GlowWatchDay) -> Bool {
        if let command = pending.last(where: { $0.habitID == habitID && $0.day == day }) {
            return command.completed
        }
        guard snapshot?.day == day else { return false }
        return snapshot?.habits.first(where: { $0.id == habitID })?.completed ?? false
    }

    mutating func setCompleted(_ completed: Bool, habitID: String, day: GlowWatchDay) {
        // Only the latest intent for a habit/day needs to survive locally. Receipt sequences
        // prevent an older in-flight packet from replacing this intent on the phone.
        pending.removeAll { $0.habitID == habitID && $0.day == day }
        pending.append(GlowWatchCommand(
            id: UUID(), clientID: clientID, sequence: nextSequence,
            habitID: habitID, day: day, completed: completed
        ))
        nextSequence += 1
        revision += 1
        syncError = nil
    }

    mutating func receive(_ incoming: GlowWatchSnapshot) {
        // Acknowledgements can arrive via both the foreground and background routes.
        // Accept them even when their accompanying display snapshot is older.
        pending.removeAll { command in
            guard let receipt = incoming.receipts.first(where: {
                $0.command.receiptKey == command.receiptKey && $0.command.sequence >= command.sequence
            }) else { return false }
            if let rejection = receipt.rejection { syncError = rejection }
            return true
        }
        if incoming.generatedAt >= (snapshot?.generatedAt ?? .distantPast) {
            snapshot = incoming
        }
        revision += 1
    }
}
