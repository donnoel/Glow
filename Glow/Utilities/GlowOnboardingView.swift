import SwiftUI

struct GlowOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var pageIndex: Int = 0

    private let totalPages = 6

    var body: some View {
        ZStack {
            TabView(selection: $pageIndex) {
                OnboardingPage(
                    title: "Welcome to Glow ✨",
                    subtitle: "Glow keeps the few daily practices you actually care about.",
                    systemImage: "sparkles"
                )
                .tag(0)

                OnboardingPage(
                    title: "Add a practice",
                    subtitle: "Tap the + in the top right. Give it a name, pick a schedule, then turn on “Remind me”.",
                    systemImage: "bell.badge.fill"
                )
                .tag(1)

                OnboardingPage(
                    title: "Tap to see details",
                    subtitle: "From Home, tap a practice to see streak, heatmap, and history.",
                    systemImage: "list.bullet.rectangle.portrait.fill"
                )
                .tag(2)

                OnboardingPage(
                    title: "Swipe on a practice",
                    subtitle: "Swipe left to Edit, Archive, or Delete.",
                    systemImage: "hand.point.right.fill"
                )
                .tag(3)

                OnboardingPage(
                    title: "Open the menu",
                    subtitle: "Use the menu for You, Trends, Reminders, Archived, and About.",
                    systemImage: "line.3.horizontal"
                )
                .tag(4)

                OnboardingPage(
                    title: "Add the Glow Widget",
                    subtitle: "Put Glow on your Home Screen for instant daily progress and one‑tap check‑ins.",
                    systemImage: "rectangle.3.offgrid.fill"
                )
                .tag(5)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(.ultraThinMaterial)

            // top-right skip
            VStack {
                HStack {
                    Spacer()
                    if pageIndex < totalPages - 1 {
                        Button("Skip") {
                            isPresented = false
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(14)
                    }
                }
                Spacer()
            }

            // bottom controls
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    // dots
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { idx in
                            Circle()
                                .fill(idx == pageIndex ? GlowTheme.accentPrimary : Color.secondary.opacity(0.28))
                                .frame(width: idx == pageIndex ? 10 : 8, height: idx == pageIndex ? 10 : 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        if pageIndex < totalPages - 1 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                pageIndex += 1
                            }
                        } else {
                            isPresented = false
                        }
                    } label: {
                        Text(pageIndex < totalPages - 1 ? "Next" : "Get started")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: 160)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(GlowTheme.accentPrimary)
                            )
                            .foregroundStyle(.white)
                    }
                }
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
