import SwiftUI

// MARK: - Empty State View

/// A placeholder view for empty content states with icon, message, and action button
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String?
    let actionTitle: String?
    let isLoading: Bool
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String? = nil,
        actionTitle: String? = nil,
        isLoading: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        AppCard {
            VStack(spacing: Tokens.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(Tokens.Typography.iconLarge())
                    .foregroundStyle(Tokens.Color.textSecondary)

                // Title
                AppText(title, style: .sectionTitle, color: Tokens.Color.textPrimary)
                    .multilineTextAlignment(.center)

                // Message
                if let message = message {
                    AppText(message, style: .body, color: Tokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Action Button
                if let actionTitle = actionTitle, let action = action {
                    GradientActionButton(
                        actionTitle,
                        isLoading: isLoading,
                        action: action
                    )
                    .padding(.top, Tokens.Spacing.xs)
                }
            }
            .padding(Tokens.Spacing.lg)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Loading State View

/// A loading placeholder with spinner
struct LoadingStateView: View {
    let message: String

    init(_ message: String = "読み込み中...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: Tokens.Spacing.md) {
            ProgressView()
                .scaleEffect(1.2)

            AppText(message, style: .body, color: Tokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

/// An error state with retry action
struct ErrorStateView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        EmptyStateView(
            icon: "exclamationmark.triangle",
            title: "エラーが発生しました",
            message: message,
            actionTitle: "再試行",
            action: retryAction
        )
    }
}

// MARK: - Preview
