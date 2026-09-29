import SwiftUI

extension Habit {
    private static let accentColorNames = [
        "PracticeBlueAccent",
        "PracticeGreenAccent",
        "PracticePurpleAccent",
        "PracticeOrangeAccent",
        "PracticePinkAccent",
        "PracticeTealAccent",
        "PracticeAmberAccent",
        "PracticeCoralAccent",
        "PracticeLavenderAccent",
        "PracticeMintAccent"
    ]

    var accentColorName: String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        let index = Int(hash % UInt64(Self.accentColorNames.count))
        return Self.accentColorNames[index]
    }

    var accentColor: Color { Color(accentColorName) }
}

extension Notification.Name {
    static let glowShowTrends = Notification.Name("glowShowTrends")
    static let glowShowAbout  = Notification.Name("glowShowAbout")
    static let glowShowYou    = Notification.Name("glowShowYou")
    static let glowShowArchive = Notification.Name("glowShowArchive")
    static let glowShowReminders = Notification.Name("glowShowReminders")
    static let glowDataDidChange = Notification.Name("glowDataDidChange")
}

extension Habit {
    /// Minimal stand-in habit so we can reuse StreakEngine at the global level.
    static var placeholder: Habit {
        Habit(
            title: "Any Habit",
            createdAt: .now,
            isArchived: false,
            schedule: .daily,
            reminderEnabled: false,
            reminderHour: nil,
            reminderMinute: nil,
            iconName: "circle",
            sortOrder: 0
        )
    }
}
