import SwiftUI

// MARK: - Decisions Tab View

struct DecisionsTabView: View {
    let decisions: [MeetingDecision]
    let chapters: [ChapterMarker]
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        ScrollView {
            if decisions.isEmpty {
                EmptyDecisionsView()
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(groupedDecisions.keys.sorted(), id: \.self) { chapterId in
                        if let chapterDecisions = groupedDecisions[chapterId] {
                            DecisionGroupView(
                                chapterTitle: chapterTitle(for: chapterId),
                                decisions: chapterDecisions,
                                onSeek: onSeek
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
    }
    
    // Group decisions by chapter
    private var groupedDecisions: [String: [MeetingDecision]] {
        Dictionary(grouping: decisions) { decision in
            decision.chapterId ?? "other"
        }
    }
    
    private func chapterTitle(for id: String) -> String {
        if id == "other" { return "その他" }
        return chapters.first { $0.id == id }?.title ?? "セクション"
    }
}

// MARK: - Empty Decisions View

struct EmptyDecisionsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("決定事項がありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("会議で決定された事項がここに表示されます")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Decision Group View

struct DecisionGroupView: View {
    let chapterTitle: String
    let decisions: [MeetingDecision]
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(GlassNotebook.Accent.lecture)
                Text(chapterTitle)
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            // Decision Cards
            ForEach(Array(decisions.enumerated()), id: \.element.id) { index, decision in
                DecisionCard(
                    number: index + 1,
                    decision: decision,
                    onSeek: { onSeek(decision.timeStart) }
                )
            }
        }
        .padding(16)
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Decision Card

struct DecisionCard: View {
    let number: Int
    let decision: MeetingDecision
    let onSeek: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd"
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                // Number badge
                Text("決定 #\(number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(GlassNotebook.Accent.meeting))
                
                Spacer()
                
                // Play button
                Button(action: onSeek) {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                        Text(decision.timeStart.mmssString)
                            .font(.caption.monospacedDigit())
                    }
                    .foregroundStyle(GlassNotebook.Accent.primary)
                }
            }
            
            // Content
            Text(decision.content)
                .font(.body)
                .foregroundStyle(.primary)
            
            // Metadata
            HStack(spacing: 16) {
                // Assignee
                if let assignee = decision.assignee {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                        Text(assignee)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.orange)
                }
                
                // Due date
                if let dueDate = decision.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(dateFormatter.string(from: dueDate))
                            .font(.caption)
                    }
                    .foregroundStyle(GlassNotebook.Text.secondary)
                }
                
                Spacer()
            }
        }
        .padding(14)
        .background(GlassNotebook.Background.elevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    DecisionsTabView(
        decisions: [
            MeetingDecision(
                content: "AI倫理ガイドライン案を次回までに作成",
                assignee: "佐藤",
                dueDate: Date().addingTimeInterval(86400 * 7),
                timeStart: 623,
                timeEnd: 765,
                chapterId: "ch1"
            ),
            MeetingDecision(
                content: "社内勉強会を月1で開催",
                assignee: "山田",
                timeStart: 1201,
                timeEnd: 1270,
                chapterId: "ch1"
            )
        ],
        chapters: [
            ChapterMarker(id: "ch1", timeSeconds: 0, title: "AI倫理導入")
        ],
        onSeek: { _ in }
    )
}
