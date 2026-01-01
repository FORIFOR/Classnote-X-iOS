import SwiftUI

struct GlassChrome: View {
    @Environment(\.colorScheme) var scheme
    
    var body: some View {
        let shadow = Tokens.Shadows.card(for: scheme)
        ZStack {
            BlurView(style: Tokens.Blur.tabBar(for: scheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.tabBarPill, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.tabBarPill, style: .continuous)
                .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
        )
        .shadow(
            color: shadow.color,
            radius: shadow.radius,
            x: shadow.x,
            y: shadow.y
        )
    }
}
