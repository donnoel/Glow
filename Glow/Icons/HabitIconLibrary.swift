import Foundation

/// Central library of habit icons and the keywords that map to them.
enum HabitIconLibrary {

    struct HabitIcon: Identifiable, Hashable {
        let id = UUID()
        let name: String        // SF Symbol name
        let label: String       // Human-readable label
        let keywords: [String]  // Words/phrases that should trigger this icon
    }

    static let all: [HabitIcon] = [
        HabitIcon(
            name: "drop.fill",
            label: "Hydrate",
            keywords: ["water", "hydrate", "drink water", "h2o", "no soda"]
        ),
        HabitIcon(
            name: "bed.double.fill",
            label: "Sleep",
            keywords: ["sleep", "bed", "rest", "lights out", "wind down", "bedtime"]
        ),
        HabitIcon(
            name: "book.fill",
            label: "Read",
            keywords: ["read", "reading", "book", "study", "pages", "chapter"]
        ),
        HabitIcon(
            name: "figure.walk",
            label: "Walk",
            keywords: ["walk", "walking", "steps", "outside walk"]
        ),
        HabitIcon(
            name: "figure.run",
            label: "Run",
            keywords: ["run", "running", "cardio", "treadmill", "jog"]
        ),
        HabitIcon(
            name: "dumbbell.fill",
            label: "Workout",
            keywords: ["workout", "lift", "gym", "weights", "training", "strength", "exercise"]
        ),
        HabitIcon(
            name: "heart.fill",
            label: "Health",
            keywords: ["diet", "nutrition", "eat clean", "no candy", "no sugar", "no junk"]
        ),
        HabitIcon(
            name: "nosign",
            label: "No ____",
            keywords: ["no candy", "no sugar", "no soda", "no smoking", "no vape", "no alcohol"]
        ),
        HabitIcon(
            name: "lungs.fill",
            label: "No Smoking",
            keywords: ["quit smoking", "no smoking", "no vape", "no nicotine"]
        ),
        HabitIcon(
            name: "cup.and.saucer.fill",
            label: "Caffeine",
            keywords: ["less caffeine", "no coffee", "tea only", "limit caffeine"]
        ),
        HabitIcon(
            name: "leaf.fill",
            label: "Mindful",
            keywords: ["meditate", "meditation", "mindful", "breathe", "breathing", "calm", "stillness"]
        ),
        HabitIcon(
            name: "pencil.and.list.clipboard",
            label: "Journal",
            keywords: ["journal", "gratitude", "reflect", "write", "morning pages", "log day"]
        ),
        HabitIcon(
            name: "brain.head.profile",
            label: "Focus / Study",
            keywords: ["focus block", "focus", "study", "learn", "course", "training", "practice"]
        ),
        HabitIcon(
            name: "moon.zzz.fill",
            label: "Wind Down",
            keywords: ["wind down", "no screens", "blue light", "night routine", "relax before bed"]
        ),
        HabitIcon(
            name: "tooth.fill",
            label: "Teeth",
            keywords: ["floss", "flossing", "brush", "brush teeth", "oral care", "mouthwash"]
        ),
        HabitIcon(
            name: "figure.cooldown",
            label: "Stretch",
            keywords: ["stretch", "mobility", "cooldown", "yoga", "flexibility"]
        ),
        HabitIcon(
            name: "bubble.fill",
            label: "Reach Out",
            keywords: ["call", "text", "check in", "reach out", "message", "talk to", "friend", "mom", "dad"]
        )
    ]

    /// Returns the best-fit SF Symbol name for a given habit title.
    static func guessIcon(for title: String) -> String {
        let lower = title.lowercased()

        // 1. Exact-ish keyword match
        for icon in all {
            if icon.keywords.contains(where: { lower.contains($0) }) {
                return icon.name
            }
        }

        // 2. Tiny heuristics for common words that may not be in keywords
        if lower.contains("drink") || lower.contains("water") {
            return "drop.fill"
        }
        if lower.contains("sleep") || lower.contains("bed") {
            return "bed.double.fill"
        }
        if lower.contains("walk") {
            return "figure.walk"
        }
        if lower.contains("run") || lower.contains("jog") {
            return "figure.run"
        }

        // 3. Fallback
        return "checkmark.circle"
    }
}
