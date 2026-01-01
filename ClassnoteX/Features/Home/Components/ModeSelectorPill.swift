import SwiftUI

struct ModeSelectorPill: View {
    @Binding var selection: SessionType
    
    var body: some View {
        HStack(spacing: Tokens.Spacing.sm) {
            // Lecture Option
            ModePillButton(
                title: "講義",
                icon: "book.closed.fill",
                isSelected: selection == .lecture,
                background: Tokens.Gradients.lecture,
                action: { selection = .lecture }
            )
            
            // Meeting Option
            ModePillButton(
                title: "会議",
                icon: "person.2.fill",
                isSelected: selection == .meeting,
                background: Tokens.Gradients.meeting,
                action: { selection = .meeting }
            )
        }
    }
}

private struct ModePillButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let background: LinearGradient
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                action()
            }
        }) {
            HStack(spacing: Tokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(Tokens.Typography.modePill())
                Text(title)
                    .font(Tokens.Typography.modePill())
            }
            .foregroundStyle(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: Tokens.Sizing.buttonCompactHeight)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(background)
                            .matchedGeometryEffect(id: "PillBg", in: namespace)
                    } else {
                        Capsule()
                            .fill(Tokens.Color.surface)
                            .overlay(
                                Capsule()
                                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                            )
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
    }
    
    // Namespace technically needs to be passed down or shared if we want the background to "slide" between them.
    // If they are separate buttons side-by-side, we can use matchedGeometryEffect if we share the namespace.
    // However, since they are distinct hierarchy items (Left vs Right), sharing namespace is good for sliding effect.
    // But here I'll just use fade/scale for simplicity unless sliding is critically requested.
    // "Animation: easeInOut... for color and slight scale" -> Simple transition is fine.
    
    @Namespace private var namespace
}
