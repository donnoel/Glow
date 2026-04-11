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
}
