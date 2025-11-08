import SwiftUI

struct AboutGlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    // Fake version for now — you can wire this to Bundle.main later
    private let appVersion = "1.0 (Beta)"

    private var glassCardBackground: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.4),
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
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Glow identity + version
                    VStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(GlowTheme.accentPrimary)

                        Text("Glow")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                        Text("Version \(appVersion)")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(
                                colorScheme == .dark
                                ? Color.white.opacity(0.6)
                                : GlowTheme.textSecondary
                            )
                    }
                    .frame(maxWidth: .infinity)

                    // Mission
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Why Glow exists")
                            .font(.headline)
                            .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                        Text(
                            "Glow helps you show up for yourself every day. Not with guilt, not with streak anxiety — just gentle momentum.\n\nYou pick the practices that matter. Glow tracks them, celebrates the small wins, and keeps the rhythm going."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)

                    // Privacy
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your data")
                            .font(.headline)
                            .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                        Text(
                            "Your habits are yours. Glow keeps your practices on your device.\n\nWe’re working on optional iCloud sync so you can see them on iPad without creating an account."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)

                    // Credits / contact
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Made with care")
                            .font(.headline)
                            .foregroundStyle(colorScheme == .dark ? .white : GlowTheme.textPrimary)

                        Text(
                            "Glow is being crafted by a tiny team that really cares about daily habits, mental energy, and showing up.\n\nWe’d love to hear what’s working (and what’s not)."
                        )
                        .font(.subheadline)
                        .foregroundStyle(
                            colorScheme == .dark
                            ? Color.white.opacity(0.8)
                            : GlowTheme.textSecondary
                        )
                        .multilineTextAlignment(.leading)

                        Button {
                            if let url = URL(string: "mailto:donnoel@icloud.com?subject=Glow%20Feedback") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Send Feedback")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(GlowTheme.accentPrimary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        GlowTheme.accentPrimary.opacity(
                                            colorScheme == .dark ? 0.18 : 0.12
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Send feedback about Glow")
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(glassCardBackground)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("About Glow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                }
            }
        }
    }
}
