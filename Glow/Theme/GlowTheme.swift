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

// MARK: - 🔐 Design tokens (spacing, radii, glass)
extension GlowTheme {
    /// Spacing scale for Glow. Stick to these so Home, Detail, and Widgets
    /// all breathe the same.
    struct Spacing {
        static let xsmall: CGFloat = 8
        static let small: CGFloat  = 12
        static let medium: CGFloat = 16   // default inner padding
        static let large: CGFloat  = 20   // section gaps
        static let xlarge: CGFloat = 32   // hero / top chrome
    }

    /// Corner radius scale so we stop seeing 12/18/26 all over.
    struct Radius {
        static let pill: CGFloat   = 999
        static let small: CGFloat  = 12   // cards, widget corners
        static let medium: CGFloat = 16   // list rows / detail cards
        static let large: CGFloat  = 20   // dashboard blocks
        static let hero: CGFloat   = 24   // big hero cards (we'll pull 26 → 24 later)
    }

    /// Glass strokes/overlays tuned for light/dark.
    struct Glass {
        static let strokeLight  = Color.white.opacity(0.35)
        static let strokeDark   = Color.white.opacity(0.18)
        static let overlayLight = Color.white.opacity(0.16)
        static let overlayDark  = Color.white.opacity(0.08)
    }
}

// MARK: - 🪟 Shared glass card helper
extension View {
    /// Standard Glow glass card: ultra-thin material, subtle stroke.
    /// Use this in Home, Detail, and even to mirror in the widget.
    func glowGlassCard(cornerRadius: CGFloat = GlowTheme.Radius.small) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(GlowTheme.Glass.strokeDark, lineWidth: 1)
            )
    }
}
