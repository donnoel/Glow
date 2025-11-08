import SwiftUI

extension Habit {
    var accentColorName: String {
        switch abs(id.hashValue) % 10 {
        case 0: return "PracticeBlueAccent"
        case 1: return "PracticeGreenAccent"
        case 2: return "PracticePurpleAccent"
        case 3: return "PracticeOrangeAccent"
        case 4: return "PracticePinkAccent"
        case 5: return "PracticeTealAccent"
        case 6: return "PracticeAmberAccent"
        case 7: return "PracticeCoralAccent"
        case 8: return "PracticeLavenderAccent"
        default: return "PracticeMintAccent"
        }
    }

    var accentColor: Color { Color(accentColorName) }
}

extension Notification.Name {
    static let glowShowTrends = Notification.Name("glowShowTrends")
    static let glowShowAbout  = Notification.Name("glowShowAbout")
    static let glowShowYou    = Notification.Name("glowShowYou")
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
