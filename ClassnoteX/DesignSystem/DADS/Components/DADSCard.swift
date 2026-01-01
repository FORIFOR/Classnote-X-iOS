import SwiftUI

struct DADSCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shadow = DADS.Shadows.card(for: colorScheme)
        content
            .padding(DADS.Spacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: DADS.Radius.card, style: .continuous)
                    .fill(DADS.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DADS.Radius.card, style: .continuous)
                    .stroke(DADS.Colors.border, lineWidth: 1)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
