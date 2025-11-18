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
    
    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }
    
    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.7) : GlowTheme.textSecondary
    }
    
    private var checkInTimeString: String {
        checkInTime.formatted(date: .omitted, time: .shortened)
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
                            Text("\(currentStreak) day streak")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            
                            Text("Best streak: \(bestStreak) days")
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
                            Text("Most consistent: \(favoriteTitle)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            
                            Text("\(favoriteHits) days in last \(favoriteWindow) days")
                                .font(.footnote.monospacedDigit())
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Most consistent practice")
                    .accessibilityValue("\(favoriteTitle), \(favoriteHits) days in last \(favoriteWindow) days.")
                    
                    // check-in time
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Image(systemName: "clock.fill")
                            .foregroundStyle(GlowTheme.accentPrimary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You usually check in around \(checkInTimeString)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(primaryTextColor)
                            
                            Text("That’s when you tend to mark things done.")
                                .font(.footnote)
                                .foregroundStyle(secondaryTextColor)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Typical check-in time")
                    .accessibilityValue("Around \(checkInTimeString)")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(glassCardBackground)
                
                // future / placeholder card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coming soon")
                        .font(.headline)
                        .foregroundStyle(primaryTextColor)
                    
                    Text("Daily mood, softer nudges, tiny reflections — all in one place.")
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(glassCardBackground)
            }
        }
    }
}
