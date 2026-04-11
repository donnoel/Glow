import SwiftUI

private struct IPadPageContainerModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let maxWidth: CGFloat

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .frame(maxWidth: maxWidth, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
        } else {
            content
        }
    }
}

extension View {
    func glowIPadPageContainer(maxWidth: CGFloat) -> some View {
        modifier(IPadPageContainerModifier(maxWidth: maxWidth))
    }

    func glowIPadListComposition(top: CGFloat = 6, bottom: CGFloat = 20) -> some View {
        modifier(IPadListCompositionModifier(top: top, bottom: bottom))
    }
}

private struct IPadListCompositionModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let top: CGFloat
    let bottom: CGFloat

    func body(content: Content) -> some View {
        if horizontalSizeClass == .regular {
            content
                .contentMargins(.top, top, for: .scrollContent)
                .contentMargins(.bottom, bottom, for: .scrollContent)
        } else {
            content
        }
    }
}
