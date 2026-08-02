import Foundation

/// Central library of habit icons and the keywords that map to them.
enum HabitIconLibrary {

    struct HabitIcon: Identifiable, Hashable {
        var id: String { name }
        let name: String        // SF Symbol name or a Glow custom symbol name
        let label: String       // Human-readable label
        let keywords: [String]  // Words/phrases that should trigger this icon (lowercased)
    }

    static let martiniIconName = "glow.martini"
    static let candyIconName = "glow.candy.gummies"
    static let cannabisIconName = "glow.cannabis"

    private static let legacyAutomaticIconNames: Set<String> = [
        "birthday.cake.fill",
        "checkmark.circle",
        "glow.candy",
        "heart.fill",
        "nosign"
    ]

    private static let upgradedSemanticIconNames: Set<String> = [
        martiniIconName,
        candyIconName,
        "gift.fill",
        "fork.knife",
        cannabisIconName
    ]

    // NOTE: order matters – the first matching icon wins.
    static let all: [HabitIcon] = [
        HabitIcon(
            name: martiniIconName,
            label: "No Alcohol",
            keywords: ["no alcohol", "alcohol-free", "sober", "sobriety"]
        ),
        HabitIcon(
            name: candyIconName,
            label: "No Candy",
            keywords: ["no candy", "no sweets", "candy-free"]
        ),
        HabitIcon(
            name: "gift.fill",
            label: "No Purchases",
            keywords: ["no purchases", "no purchase", "no shopping", "no spending", "buy nothing"]
        ),
        HabitIcon(
            name: "fork.knife",
            label: "No Meat",
            keywords: ["no meat", "meat-free", "vegetarian"]
        ),
        HabitIcon(
            name: cannabisIconName,
            label: "No Grass",
            keywords: ["no grass", "no marijuana", "no cannabis", "no weed"]
        ),
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
            keywords: ["diet", "nutrition", "eat clean", "no sugar", "no junk"]
        ),
        HabitIcon(
            name: "nosign",
            label: "No",
            keywords: ["no sugar", "no soda", "no smoking", "no vape"]
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
            label: "Focus",
            keywords: ["focus block", "focus", "study", "learn", "course", "training", "practice"]
        ),
        HabitIcon(
            name: "moon.zzz.fill",
            label: "Wind Down",
            keywords: ["wind down", "no screens", "blue light", "night routine", "relax before bed"]
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

    private static func matches(_ title: String, icon: HabitIcon) -> Bool {
        let lower = title.lowercased()
        return icon.keywords.contains { key in
            lower.contains(key)
        }
    }

    /// Returns the best-fit SF Symbol name for a given habit title.
    static func guessIcon(for title: String) -> String {
        // 1. library-driven match (first win)
        for icon in all {
            if matches(title, icon: icon) {
                return icon.name
            }
        }

        let lower = title.lowercased()

        // 2. additional simple heuristics that aren’t in the library yet
        if lower.contains("journal") || lower.contains("gratitude") {
            return "pencil.and.list.clipboard"
        }
        if lower.contains("meditate") || lower.contains("breathe") || lower.contains("breathing") {
            return "leaf.fill"
        }

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

    /// Returns a semantic replacement for an icon that was automatically assigned
    /// by an older version of Glow. Explicitly chosen, non-generic icons are preserved.
    static func upgradedIcon(for title: String, currentIcon: String) -> String? {
        guard legacyAutomaticIconNames.contains(currentIcon) else { return nil }

        let recommendedIcon = guessIcon(for: title)
        guard upgradedSemanticIconNames.contains(recommendedIcon),
              recommendedIcon != currentIcon
        else {
            return nil
        }

        return recommendedIcon
    }
}
