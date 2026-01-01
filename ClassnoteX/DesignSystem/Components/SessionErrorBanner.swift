import SwiftUI

// MARK: - Session Error Type

enum SessionErrorType: Equatable {
    case sessionCreationFailed(String)
    case audioPlaybackFailed(String)
    case syncFailed(String)
    case aiGenerationFailed(String)
    case networkError(String)
    case generic(String)

    var icon: String {
        switch self {
        case .sessionCreationFailed: return "exclamationmark.triangle.fill"
        case .audioPlaybackFailed: return "speaker.slash.fill"
        case .syncFailed: return "arrow.triangle.2.circlepath"
        case .aiGenerationFailed: return "sparkles"
        case .networkError: return "wifi.slash"
        case .generic: return "exclamationmark.circle.fill"
        }
    }

    var title: String {
        switch self {
        case .sessionCreationFailed: return "セッション作成に失敗"
        case .audioPlaybackFailed: return "音声再生エラー"
        case .syncFailed: return "同期に失敗"
        case .aiGenerationFailed: return "AI生成エラー"
        case .networkError: return "ネットワークエラー"
        case .generic: return "エラー"
        }
    }

    var message: String {
        switch self {
        case .sessionCreationFailed(let msg),
             .audioPlaybackFailed(let msg),
             .syncFailed(let msg),
             .aiGenerationFailed(let msg),
             .networkError(let msg),
             .generic(let msg):
            return msg
        }
    }
}

// MARK: - Error Action

struct SessionErrorAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String?
    let style: ActionStyle
    let action: () -> Void

    enum ActionStyle {
        case primary
        case secondary
        case destructive
    }
}

// MARK: - Session Error Banner

struct SessionErrorBanner: View {
    let errorType: SessionErrorType
    let actions: [SessionErrorAction]
    let onDismiss: (() -> Void)?

    init(
        errorType: SessionErrorType,
        actions: [SessionErrorAction],
        onDismiss: (() -> Void)? = nil
    ) {
        self.errorType = errorType
        self.actions = actions
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
            // Header row
            HStack(spacing: Tokens.Spacing.xs) {
                Image(systemName: errorType.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Color.destructive)

                Text(errorType.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)

                Spacer()

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.Color.textTertiary)
                            .frame(width: 24, height: 24)
                            .background(Tokens.Color.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Message
            Text(errorType.message)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Color.textSecondary)
                .lineLimit(3)

            // Actions
            if !actions.isEmpty {
                HStack(spacing: Tokens.Spacing.xs) {
                    ForEach(actions) { action in
                        errorActionButton(action)
                    }
                }
            }
        }
        .padding(Tokens.Spacing.md)
        .background(Tokens.Color.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
                .stroke(Tokens.Color.destructive.opacity(0.2), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func errorActionButton(_ action: SessionErrorAction) -> some View {
        Button(action: {
            Haptics.light()
            action.action()
        }) {
            HStack(spacing: 4) {
                if let icon = action.icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(action.title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(actionForeground(action.style))
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(actionBackground(action.style))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func actionForeground(_ style: SessionErrorAction.ActionStyle) -> Color {
        switch style {
        case .primary: return .white
        case .secondary: return Tokens.Color.textPrimary
        case .destructive: return Tokens.Color.destructive
        }
    }

    private func actionBackground(_ style: SessionErrorAction.ActionStyle) -> Color {
        switch style {
        case .primary: return Tokens.Color.accent
        case .secondary: return Tokens.Color.surface
        case .destructive: return Tokens.Color.destructive.opacity(0.15)
        }
    }
}

// MARK: - Convenience Initializers

extension SessionErrorBanner {
    /// Quick initializer for sync errors with retry action
    static func syncError(message: String, onRetry: @escaping () -> Void, onDismiss: (() -> Void)? = nil) -> SessionErrorBanner {
        SessionErrorBanner(
            errorType: .syncFailed(message),
            actions: [
                SessionErrorAction(title: "再同期", icon: "arrow.clockwise", style: .primary, action: onRetry)
            ],
            onDismiss: onDismiss
        )
    }

    /// Quick initializer for audio playback errors
    static func audioError(
        message: String,
        onRetry: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) -> SessionErrorBanner {
        SessionErrorBanner(
            errorType: .audioPlaybackFailed(message),
            actions: [
                SessionErrorAction(title: "再試行", icon: "arrow.clockwise", style: .primary, action: onRetry),
                SessionErrorAction(title: "削除", icon: "trash", style: .destructive, action: onDelete)
            ],
            onDismiss: onDismiss
        )
    }

    /// Quick initializer for network errors
    static func networkError(message: String, onRetry: @escaping () -> Void, onDismiss: (() -> Void)? = nil) -> SessionErrorBanner {
        SessionErrorBanner(
            errorType: .networkError(message),
            actions: [
                SessionErrorAction(title: "再試行", icon: "arrow.clockwise", style: .primary, action: onRetry)
            ],
            onDismiss: onDismiss
        )
    }
}

// MARK: - Inline Error View (Compact version)

struct InlineErrorView: View {
    let message: String
    let onRetry: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Tokens.Color.destructive)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(Tokens.Color.textSecondary)
                .lineLimit(2)

            Spacer()

            if let onRetry {
                Button(action: {
                    Haptics.light()
                    onRetry()
                }) {
                    Text("再試行")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Tokens.Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Tokens.Spacing.sm)
        .background(Tokens.Color.destructive.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SessionErrorBanner(
                errorType: .syncFailed("サーバーに接続できませんでした"),
                actions: [
                    SessionErrorAction(title: "再同期", icon: "arrow.clockwise", style: .primary, action: {}),
                    SessionErrorAction(title: "後で", icon: nil, style: .secondary, action: {})
                ],
                onDismiss: {}
            )

            SessionErrorBanner.audioError(
                message: "音声ファイルが見つかりません",
                onRetry: {},
                onDelete: {}
            )

            SessionErrorBanner.networkError(
                message: "インターネット接続を確認してください",
                onRetry: {},
                onDismiss: {}
            )

            InlineErrorView(message: "アップロードに失敗しました", onRetry: {})

            InlineErrorView(message: "データの取得に失敗", onRetry: nil)
        }
        .padding()
    }
    .background(Tokens.Color.background)
}
