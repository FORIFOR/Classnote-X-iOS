import SwiftUI

// MARK: - Session Status Chip Type

enum SessionStatusChip: String, CaseIterable {
    case offline = "オフライン保存中"
    case uploading = "アップロード中"
    case aiGenerating = "AI生成中"
    case hasSummary = "要約あり"
    case sharing = "共有中"
    case syncing = "未同期"

    var icon: String {
        switch self {
        case .offline: return "cloud.fill"
        case .uploading: return "arrow.up.circle"
        case .aiGenerating: return "sparkles"
        case .hasSummary: return "doc.text.fill"
        case .sharing: return "person.2.fill"
        case .syncing: return "arrow.triangle.2.circlepath"
        }
    }

    var color: Color {
        switch self {
        case .offline, .syncing: return Tokens.Color.textSecondary
        case .uploading: return Tokens.Color.accent
        case .aiGenerating: return Color.purple
        case .hasSummary: return Color.green
        case .sharing: return Tokens.Color.accent
        }
    }
}

// MARK: - Status Chip View

struct SessionStatusChipView: View {
    let chip: SessionStatusChip

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: chip.icon)
                .font(.system(size: 9, weight: .medium))

            Text(chip.rawValue)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(chip.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(chip.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Status Chip Row

struct StatusChipRow: View {
    let chips: [SessionStatusChip]
    let maxVisible: Int

    init(chips: [SessionStatusChip], maxVisible: Int = 3) {
        self.chips = chips
        self.maxVisible = maxVisible
    }

    var body: some View {
        if chips.isEmpty {
            EmptyView()
        } else {
            HStack(spacing: Tokens.Spacing.xxs) {
                ForEach(visibleChips, id: \.rawValue) { chip in
                    SessionStatusChipView(chip: chip)
                }

                if remainingCount > 0 {
                    Text("+\(remainingCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Tokens.Color.textTertiary)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private var visibleChips: [SessionStatusChip] {
        Array(chips.prefix(maxVisible))
    }

    private var remainingCount: Int {
        max(0, chips.count - maxVisible)
    }
}

// MARK: - Session Status Chip Helpers

extension Session {
    /// Compute applicable status chips based on session state
    var statusChips: [SessionStatusChip] {
        var chips: [SessionStatusChip] = []

        // Check audio upload status
        if audioStatus == .uploading {
            chips.append(.uploading)
        }

        // Check if processing (AI generation)
        if status == .processing {
            chips.append(.aiGenerating)
        }

        // Check if has summary
        if summary?.hasSummary == true {
            chips.append(.hasSummary)
        }

        // Check if shared
        if let sharing = sharing, sharing.memberCount > 0 {
            chips.append(.sharing)
        }

        return chips
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        StatusChipRow(chips: [.aiGenerating, .sharing])
        StatusChipRow(chips: [.hasSummary])
        StatusChipRow(chips: [.uploading, .aiGenerating, .sharing, .hasSummary], maxVisible: 2)
        StatusChipRow(chips: [])
    }
    .padding()
}
