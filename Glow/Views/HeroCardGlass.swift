import SwiftUI

struct HeroCardGlass: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // spotlight bindings
    @Binding var highlightTodayCard: Bool
    @Binding var lastPercent: Double

    // celebration state
    @State private var overdriveActive = false
    @State private var sheenOffset: CGFloat = -200
    @State private var showBonusGlow = false

    // ✨ shooting star animation state
    @State private var showBonusStar = false
    @State private var starProgress: CGFloat = 0.0
    @State private var starResting = false

    // progress inputs
    let done: Int
    let total: Int
    let percent: Double    // can be > 1.0
    let bonus: Int
    let allDone: Int

    /// Fraction of scheduled practices that are complete (ignores bonus).
    private var scheduledFraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(done) / Double(total), 0), 1)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? .white : GlowTheme.textPrimary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
        ? Color.white.opacity(0.7)
        : GlowTheme.textSecondary
    }

    // glass card base + optional celebration layer
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GlowTheme.Radius.hero, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: GlowTheme.Radius.hero, style: .continuous)
                        .stroke(
                            Color.white.opacity(colorScheme == .dark ? 0.18 : 0.4),
                            lineWidth: 1
                        )
                        .blendMode(.plusLighter)
                )

            if overdriveActive {
                // soft accent bloom
                RadialGradient(
                    colors: [
                        GlowTheme.accentPrimary.opacity(0.35),
                        .clear
                    ],
                    center: .topLeading,
                    startRadius: 12,
                    endRadius: 180
                )
                .blendMode(.screen)
                .allowsHitTesting(false)

                // single sheen swipe
                LinearGradient(
                    colors: [
                        .clear,
                        Color.white.opacity(0.35),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 160)
                .rotationEffect(.degrees(18))
                .offset(x: sheenOffset)
                .blur(radius: 18)
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: GlowTheme.Radius.hero, style: .continuous))
    }

    private var statusLine: String {
        if total == 0 {
            return "No practices scheduled"
        }
        if done == 0 {
            return "Ready when you are"
        }
        return "\(done) of \(total) complete"
    }

    var body: some View {
        HStack(alignment: .center, spacing: GlowTheme.Spacing.medium) {

            // LEFT: ring
            ProgressRingView(
                percent: percent,
                overdriveActive: overdriveActive,
                sweepPhase: 0 // we don’t need to drive this from outside
            )
            .frame(width: 88, height: 88)

            // MIDDLE: text
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.title.weight(.semibold))
                    .foregroundStyle(primaryTextColor)

                Text(statusLine)
                    .font(.footnote)
                    .foregroundStyle(secondaryTextColor)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(1)
                    .opacity(showBonusGlow ? 1.0 : 0.55)
                    .scaleEffect(showBonusGlow ? 1.0 : 0.995, anchor: .leading)
                    .animation(.easeInOut(duration: 0.85), value: showBonusGlow)
            }
            .padding(.top, 2)

            Spacer(minLength: 8)
        }
        .padding(.vertical, GlowTheme.Spacing.medium)
        .padding(.horizontal, GlowTheme.Spacing.medium)
        .background(cardBackground)
        // ✨ overlay: gold shooting star path from near “complete” to off the right edge
        .overlay(
            GeometryReader { geo in
                if showBonusStar {
                    // Start just under the status line, roughly under the word "complete"
                    let start = CGPoint(
                        x: geo.size.width * 0.14,   // near lower-left of the hero card
                        y: geo.size.height * 0.82
                    )
                    // End near the top‑right edge of the hero card, still visible
                    let end = CGPoint(
                        x: geo.size.width - 10,
                        y: geo.size.height * 0.18
                    )

                    let t = starResting ? 1.0 : CGFloat(starProgress)
                    let x = start.x + (end.x - start.x) * t
                    let y = start.y + (end.y - start.y) * t

                    ShootingStarView(resting: starResting)
                        .position(x: x, y: y)
                }
            }
            .allowsHitTesting(false)
        )
        .contentShape(RoundedRectangle(cornerRadius: GlowTheme.Radius.hero, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.48 : 0.09),
            radius: 28,
            y: 16
        )
        // accent glow grows as scheduled practices complete
        .shadow(
            color: GlowTheme.accentPrimary.opacity(
                (colorScheme == .dark ? 0.5 : 0.35) * scheduledFraction
            ),
            radius: 24 * scheduledFraction,
            y: 0
        )
        .onChange(of: percent) { _, newValue in
            // track lastPercent but let completion logic be driven by done/total
            lastPercent = newValue
        }
        .onChange(of: done) { oldValue, newValue in
            let wasComplete = total > 0 && oldValue >= total
            let isComplete = total > 0 && newValue >= total
            if !wasComplete && isComplete {
                startOverdrive()
            }
        }
        .onChange(of: bonus) { _, newValue in
            if newValue > 0 {
                pulseBonus()
            }
        }
        .onAppear {
            if bonus > 0 {
                pulseBonus()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today \(statusLine), \(Int(percent * 100)) percent."
        )
    }

    // MARK: - celebration
    private func startOverdrive() {
        // accessibility-friendly short version
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.25)) {
                overdriveActive = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                overdriveActive = false
            }
            return
        }

        // turn the glow on
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            overdriveActive = true
        }

        // run a single sheen sweep
        sheenOffset = -200
        withAnimation(.easeInOut(duration: 1.3)) {
            sheenOffset = 200
        }

        // keep the glow for ~10s like you wanted
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                overdriveActive = false
                sheenOffset = -200
            }
        }
    }

    private func pulseBonus() {
        withAnimation(.easeInOut(duration: 0.85)) {
            showBonusGlow = true
        }

        launchShootingStar()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeInOut(duration: 0.85)) {
                showBonusGlow = false
            }
        }
    }

    private func launchShootingStar() {
        guard bonus > 0 else { return }

        // Respect Reduce Motion with a shorter, simpler effect
        if reduceMotion {
            showBonusStar = true
            starResting = false
            starProgress = 0.0

            // Start the animation on the next runloop tick so the star
            // is first rendered at the starting point, then flies across.
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.6)) {
                    starProgress = 1.0
                }
            }

            // Snap into a brief resting pulse at the edge
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                starResting = true
            }

            return
        }

        // Normal, more expressive arc across the card
        showBonusStar = true
        starResting = false
        starProgress = 0.0

        // Fly across the card – start the animation on the next tick so
        // the star is first drawn at the starting point and then travels
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 1.4)) {
                starProgress = 1.0
            }
        }

        // When the flight finishes, switch into a pulsing resting state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            starResting = true
        }
    }
}

