import SwiftUI

enum SidebarTab: String {
    case home = "Home"
    case progress = "Trends"
    case settings = "You"
}

struct SidebarOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedTab: SidebarTab
    let close: () -> Void

    @State private var offsetX: CGFloat = -320
    @Environment(\.openURL) private var openURL

    private var sidebarWidth: CGFloat { 260 }
    private var verticalInset: CGFloat { 40 }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black
                .opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { closeWithSlideOut() }

            VStack(alignment: .leading, spacing: 0) {
                // main nav
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "house.fill",
                        label: "Home",
                        isSelected: selectedTab == .home,
                        colorScheme: colorScheme,
                        iconSize: 20
                    ) {
                        selectedTab = .home
                        closeWithSlideOut()
                    }

                    SidebarRow(
                        icon: "person.crop.circle",
                        label: "You",
                        isSelected: selectedTab == .settings,
                        colorScheme: colorScheme,
                        iconSize: 19
                    ) {
                        selectedTab = .settings
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowYou, object: nil)
                    }

                    SidebarRow(
                        icon: "chart.bar",
                        label: "Trends",
                        isSelected: selectedTab == .progress,
                        colorScheme: colorScheme,
                        iconSize: 21
                    ) {
                        selectedTab = .progress
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowTrends, object: nil)
                    }
                }
                .padding(.top, 20)

                sidebarDivider

                // secondary
                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "bell.badge",
                        label: "Reminders",
                        isSelected: false,
                        colorScheme: colorScheme,
                        iconSize: 20
                    ) {
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowReminders, object: nil)
                    }

                    SidebarRow(
                        icon: "archivebox.fill",
                        label: "Archived",
                        isSelected: false,
                        colorScheme: colorScheme,
                        iconSize: 20
                    ) {
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowArchive, object: nil)
                    }
                }

                sidebarDivider
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 6) {
                    SidebarRow(
                        icon: "sparkles",
                        label: "About Glow",
                        isSelected: false,
                        colorScheme: colorScheme,
                        iconSize: 20
                    ) {
                        closeWithSlideOut()
                        NotificationCenter.default.post(name: .glowShowAbout, object: nil)
                    }

                    SidebarRow(
                        icon: "paperplane.fill",
                        label: "Send Feedback",
                        isSelected: false,
                        colorScheme: colorScheme,
                        iconSize: 20
                    ) {
                        sendFeedback()
                    }
                }
                .padding(.bottom, 12)
            }
            .frame(width: sidebarWidth, alignment: .leading)
            .padding(.vertical, verticalInset)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.93)
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.03 : 0.14),
                                Color.white.opacity(0.00)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(
                                Color.white.opacity(colorScheme == .dark ? 0.12 : 0.22),
                                lineWidth: 0.75
                            )
                            .blendMode(.plusLighter)
                    )
                    .shadow(
                        color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.08),
                        radius: 40,
                        y: 20
                    )
            )
            .offset(x: offsetX)
        }
        .onAppear {
            selectedTab = .home
            offsetX = -sidebarWidth - 40
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                offsetX = 0
            }
        }
    }

    private var sidebarDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.15 : 0.25),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }

    private func closeWithSlideOut() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            offsetX = -sidebarWidth - 40
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            close()
        }
    }

    private func sendFeedback() {
        openMail(
            to: GlowAppConfig.supportEmail,
            subject: GlowAppConfig.supportSubject,
            body: GlowAppConfig.supportBodyHint
        )
        closeWithSlideOut()
    }

    private func openMail(to: String, subject: String, body: String) {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(to)?subject=\(encodedSubject)&body=\(encodedBody)") {
            openURL(url)
        }
    }
}

private struct SidebarRow: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let colorScheme: ColorScheme
    let iconSize: CGFloat
    let tap: () -> Void

    private var fgColor: Color {
        if isSelected {
            return GlowTheme.accentPrimary
        } else {
            return colorScheme == .dark ? .white : GlowTheme.textPrimary
        }
    }

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .medium))
                    .foregroundStyle(fgColor)

                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(fgColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 48, alignment: .leading)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GlowTheme.accentPrimary.opacity(colorScheme == .dark ? 0.22 : 0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(GlowTheme.accentPrimary.opacity(colorScheme == .dark ? 0.5 : 0.4), lineWidth: 1)
                            )
                    } else {
                        Color.clear
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
    }
}
