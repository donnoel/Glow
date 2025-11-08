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
