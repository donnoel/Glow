import Foundation

/// Owns the complete read/update/atomic-write transaction, not just the file replacement.
actor GlowWatchStore {
    private let url: URL
    private var state: GlowWatchState?

    init(url: URL) { self.url = url }

    func load() throws -> GlowWatchState {
        if let state { return state }
        let loaded: GlowWatchState
        if FileManager.default.fileExists(atPath: url.path) {
            loaded = try JSONDecoder().decode(GlowWatchState.self, from: Data(contentsOf: url))
        } else {
            loaded = GlowWatchState()
        }
        state = loaded
        return loaded
    }

    func setCompleted(_ completed: Bool, habitID: String, day: GlowWatchDay) throws -> GlowWatchState {
        var updated = try load()
        updated.setCompleted(completed, habitID: habitID, day: day)
        return try save(updated)
    }

    func receive(_ snapshot: GlowWatchSnapshot) throws -> GlowWatchState {
        var updated = try load()
        updated.receive(snapshot)
        return try save(updated)
    }

    private func save(_ updated: GlowWatchState) throws -> GlowWatchState {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: url, options: .atomic)
        state = updated
        return updated
    }
}