private struct ProgressRingView: View {
    let percent: Double
    let overdriveActive: Bool
    let sweepPhase: Double // kept for signature

    @State private var breathe: Bool = false

    private var clampedPercent: Double {
        max(0.0, percent)
    }

    var body: some View {
        let idleScale: CGFloat = 1.015
        let overScale: CGFloat = 1.03

        ZStack {
            Circle()
                .stroke(GlowTheme.borderMuted.opacity(0.35), lineWidth: 12)

            Circle()
                .trim(from: 0, to: min(1.0, clampedPercent))
                .stroke(
                    GlowTheme.accentPrimary.opacity(breathe ? 1.0 : 0.4),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(breathe ? (overdriveActive ? overScale : idleScale) : 1.0)
                .animation(.easeInOut(duration: 0.25), value: clampedPercent)
                .animation(
                    .easeInOut(duration: overdriveActive ? 0.9 : 2.2)
                        .repeatForever(autoreverses: true),
                    value: breathe
                )

            Text("\(Int(clampedPercent * 100))%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(GlowTheme.textPrimary)
        }
        .onAppear {
            breathe = true
        }
        .onChange(of: overdriveActive) { _, newValue in
            if newValue {
                breathe = true
            }
        }
    }
}

// MARK: - Gold shooting star

private struct ShootingStarView: View {
    let resting: Bool
    @State private var pulse = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // trailing tail (only while flying)
            if !resting {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.yellow.opacity(0.0),
                                Color.yellow.opacity(0.12),
                                Color.yellow.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 80, height: 3)
                    .blur(radius: 0.7)
                    .rotationEffect(.degrees(-15))
            }

            // gold star head
            Image(systemName: "star.fill")
                .font(.system(size: resting ? 18 : 14, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.76),
                            Color(red: 1.0, green: 0.84, blue: 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.yellow.opacity(0.95), radius: resting ? 12 : 10, x: 0, y: 0)
                .scaleEffect(resting ? (pulse ? 1.12 : 0.95) : 1.0)
                .animation(
                    resting
                    ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                    : .default,
                    value: pulse
                )
        }
        .compositingGroup()
        .onAppear {
            pulse = true
        }
    }
}
