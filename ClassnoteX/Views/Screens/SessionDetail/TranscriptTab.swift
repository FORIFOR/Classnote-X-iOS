import SwiftUI

struct TranscriptTab: View {
    @Binding var session: Session
    @Binding var generationError: String?
    let canLocalRegenerate: Bool
    let onRegenerate: () -> Void
    let onRegenerateLocal: () -> Void
    let onDiarize: () -> Void
    @State private var isRegenerating = false
    @State private var isLocalRegenerating = false
    @State private var isDiarizing = false
    @State private var showDiarized = true

    private var hasTranscript: Bool {
        if let text = session.transcript?.text ?? session.transcriptText, !text.isEmpty {
            return true
        }
        return session.transcript?.hasTranscript == true
    }

    private var hasDiarizedTranscript: Bool {
        guard let blocks = session.diarizedTranscript, !blocks.isEmpty else { return false }
        return true
    }

    var body: some View {
        Group {
            if hasTranscript {
                contentView
            } else {
                emptyStateView
            }
        }
        .onChange(of: session.transcript?.hasTranscript) { _, hasTranscript in
            if hasTranscript == true {
                isRegenerating = false
                isLocalRegenerating = false
            }
        }
        .onChange(of: session.transcriptText) { _, text in
            if let text, !text.isEmpty {
                isRegenerating = false
                isLocalRegenerating = false
            }
        }
        .onChange(of: session.diarizedTranscript) { _, blocks in
            if let blocks, !blocks.isEmpty {
                isDiarizing = false
                showDiarized = true
            }
        }
        .onChange(of: generationError) { _, error in
            if error != nil {
                isRegenerating = false
                isLocalRegenerating = false
                isDiarizing = false
            }
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        TabContentWrapper {
            VStack(spacing: Tokens.Spacing.md) {
                if hasDiarizedTranscript {
                    viewToggle
                }

                if showDiarized && hasDiarizedTranscript {
                    diarizedView
                } else {
                    plainTextView
                }

                actionButtons
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        let canRegenerate = session.hasAudio && !isRegenerating
        return EmptyStateContainer {
            VStack {
                Spacer()
                EmptyAIStateCard(
                    icon: "text.alignleft",
                    title: "文字起こしがありません",
                    subtitle: "音声がある場合に生成できます。",
                    primaryTitle: isRegenerating ? "生成中…" : "文字起こしを生成 (AI)",
                    primaryIcon: "waveform",
                    isLoading: isRegenerating,
                    isPrimaryDisabled: !canRegenerate,
                    secondaryTitle: canLocalRegenerate ? "ローカルで再生成" : nil,
                    isSecondaryDisabled: !canLocalRegenerate || isLocalRegenerating,
                    onPrimary: {
                        isRegenerating = true
                        onRegenerate()
                    },
                    onSecondary: canLocalRegenerate ? {
                        isLocalRegenerating = true
                        onRegenerateLocal()
                    } : nil
                )
                Spacer()
            }
        }
    }

    // MARK: - View Toggle

    private var viewToggle: some View {
        HStack(spacing: Tokens.Spacing.xs) {
            ToggleButton(
                title: "話者別",
                icon: "person.2.fill",
                isSelected: showDiarized
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDiarized = true
                }
            }

            ToggleButton(
                title: "テキスト",
                icon: "text.alignleft",
                isSelected: !showDiarized
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showDiarized = false
                }
            }

            Spacer()
        }
    }

    // MARK: - Diarized View

    private var diarizedView: some View {
        ContentCard {
            LazyVStack(alignment: .leading, spacing: Tokens.Spacing.md) {
                ForEach(session.diarizedTranscript ?? []) { block in
                    DiarizedBlockRow(block: block)
                }
            }
        }
    }

    // MARK: - Plain Text View

    private var plainTextView: some View {
        ContentCard {
            Text(session.transcript?.text ?? session.transcriptText ?? "")
                .font(Tokens.Typography.body())
                .foregroundStyle(Tokens.Color.textPrimary)
                .lineSpacing(Tokens.Spacing.xxs)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        ActionButtonsRow(buttons: actionButtonConfigs)
    }

    private var actionButtonConfigs: [ActionButtonsRow.ActionButtonConfig] {
        var configs: [ActionButtonsRow.ActionButtonConfig] = []

        if canLocalRegenerate {
            configs.append(.init(
                title: isLocalRegenerating ? "処理中…" : "ローカル再生成",
                icon: "waveform",
                isLoading: isLocalRegenerating,
                isDisabled: !canLocalRegenerate || isLocalRegenerating
            ) {
                isLocalRegenerating = true
                onRegenerateLocal()
            })
        }

        if !hasDiarizedTranscript {
            configs.append(.init(
                title: isDiarizing ? "分離中…" : "話者分離",
                icon: "person.2.fill",
                isLoading: isDiarizing,
                isDisabled: !hasTranscript || isDiarizing
            ) {
                isDiarizing = true
                onDiarize()
            })
        }

        configs.append(.init(
            title: isRegenerating ? "生成中…" : "再生成",
            icon: "arrow.clockwise",
            isLoading: isRegenerating,
            isDisabled: !session.hasAudio || isRegenerating
        ) {
            isRegenerating = true
            onRegenerate()
        })

        return configs
    }
}

// MARK: - Toggle Button

private struct ToggleButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Spacing.xxs) {
                Image(systemName: icon)
                    .font(Tokens.Typography.caption())
                Text(title)
            }
            .font(Tokens.Typography.caption())
            .foregroundStyle(isSelected ? Tokens.Color.surface : Tokens.Color.textSecondary)
            .padding(.horizontal, Tokens.Spacing.sm)
            .padding(.vertical, Tokens.Spacing.xs)
            .background(isSelected ? Tokens.Color.accent : Tokens.Color.surface)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : Tokens.Color.border, lineWidth: Tokens.Border.thin)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Diarized Block Row

private struct DiarizedBlockRow: View {
    let block: TranscriptBlock

    private var speakerColor: Color {
        let hash = abs(block.speaker.hashValue)
        let colors: [Color] = [
            .blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint
        ]
        return colors[hash % colors.count]
    }

    private var formattedTime: String {
        let minutes = Int(block.startTime) / 60
        let seconds = Int(block.startTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Spacing.sm) {
            VStack(spacing: Tokens.Spacing.xxs) {
                Circle()
                    .fill(speakerColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(speakerInitial)
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(.white)
                    )

                Text(formattedTime)
                    .font(Tokens.Typography.dateCaps())
                    .foregroundStyle(Tokens.Color.textTertiary)
                    .monospacedDigit()
            }
            .frame(width: 48)

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxs) {
                Text(block.speaker)
                    .font(Tokens.Typography.caption())
                    .fontWeight(.semibold)
                    .foregroundStyle(speakerColor)

                Text(block.text)
                    .font(Tokens.Typography.body())
                    .foregroundStyle(Tokens.Color.textPrimary)
                    .lineSpacing(Tokens.Spacing.xxs)
            }
        }
        .padding(.vertical, Tokens.Spacing.xs)
    }

    private var speakerInitial: String {
        if block.speaker.hasPrefix("Speaker") || block.speaker.hasPrefix("話者") {
            let number = block.speaker.filter { $0.isNumber }
            if !number.isEmpty {
                return String(number.prefix(1))
            }
        }
        return String(block.speaker.prefix(1)).uppercased()
    }
}
