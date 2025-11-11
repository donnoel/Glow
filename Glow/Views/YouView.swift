import SwiftUI

struct YouView: View {
    @Environment(\.colorScheme) private var colorScheme

    // live data from HomeView
    let currentStreak: Int
    let bestStreak: Int
    let favoriteTitle: String
    let favoriteHits: Int      // e.g. "9" times in window
    let favoriteWindow: Int    // e.g. "14" days window
    let checkInTime: Date      // e.g. ~8:15pm

    private var checkInTimeString: String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: checkInTime)
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
            subtitle: "Your rhythm, your highlights, your usual check-in time."
        ) {
            // greeting
            VStack(spacing: 8) {
                Text("Hi there 👋")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(
                        colorScheme == .dark ? .white : GlowTheme.textPrimary
                    )

                Text("This is your space. Your habits, your rhythm, your wins.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(
                        colorScheme == .dark
                        ? Color.white.opacity(0.7)
                        : GlowTheme.textSecondary
                    )
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity)

            // right now
            VStack(alignment: .leading, spacing: 16) {

                Text("Right now")
                    .font(.headline)
                    .foregroundStyle(
                        colorScheme == .dark ? .white : GlowTheme.textPrimary
                    )

                // streak row
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(GlowTheme.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(currentStreak) day streak")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text("Best streak: \(bestStreak) days")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                colorScheme == .dark
                                ? Color.white.opacity(0.7)
                                : GlowTheme.textSecondary
                            )
                    }
                }

                // most consistent
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Most consistent: \(favoriteTitle)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text("\(favoriteHits) days in last \(favoriteWindow) days")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                colorScheme == .dark
                                ? Color.white.opacity(0.7)
                                : GlowTheme.textSecondary
                            )
                    }
                }

                // check-in time
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(GlowTheme.accentPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You usually check in around \(checkInTimeString)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(
                                colorScheme == .dark ? .white : GlowTheme.textPrimary
                            )

                        Text("That’s when you tend to mark things done.")
                            .font(.footnote)
                            .foregroundStyle(
                                colorScheme == .dark
                                ? Color.white.opacity(0.7)
                                : GlowTheme.textSecondary
                            )
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(glassCardBackground)

            // future card
            VStack(alignment: .leading, spacing: 12) {
                Text("Coming soon")
                    .font(.headline)
                    .foregroundStyle(
                        colorScheme == .dark ? .white : GlowTheme.textPrimary
                    )

                Text("Daily mood, gentle nudges, tiny reflections. A calmer way to see how you're actually doing, not just what you checked off.")
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
