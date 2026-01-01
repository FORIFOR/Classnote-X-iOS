import SwiftUI
import UIKit

struct SummaryTab: View {
    @Binding var session: Session
    @Binding var generationError: String?
    let onGenerate: () -> Void

    @State private var showCopied = false
    @State private var isGenerating = false

    private var hasSummary: Bool {
        guard let summary = session.summary else { return false }
        return summary.hasSummary && !(summary.text ?? "").isEmpty
    }

    var body: some View {
        Group {
            if hasSummary {
                contentView
            } else {
                emptyStateView
            }
        }
        .overlay(alignment: .top) {
            ToastOverlay(message: "コピーしました", isVisible: showCopied)
                .padding(.top, Tokens.Spacing.md)
        }
        .onChange(of: session.summary?.hasSummary) { _, hasSummary in
            if hasSummary == true {
                isGenerating = false
            }
        }
        .onChange(of: generationError) { _, error in
            if error != nil {
                isGenerating = false
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        TabContentWrapper {
            VStack(spacing: Tokens.Spacing.md) {
                ContentCard {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                        HStack {
                            Spacer()
                            CopyButton {
                                copySummary()
                            }
                        }

                        Text(session.summary?.text ?? "")
                            .font(Tokens.Typography.body())
                            .foregroundStyle(Tokens.Color.textPrimary)
                            .lineSpacing(Tokens.Spacing.xxs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                SecondaryActionButton(
                    isGenerating ? "生成中…" : "もう一度生成",
                    icon: "arrow.clockwise",
                    isLoading: isGenerating,
                    isDisabled: isGenerating
                ) {
                    isGenerating = true
                    onGenerate()
                }
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        EmptyStateContainer {
            VStack {
                Spacer()
                EmptyAIStateCard(
                    icon: "sparkles",
                    title: "要約がまだありません",
                    subtitle: "AIがこのセッションを要約します。",
                    primaryTitle: isGenerating ? "生成中…" : "要約を生成 (AI)",
                    primaryIcon: "sparkles",
                    isLoading: isGenerating,
                    onPrimary: {
                        isGenerating = true
                        onGenerate()
                    }
                )
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func copySummary() {
        guard let text = session.summary?.text else { return }
        UIPasteboard.general.string = text
        Haptics.success()
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}
