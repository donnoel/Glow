// HeroCardGlass.swift
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

    // progress inputs
    let done: Int
    let total: Int
    let percent: Double    // can be > 1.0
    let bonus: Int
    let allDone: Int

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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
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
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var statusLine: String {
        if bonus > 0 {
            return "\(allDone) of \(total) complete\n+\(bonus) you're glowing!"
        } else {
            return "\(done) of \(total) complete"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {

            // LEFT: ring
            ProgressRingView(
                percent: percent,
                overdriveActive: overdriveActive,
                sweepPhase: 0 // we don’t need to drive this from outside
            )
            .frame(width: 88, height: 88)

            // RIGHT: text
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.55 : 0.09),
            radius: 30,
            y: 18
        )
        .onChange(of: percent) { oldValue, newValue in
            // only celebrate when we cross the 1.0 boundary
            if oldValue <= 1.0 && newValue > 1.0 {
                startOverdrive()
            }
            lastPercent = newValue
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) {
            withAnimation(.easeInOut(duration: 0.85)) {
                showBonusGlow = false
            }
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
        // pick the right scale based on state
        let idleScale: CGFloat = 1.015   // subtle all the time
        let overScale: CGFloat = 1.03    // a bit more when celebrating

        ZStack {
            // base ring
            Circle()
                .stroke(GlowTheme.borderMuted.opacity(0.35), lineWidth: 12)

            // progress
            Circle()
                .trim(from: 0, to: min(1.0, clampedPercent))
                .stroke(
                    GlowTheme.accentPrimary.opacity(breathe ? 1.0 : 0.4),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .scaleEffect(breathe ? (overdriveActive ? overScale : idleScale) : 1.0)
                // animate percent changes
                .animation(.easeInOut(duration: 0.25), value: clampedPercent)
                // animate the breathing itself
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
            // always breathe, just slower when idle
            breathe = true
        }
        .onChange(of: overdriveActive) { isOn in
            if isOn {
                breathe = true
            }
        }
    }
}
