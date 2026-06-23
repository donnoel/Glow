import Foundation
import SwiftData

extension ModelContext {
    /// Saves the context and prints errors in debug so failures aren't silent.
    func saveSafely(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try self.save()
        } catch {
            #if DEBUG
            print("⚠️ SwiftData save failed at \(file):\(line) – \(error)")
            #endif
        }
    }

    @discardableResult
    func saveSafelyReturningSuccess(file: StaticString = #fileID, line: UInt = #line) -> Bool {
        do {
            try self.save()
            return true
        } catch {
            #if DEBUG
            print("⚠️ SwiftData save failed at \(file):\(line) – \(error)")
            #endif
            return false
        }
    }
}

@MainActor
enum HabitArchiveAction {
    @discardableResult
    static func setArchived(_ isArchived: Bool, for habit: Habit, in context: ModelContext) -> Bool {
        habit.isArchived = isArchived

        guard context.saveSafelyReturningSuccess() else {
            context.rollback()
            return false
        }

        let notificationSnapshot = NotificationScheduleSnapshot(habit: habit)
        Task {
            await NotificationManager.syncAfterArchiveStateChange(for: notificationSnapshot)
        }
        NotificationCenter.default.post(name: .glowDataDidChange, object: nil)
        return true
    }
}
