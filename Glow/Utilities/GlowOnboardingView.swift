import SwiftUI

struct GlowOnboardingView: View {
    // parent will bind this
    @Binding var isPresented: Bool

    var body: some View {
        TabView {
            OnboardingPage(
                title: "Welcome to Glow ✨",
                subtitle: "Glow is for small daily practices. Things you actually want to keep doing.",
                systemImage: "sparkles"
            )

            OnboardingPage(
                title: "Add a practice",
                subtitle: "Tap the + in the top right. Name it, pick a schedule, optionally set a reminder.",
                systemImage: "plus.circle.fill"
            )

            OnboardingPage(
                title: "Check it off",
                subtitle: "From Home, tap a practice to mark today done. Glow tracks streaks and shows your wins.",
                systemImage: "checkmark.circle.fill"
            )

            OnboardingPage(
                title: "See more",
                subtitle: "Use the menu to view Trends, You, Reminders, and Archived.",
                systemImage: "line.3.horizontal"
            )
        }
        .tabViewStyle(.page)
        .background(.ultraThinMaterial)
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                isPresented = false
            }
            .font(.footnote.weight(.semibold))
            .padding(14)
        }
        .overlay(alignment: .bottom) {
            Button {
                isPresented = false
            } label: {
                Text("Get started")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GlowTheme.accentPrimary)
                    )
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
            }
        }
    }
}

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(GlowTheme.accentPrimary)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }
}
