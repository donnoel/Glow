import Foundation
import SwiftData
import Testing
@testable import Glow

@MainActor
struct WatchCompanionTests {
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private func snapshot(at date: Date, completed: Bool = false, receipts: [GlowWatchReceipt] = []) -> GlowWatchSnapshot {
        GlowWatchSnapshot(
            generatedAt: date, day: GlowWatchDay(date: date),
            habits: [GlowWatchHabit(id: "habit", title: "Read", iconName: "book", weekdays: Set(1...7), completed: completed)],
            receipts: receipts
        )
    }

    @Test func offlineCompletionAndUndoKeepOnlyLatestIntent() {
        let day = GlowWatchDay(date: today)
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.setCompleted(true, habitID: "habit", day: day)
        let first = state.pending[0]
        state.setCompleted(false, habitID: "habit", day: day)
        #expect(state.pending.count == 1)
        #expect(state.pending[0].sequence > first.sequence)
        #expect(!state.isCompleted("habit", on: day))
        // A late acknowledgement for Done must not remove the newer Undo.
        state.receive(snapshot(at: today.addingTimeInterval(1), completed: true,
                               receipts: [GlowWatchReceipt(command: first, rejection: nil)]))
        #expect(state.pending.count == 1)
        #expect(!state.isCompleted("habit", on: day))
    }

    @Test func acknowledgementClearsOutboxWithoutAcceptingOlderDisplayData() {
        let day = GlowWatchDay(date: today)
        var state = GlowWatchState()
        state.setCompleted(true, habitID: "habit", day: day)
        let command = state.pending[0]
        state.receive(snapshot(at: today.addingTimeInterval(10), completed: true))
        state.receive(snapshot(at: today, completed: false,
                               receipts: [GlowWatchReceipt(command: command, rejection: nil)]))
        #expect(state.pending.isEmpty)
        #expect(state.isCompleted("habit", on: day))
    }

    @Test func midnightDoesNotCarryYesterdayCompletionForward() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        var state = GlowWatchState()
        state.receive(snapshot(at: today, completed: true))
        state.setCompleted(true, habitID: "habit", day: GlowWatchDay(date: today))
        #expect(!state.isCompleted("habit", on: GlowWatchDay(date: tomorrow)))
        #expect(state.pending[0].day == GlowWatchDay(date: today))
    }

    @Test func rejectedChangeRemovesOptimisticCompletionAndExplainsFailure() {
        let day = GlowWatchDay(date: today)
        var state = GlowWatchState()
        state.receive(snapshot(at: today))
        state.setCompleted(true, habitID: "habit", day: day)
        state.receive(snapshot(at: today, receipts: [GlowWatchReceipt(command: state.pending[0], rejection: "Habit was archived")]))
        #expect(state.pending.isEmpty)
        #expect(!state.isCompleted("habit", on: day))
        #expect(state.syncError == "Habit was archived")
    }

    @Test func pendingChangesSurviveRelaunchAndAcknowledgement() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("state.json")
        let first = GlowWatchStore(url: url)
        _ = try await first.receive(snapshot(at: today))
        let saved = try await first.setCompleted(true, habitID: "habit", day: GlowWatchDay(date: today))
        let relaunched = GlowWatchStore(url: url)
        let restored = try await relaunched.load()
        #expect(restored.pending == saved.pending)
        #expect(restored.clientID == saved.clientID)
        let acknowledged = try await relaunched.receive(snapshot(at: today, completed: true,
            receipts: [GlowWatchReceipt(command: restored.pending[0], rejection: nil)]))
        #expect(acknowledged.pending.isEmpty)
        let again = GlowWatchStore(url: url)
        #expect(try await again.load().pending.isEmpty)
    }

    @Test func corruptLocalStateIsNotOverwritten() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("state.json")
        let original = Data("invalid state".utf8)
        try original.write(to: url)
        let store = GlowWatchStore(url: url)
        await #expect(throws: (any Error).self) {
            try await store.setCompleted(true, habitID: "habit", day: GlowWatchDay(date: self.today))
        }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func explicitCompletionIsIdempotentAndKeepsDelayedDay() throws {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let container = try ModelContainer(for: Habit.self, HabitLog.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let context = container.mainContext
        let habit = Habit(title: "Read")
        context.insert(habit)
        HabitCompletionAction.setCompleted(true, for: habit, on: yesterday, in: context)
        HabitCompletionAction.setCompleted(true, for: habit, on: yesterday, in: context)
        try context.save()
        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.completed == true)
        #expect(habit.logs?.first?.date == yesterday)
        HabitCompletionAction.setCompleted(false, for: habit, on: yesterday, in: context)
        try context.save()
        #expect(habit.logs?.count == 1)
        #expect(habit.logs?.first?.completed == false)
    }

    @Test func invalidCivilDatesAndUnsupportedPacketsAreRejected() throws {
        let invalid = try JSONDecoder().decode(GlowWatchDay.self, from: Data("{\"year\":2026,\"month\":2,\"day\":30}".utf8))
        #expect(invalid.date() == nil)
        var packet = GlowWatchPacket(body: .requestSnapshot)
        packet.version = 2
        #expect(GlowWatchPacket.decode(try packet.data()) == nil)
    }
}
