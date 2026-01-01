import SwiftUI

// MARK: - Glass Card components

/// A unified card container with glass effect, stroke, and shadow.
/// Matches the specification's card design with radius=28.
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shadow = Tokens.Shadows.card(for: colorScheme)
        content
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

/// GlassCard with standard padding applied
struct PaddedGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GlassCard {
            content
                .padding(Tokens.Spacing.cardContent)
        }
    }
}

/// A smaller card with pill-like radius (26pt)
struct PillCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        let shadow = Tokens.Shadows.card(for: colorScheme)
        content
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(Tokens.Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
            .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - View Modifiers

extension View {
    /// Applies the standard glass card style to the view
    func glassCard() -> some View {
        GlassCard {
            self
        }
    }
    
    /// Applies the padded glass card style to the view
    func paddedGlassCard() -> some View {
        PaddedGlassCard {
            self
        }
    }
}
