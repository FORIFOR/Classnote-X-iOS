import SwiftUI

// MARK: - Tab Content Wrapper
/// Provides consistent layout structure for all session detail tabs
struct TabContentWrapper<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.top, Tokens.Spacing.md)
                .padding(.bottom, Tokens.Spacing.xl)
        }
    }
}

// MARK: - Empty State Container
/// Centers empty state cards vertically within available space
struct EmptyStateContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .frame(minHeight: proxy.size.height - Tokens.Spacing.xl * 2)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
    }
}

// MARK: - Content Card
/// Standard card for displaying main content (transcript, summary, etc.)
struct ContentCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Tokens.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
    }
}

// MARK: - Secondary Action Button
/// Consistent styling for regenerate/action buttons below content
struct SecondaryActionButton: View {
    let title: String
    let icon: String
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String = "arrow.clockwise",
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xxs) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(Tokens.Color.textSecondary)
                } else {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(Tokens.Typography.caption())
            .foregroundStyle(isDisabled ? Tokens.Color.textTertiary : Tokens.Color.textSecondary)
            .frame(height: Tokens.Sizing.buttonCompactHeight)
            .padding(.horizontal, Tokens.Spacing.md)
            .background(Tokens.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                    .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

// MARK: - Action Buttons Row
/// Horizontal stack of action buttons with consistent spacing
struct ActionButtonsRow: View {
    let buttons: [ActionButtonConfig]

    struct ActionButtonConfig: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let isLoading: Bool
        let isDisabled: Bool
        let action: () -> Void
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Tokens.Spacing.sm) {
                ForEach(buttons) { button in
                    SecondaryActionButton(
                        button.title,
                        icon: button.icon,
                        isLoading: button.isLoading,
                        isDisabled: button.isDisabled,
                        action: button.action
                    )
                }
            }
            VStack(spacing: Tokens.Spacing.xs) {
                ForEach(buttons) { button in
                    SecondaryActionButton(
                        button.title,
                        icon: button.icon,
                        isLoading: button.isLoading,
                        isDisabled: button.isDisabled,
                        action: button.action
                    )
                }
            }
        }
    }
}

// MARK: - Copy Button
/// Compact copy button for top-right of content cards
struct CopyButton: View {
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            Label("コピー", systemImage: "doc.on.doc")
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textSecondary)
                .padding(.horizontal, Tokens.Spacing.sm)
                .padding(.vertical, Tokens.Spacing.xs)
                .background(Tokens.Color.background)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toast Overlay
/// Shows a temporary toast message
struct ToastOverlay: View {
    let message: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Text(message)
                .font(Tokens.Typography.caption())
                .foregroundStyle(Tokens.Color.textPrimary)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.sm)
                .background(Tokens.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous)
                        .stroke(Tokens.Color.border, lineWidth: Tokens.Border.thin)
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
