import SwiftUI

struct QuizTab: View {
    @Binding var session: Session
    @Binding var generationError: String?
    let onGenerate: () -> Void
    @State private var isGenerating = false
    @State private var revealedAnswers: Set<String> = []

    private var hasQuiz: Bool {
        guard let quiz = session.quiz else { return false }
        return quiz.hasQuiz && !(quiz.items ?? []).isEmpty
    }

    var body: some View {
        Group {
            if hasQuiz {
                contentView
            } else {
                emptyStateView
            }
        }
        .onChange(of: session.quiz?.hasQuiz) { _, hasQuiz in
            if hasQuiz == true {
                isGenerating = false
                revealedAnswers = []
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
                ForEach(session.quiz?.items ?? []) { item in
                    quizCard(item)
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
                    icon: "brain.head.profile",
                    title: "クイズがまだありません",
                    subtitle: "AIがこのセッションの内容から\nクイズを生成します。",
                    primaryTitle: isGenerating ? "生成中…" : "クイズを生成 (AI)",
                    primaryIcon: "brain.head.profile",
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

    // MARK: - Quiz Card

    private func quizCard(_ item: QuizItem) -> some View {
        let isRevealed = revealedAnswers.contains(item.id)

        return ContentCard {
            VStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                // Question
                Text(item.question)
                    .font(Tokens.Typography.sectionTitle())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Choices
                VStack(alignment: .leading, spacing: Tokens.Spacing.sm) {
                    ForEach(item.choices.indices, id: \.self) { index in
                        choiceRow(
                            index: index,
                            text: item.choices[index],
                            isCorrect: index == item.answerIndex,
                            isRevealed: isRevealed
                        )
                    }
                }

                // Reveal button or feedback
                if isRevealed {
                    if let feedback = item.feedback, !feedback.isEmpty {
                        HStack(spacing: Tokens.Spacing.xs) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(Tokens.Color.accent)
                            Text(feedback)
                                .font(Tokens.Typography.caption())
                                .foregroundStyle(Tokens.Color.textSecondary)
                        }
                        .padding(.top, Tokens.Spacing.xs)
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            revealedAnswers.insert(item.id)
                        }
                        Haptics.light()
                    } label: {
                        Text("答えを見る")
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(Tokens.Color.accent)
                            .padding(.horizontal, Tokens.Spacing.sm)
                            .padding(.vertical, Tokens.Spacing.xs)
                            .background(Tokens.Color.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.button, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Tokens.Spacing.xs)
                }
            }
        }
    }

    private func choiceRow(index: Int, text: String, isCorrect: Bool, isRevealed: Bool) -> some View {
        let choiceLabel = ["A", "B", "C", "D", "E", "F"][safe: index] ?? "\(index + 1)"

        return HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            // Choice indicator
            ZStack {
                Circle()
                    .fill(isRevealed && isCorrect ? Tokens.Color.accent : Tokens.Color.background)
                    .frame(width: 28, height: 28)

                Text(choiceLabel)
                    .font(Tokens.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundStyle(isRevealed && isCorrect ? Tokens.Color.surface : Tokens.Color.textSecondary)
            }

            // Choice text
            Text(text)
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Correct indicator
            if isRevealed && isCorrect {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Tokens.Color.accent)
            }
        }
        .padding(Tokens.Spacing.sm)
        .background(
            isRevealed && isCorrect
                ? Tokens.Color.accent.opacity(0.08)
                : Tokens.Color.background
        )
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.small, style: .continuous))
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
