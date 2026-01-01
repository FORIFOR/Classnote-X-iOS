import SwiftUI

struct PremiumCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let padding: CGFloat

    func body(content: Content) -> some View {
        let shadow = Tokens.Shadows.card(for: colorScheme)
        return content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .fill(Tokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

extension View {
    func premiumCard(padding: CGFloat = Tokens.Spacing.cardContent) -> some View {
        modifier(PremiumCardModifier(padding: padding))
    }
}
