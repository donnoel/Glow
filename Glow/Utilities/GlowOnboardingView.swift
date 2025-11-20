import SwiftUI
struct GlowOnboardingState {
    private(set) var pageIndex: Int = 0
    let totalPages: Int

    var isOnLastPage: Bool {
        guard totalPages > 0 else { return true }
        return pageIndex == totalPages - 1
    }

    var primaryButtonTitle: String {
        isOnLastPage ? "Get started" : "Next"
    }

    mutating func advance() {
        guard !isOnLastPage else { return }
        pageIndex += 1
    }
}
struct GlowOnboardingView: View {
    @Binding var isPresented: Bool
    @State private var pageIndex: Int = 0

    // ✅ 4 vibrant, story-driven slides
    private let totalPages = 4

    var body: some View {
        ZStack {
            TabView(selection: $pageIndex) {
                // 0 – Welcome / concept
                OnboardingPage(
                    title: "Welcome to Glow ✨",
                    subtitle: "A tiny home for the few daily practices you actually care about.",
                    mainSymbol: "sparkles",
                    supportingSymbols: ["sun.max.fill", "heart.fill"]
                )
                .tag(0)

                // 1 – Add + reminders + details
                OnboardingPage(
                    title: "Add what matters",
                    subtitle: "Tap the + to add a practice, pick a schedule, turn on “Remind me”, then tap a row to see streaks, heatmap, and history.",
                    mainSymbol: "plus.circle.fill",
                    supportingSymbols: ["bell.badge.fill", "list.bullet.rectangle.portrait.fill"]
                )
                .tag(1)

                // 2 – Swipe + menu
                OnboardingPage(
                    title: "Stay in control",
                    subtitle: "Swipe left to Edit, Archive, or Delete. Open the menu for You, Trends, Reminders, Archived, and About.",
                    mainSymbol: "hand.point.right.fill",
                    supportingSymbols: ["line.3.horizontal", "chart.bar.fill"]
                )
                .tag(2)

                // 3 – Widget + iCloud
                OnboardingPage(
                    title: "Always within reach",
                    subtitle: "Add the Glow widget for instant progress and one-tap check-ins. Glow uses iCloud to keep your practices in sync across devices.",
                    mainSymbol: "rectangle.3.offgrid.fill",
                    supportingSymbols: ["icloud", "iphone.homebutton"]
                )
                .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .background(
                LinearGradient(
                    colors: [
                        GlowTheme.accentPrimary.opacity(0.14),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

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
                                .fill(idx == pageIndex
                                      ? GlowTheme.accentPrimary
                                      : Color.secondary.opacity(0.28))
                                .frame(
                                    width: idx == pageIndex ? 10 : 8,
                                    height: idx == pageIndex ? 10 : 8
                                )
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

// MARK: - Onboarding Page

private struct OnboardingPage: View {
    let title: String
    let subtitle: String
    let mainSymbol: String
    let supportingSymbols: [String]

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            // Hero card – glassy, colorful, very Glow
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                GlowTheme.accentPrimary.opacity(0.28),
                                GlowTheme.accentPrimary.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                    )
                    .shadow(
                        color: GlowTheme.accentPrimary.opacity(0.55),
                        radius: 24,
                        y: 14
                    )

                VStack(spacing: 12) {
                    Image(systemName: mainSymbol)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    GlowTheme.accentPrimary.opacity(0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: GlowTheme.accentPrimary.opacity(0.8), radius: 14, y: 6)

                    if !supportingSymbols.isEmpty {
                        HStack(spacing: 14) {
                            ForEach(supportingSymbols, id: \.self) { symbol in
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .padding(8)
                                    .background(
                                        Circle()
                                            .fill(
                                                GlowTheme.accentPrimary.opacity(0.35)
                                            )
                                    )
                            }
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .frame(width: 190, height: 190)

            // Text stack – short, readable, centered
            VStack(spacing: 10) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 28)
            }

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
    }
}
