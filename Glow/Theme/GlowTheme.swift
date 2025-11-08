import SwiftUI

enum GlowTheme {
    // Brand accents
    static let accentPrimary   = Color("AccentPrimary")
    static let accentSecondary = Color("AccentSecondary")
    static let accentPink      = Color("AccentPink")

    // Surfaces / backgrounds
    static let bgPrimary   = Color("BackgroundPrimary")
    static let bgSurface   = Color("BackgroundSurface")

    // Text
    static let textPrimary   = Color("TextPrimary")     // high contrast
    static let textSecondary = Color("TextSecondary")   // softer, secondary
    static let borderMuted   = Color("BorderMuted")     // subtle stroke/divider

    // Haptics for delightful taps
    static func tapHaptic() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #else
        // Haptics not available on this platform
        #endif
    }

    // Hero gradient (not currently applied to cards in M10, but we keep it
    // around for future dashboard widgets or marketing moments)
    static let heroGradient: LinearGradient = {
        LinearGradient(
            colors: [
                accentPrimary.opacity(0.55),
                accentSecondary.opacity(0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }()
}

// MARK: - View helpers
extension View {
    /// Applies Glow accent tint to controls in this subtree.
    func glowTint() -> some View {
        self.tint(GlowTheme.accentPrimary)
    }

    /// Sets the overall screen background to our brand background so
    /// system default gray doesn't leak through.
    func glowScreenBackground() -> some View {
        self
            .background(GlowTheme.bgPrimary.ignoresSafeArea())
    }

    /// Applies the surface background (for cards/lists) to the screen.
    func glowSurfaceBackground() -> some View {
        self.background(GlowTheme.bgSurface.ignoresSafeArea())
    }
}
