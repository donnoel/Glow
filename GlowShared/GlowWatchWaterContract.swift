import Foundation

nonisolated struct GlowWatchWaterEntry: Codable, Equatable, Sendable {
    let id: UUID
    let milliliters: Double
    let timestamp: Date?

    init(id: UUID, milliliters: Double, timestamp: Date? = nil) {
        self.id = id
        self.milliliters = milliliters
        self.timestamp = timestamp
    }
}

/// Each drink has its own ID. Retrying a delivery must never add another drink.
nonisolated struct GlowWatchWaterCommand: Codable, Equatable, Sendable {
    let id: UUID
    let clientID: UUID
    let sequence: UInt64
    let entryID: UUID
    let day: GlowWatchDay
    let timestamp: Date
    let milliliters: Double
    let goalMilliliters: Double
    let isDeleted: Bool

    var receiptKey: String { "\(clientID.uuidString)|water|\(entryID.uuidString)" }
}

nonisolated struct GlowWatchWaterReceipt: Codable, Equatable, Sendable {
    let command: GlowWatchWaterCommand
    let rejection: String?
}

nonisolated struct GlowWatchWaterSnapshot: Codable, Equatable, Sendable {
    let day: GlowWatchDay
    let entries: [GlowWatchWaterEntry]
    let goalMilliliters: Double
    let nextGoalMilliliters: Double
    let receipts: [GlowWatchWaterReceipt]
    let nudges: WaterNudgeSettings?
    let unitRaw: String?

    init(
        day: GlowWatchDay, entries: [GlowWatchWaterEntry], goalMilliliters: Double,
        nextGoalMilliliters: Double, receipts: [GlowWatchWaterReceipt],
        nudges: WaterNudgeSettings? = nil, unitRaw: String? = nil
    ) {
        self.day = day
        self.entries = entries
        self.goalMilliliters = goalMilliliters
        self.nextGoalMilliliters = nextGoalMilliliters
        self.receipts = receipts
        self.nudges = nudges
        self.unitRaw = unitRaw
    }
}

extension GlowWatchDay {
    nonisolated static func waterDay(date: Date, timeZone: TimeZone = .current) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return Self(date: date, calendar: calendar)
    }

    nonisolated var waterDayKey: String { String(format: "%04d-%02d-%02d", year, month, day) }

    nonisolated func waterDate(timeZone: TimeZone = .current) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return date(calendar: calendar)
    }
}

extension GlowWatchState {
    nonisolated func waterLastDrink(on day: GlowWatchDay) -> Date? {
        var timestamps: [UUID: Date] = [:]
        if let water = snapshot?.water, water.day == day {
            for entry in water.entries where WaterUnit.isValidAmount(entry.milliliters) {
                timestamps[entry.id] = entry.timestamp
            }
        }
        for command in pendingWater where command.day == day {
            timestamps[command.entryID] = command.isDeleted ? nil : command.timestamp
        }
        return timestamps.values.max()
    }

    nonisolated func waterTotal(on day: GlowWatchDay) -> Double {
        var amounts: [UUID: Double] = [:]
        if let water = snapshot?.water, water.day == day {
            for entry in water.entries where WaterUnit.isValidAmount(entry.milliliters) {
                amounts[entry.id] = entry.milliliters
            }
        }
        for command in pendingWater where command.day == day {
            amounts[command.entryID] = command.isDeleted ? nil : command.milliliters
        }
        return amounts.values.reduce(0, +)
    }

    nonisolated func waterGoal(on day: GlowWatchDay) -> Double? {
        guard let water = snapshot?.water else { return nil }
        if water.day == day, !water.entries.isEmpty { return water.goalMilliliters }
        if let first = pendingWater.first(where: { $0.day == day }) {
            return first.goalMilliliters
        }
        return water.day == day ? water.goalMilliliters : water.nextGoalMilliliters
    }

    nonisolated mutating func addWater(_ milliliters: Double, at date: Date) {
        let day = GlowWatchDay.waterDay(date: date)
        guard WaterUnit.isValidAmount(milliliters), let goal = waterGoal(on: day) else { return }
        let command = GlowWatchWaterCommand(
            id: UUID(), clientID: clientID, sequence: nextSequence, entryID: UUID(),
            day: day, timestamp: date, milliliters: milliliters, goalMilliliters: goal, isDeleted: false
        )
        pendingWater.append(command)
        lastWaterEntry = command
        nextSequence += 1
        revision += 1
        syncError = nil
    }

    nonisolated mutating func undoWater(on day: GlowWatchDay) {
        guard let last = lastWaterEntry, last.day == day else { return }
        pendingWater.removeAll { $0.entryID == last.entryID }
        pendingWater.append(GlowWatchWaterCommand(
            id: UUID(), clientID: clientID, sequence: nextSequence, entryID: last.entryID,
            day: last.day, timestamp: last.timestamp, milliliters: last.milliliters,
            goalMilliliters: last.goalMilliliters, isDeleted: true
        ))
        lastWaterEntry = nil
        nextSequence += 1
        revision += 1
        syncError = nil
    }

    nonisolated mutating func receiveWater(_ water: GlowWatchWaterSnapshot?) {
        guard let water else { return }
        pendingWater.removeAll { command in
            guard let receipt = water.receipts.first(where: {
                $0.command.receiptKey == command.receiptKey && $0.command.sequence >= command.sequence
            }) else { return false }
            if let rejection = receipt.rejection {
                syncError = rejection
                if lastWaterEntry?.entryID == command.entryID { lastWaterEntry = nil }
            }
            return true
        }
    }
}
