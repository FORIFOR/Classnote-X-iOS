import SwiftUI

// MARK: - AI Generation State

enum AIGenerationState: Equatable {
    case notGenerated
    case generating
    case completed
    case failed(String)

    static func == (lhs: AIGenerationState, rhs: AIGenerationState) -> Bool {
        switch (lhs, rhs) {
        case (.notGenerated, .notGenerated): return true
        case (.generating, .generating): return true
        case (.completed, .completed): return true
        case (.failed(let l), .failed(let r)): return l == r
        default: return false
        }
    }
}

// MARK: - AI Generation State View

struct AIGenerationStateView<Content: View>: View {
    let state: AIGenerationState
    let featureName: String
    let icon: String
    let onGenerate: () -> Void
    let onRetry: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        switch state {
        case .notGenerated:
            AIEmptyStateCard(
                icon: icon,
                featureName: featureName,
                onGenerate: onGenerate
            )

        case .generating:
            AIGeneratingView(featureName: featureName)

        case .completed:
            content()

        case .failed(let errorMessage):
            AIErrorStateCard(
                featureName: featureName,
                errorMessage: errorMessage,
                onRetry: onRetry
            )
        }
    }
}

// MARK: - Empty State Card

private struct AIEmptyStateCard: View {
    let icon: String
    let featureName: String
    let onGenerate: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(Tokens.Gradients.ai.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Gradients.ai)
            }

            // Text
            VStack(spacing: Tokens.Spacing.xxs) {
                Text("\(featureName)がまだありません")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)

                Text("AIが自動で生成します")
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }

            // Generate Button
            Button(action: {
                Haptics.light()
                onGenerate()
            }) {
                HStack(spacing: Tokens.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                    Text("\(featureName)を生成")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Tokens.Spacing.lg)
                .padding(.vertical, Tokens.Spacing.sm)
                .background(Tokens.Gradients.ai)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Generating View (Skeleton)

private struct AIGeneratingView: View {
    let featureName: String
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
            // Skeleton lines
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Tokens.Color.border)
                    .frame(height: 14)
                    .frame(maxWidth: index == 3 ? 180 : .infinity)
                    .opacity(shimmer ? 0.4 : 0.8)
            }

            Spacer().frame(height: Tokens.Spacing.xs)

            // Progress indicator
            HStack(spacing: Tokens.Spacing.xs) {
                ProgressView()
                    .scaleEffect(0.8)

                Text("\(featureName)を生成中...")
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Tokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

// MARK: - Error State Card

private struct AIErrorStateCard: View {
    let featureName: String
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Spacing.md) {
            // Error Icon
            ZStack {
                Circle()
                    .fill(Tokens.Color.destructive.opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Tokens.Color.destructive)
            }

            // Text
            VStack(spacing: Tokens.Spacing.xxs) {
                Text("\(featureName)の生成に失敗しました")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)

                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Tokens.Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            // Retry Button
            Button(action: {
                Haptics.light()
                onRetry()
            }) {
                HStack(spacing: Tokens.Spacing.xxs) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("再試行")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(Tokens.Color.accent)
                .padding(.horizontal, Tokens.Spacing.md)
                .padding(.vertical, Tokens.Spacing.xs)
                .background(Tokens.Color.accent.opacity(0.1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(Tokens.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Tokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Convenience Initializer

extension AIGenerationStateView where Content == EmptyView {
    init(
        state: AIGenerationState,
        featureName: String,
        icon: String,
        onGenerate: @escaping () -> Void,
        onRetry: @escaping () -> Void
    ) {
        self.state = state
        self.featureName = featureName
        self.icon = icon
        self.onGenerate = onGenerate
        self.onRetry = onRetry
        self.content = { EmptyView() }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            AIGenerationStateView(
                state: .notGenerated,
                featureName: "文字起こし",
                icon: "text.alignleft",
                onGenerate: {},
                onRetry: {}
            ) {
                Text("Content here")
            }

            AIGenerationStateView(
                state: .generating,
                featureName: "要約",
                icon: "doc.text",
                onGenerate: {},
                onRetry: {}
            ) {
                Text("Content here")
            }

            AIGenerationStateView(
                state: .failed("ネットワークエラーが発生しました"),
                featureName: "クイズ",
                icon: "questionmark.circle",
                onGenerate: {},
                onRetry: {}
            ) {
                Text("Content here")
            }
        }
        .padding()
    }
    .background(Color.gray.opacity(0.1))
}
