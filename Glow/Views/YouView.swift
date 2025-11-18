import SwiftUI

struct YouView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // live data from HomeView
    let currentStreak: Int
    let bestStreak: Int
    let favoriteTitle: String
    let favoriteHits: Int      // e.g. "9" times in window
    let favoriteWindow: Int    // e.g. "14" days window
    let checkInTime: Date      // e.g. ~8:15pm
    let recentActiveDays: Int  // days with ≥1 completion in the last 7 days
    let lifetimeActiveDays: Int
    let lifetimeCompletions: Int
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : GlowTheme.textSecondary
    }
    
    private var hasMeaningfulFavorite: Bool {
        favoriteHits > 0 && favoriteTitle != "—"
    }
    
    private var favoritePercentText: String? {
        guard favoriteWindow > 0, favoriteHits > 0 else { return nil }
        let percent = Int(round((Double(favoriteHits) / Double(favoriteWindow)) * 100))
        return "\(percent)%"
    }
    
    private var checkInTimeString: String {
        checkInTime.formatted(date: .omitted, time: .shortened)
    }
    
    private var checkInBucketDescription: String {
        let hour = Calendar.current.component(.hour, from: checkInTime)
        
        switch hour {
        case 5..<9:
            return "You usually check in in the early morning"
        case 9..<12:
            return "You usually check in in the late morning"
        case 12..<17:
            return "You usually check in in the afternoon"
        case 17..<21:
            return "You usually check in in the evening"
        case 21..<24:
            return "You usually check in later at night"
        default:
            // Covers late night / very early hours (0–4)
            return "You usually check in late at night"
        }
    }
    
    private var checkInNudgeText: String {
        let hour = Calendar.current.component(.hour, from: checkInTime)
        
        switch hour {
        case 5..<12:
            return "That’s a solid time to set the tone for your day."
        case 12..<18:
            return "That’s a good window to keep your day on track."
        case 18..<22:
            return "That’s a nice way to wind down and close the loop on your day."
        default:
            return "If that feels a bit late, you might experiment with nudging one practice earlier in the day."
        }
    }
    
    private var streakDetailText: String {
        if currentStreak == 0 {
            // Gentle, encouraging tone when there is no active streak.
            return "No streak right now — every restart counts."
        }
        
        if bestStreak == 0 || currentStreak == bestStreak {
            // Either best is not meaningful yet, or they are at their best streak so far.
            return "You’re at your best streak so far."
        }
        
        let gap = bestStreak - currentStreak
        if gap > 0 && gap <= 3 {
            return "Only \(gap) day\(gap == 1 ? "" : "s") away from your best streak of \(bestStreak) days."
        }
        
        return "Best streak so far: \(bestStreak) days."
    }
    
    private var recentActivitySummaryText: String {
        switch recentActiveDays {
        case 0:
            return "No practices logged in the last 7 days — every restart counts."
        case 7:
            return "You’ve had at least one practice on all 7 of the last 7 days."
        default:
            return "You’ve had at least one practice on \(recentActiveDays) of the last 7 days."
        }
    }
    
    private var lifetimeDaysSummaryText: String {
        switch lifetimeActiveDays {
        case 0:
            return "You haven’t logged a practice day yet — your first one is a great place to start."
        case 1:
            return "You’ve shown up on 1 day since you started Glow."
        default:
            return "You’ve shown up on \(lifetimeActiveDays) days since you started Glow."
        }
    }
    
    private var lifetimeCompletionsSummaryText: String {
        switch lifetimeCompletions {
        case 0:
            return "You haven’t marked any practices done yet."
        case 1:
            return "Across all practices, you’ve marked things done 1 time."
        default:
            return "Across all practices, you’ve marked things done \(lifetimeCompletions) times."
        }
    }
    
    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        Color.white
                            .opacity(colorScheme == .dark ? 0.18 : 0.4),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.7 : 0.12),
                radius: 32,
                y: 20
            )
    }
    
    var body: some View {
        GlowModalScaffold(
            title: "You",
            // subtitle: "A snapshot of how you’ve been showing up."
        ) {
            VStack(spacing: 24) {
                
                // greeting
                VStack(spacing: 8) {
                    Text("Hi there 👋")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(primaryTextColor)
                    
                    Text("Your wins, your most steady practice, and when you usually check in.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(secondaryTextColor)
                        .padding(.horizontal, 4)
                }
                .frame(maxWidth: .infinity)
                
                // right now
                VStack(alignment: .leading, spacing: 16) {
                    
                    Text("Right now")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    // streak row
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(GlowTheme.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(currentStreak) day\(currentStreak == 1 ? "" : "s") in a row")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            
                            Text(streakDetailText)
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Current streak")
                    .accessibilityValue("\(currentStreak) days. Best streak \(bestStreak) days.")
                    
                    // most consistent
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.pink)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if hasMeaningfulFavorite {
                                Text("Most consistent: \(favoriteTitle)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryTextColor)
                                
                                if let percentText = favoritePercentText {
                                    Text("\(favoriteHits) of last \(favoriteWindow) days (\(percentText))")
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(secondaryTextColor)
                                } else {
                                    Text("\(favoriteHits) of last \(favoriteWindow) days")
                                        .font(.footnote.monospacedDigit())
                                        .foregroundStyle(secondaryTextColor)
                                }
                            } else {
                                Text("No clear “most consistent” practice yet")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(primaryTextColor)
                                
                                Text("As you build a few steady days, we’ll highlight a favorite here.")
                                    .font(.footnote)
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Most consistent practice")
                    .accessibilityValue(
                        hasMeaningfulFavorite
                        ? "\(favoriteTitle), \(favoriteHits) days in last \(favoriteWindow) days."
                        : "No clear most consistent practice yet. We’ll highlight one after a few steady days."
                    )
                    
                    // check-in time
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(GlowTheme.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(checkInBucketDescription), around \(checkInTimeString)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            
                            Text(checkInNudgeText)
                                .font(.footnote)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Typical check-in time")
                    .accessibilityValue("\(checkInBucketDescription), around \(checkInTimeString).")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(glassCardBackground)
                
                // You & Glow over time
                VStack(alignment: .leading, spacing: 12) {
                    Text("You & Glow")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Showing up lately")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                        
                        Text(recentActivitySummaryText)
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Overall")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                        
                        Text(lifetimeDaysSummaryText)
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)
                        
                        Text(lifetimeCompletionsSummaryText)
                            .font(.footnote)
                            .foregroundStyle(secondaryTextColor)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(glassCardBackground)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Your recent and lifetime activity")
                .accessibilityValue("Active on \(recentActiveDays) of the last 7 days, and on \(lifetimeActiveDays) days overall.")
            }
        }
    }
}
