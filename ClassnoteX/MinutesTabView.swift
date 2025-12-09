import SwiftUI

// MARK: - Minutes Tab View

struct MinutesTabView: View {
    let session: Session
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Overview
                minutesSection(
                    title: "概要",
                    icon: "doc.text.fill",
                    color: GlassNotebook.Accent.meeting
                ) {
                    if let summary = session.meetingSummary {
                        Text(summary.overview)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else if let summary = session.summary {
                        Text(summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("サマリーがまだ生成されていません")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Participants
                if let summary = session.meetingSummary, !summary.participants.isEmpty {
                    minutesSection(
                        title: "参加者",
                        icon: "person.3.fill",
                        color: .orange
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(summary.participants, id: \.self) { name in
                                ParticipantChip(name: name)
                            }
                        }
                    }
                }
                
                // Decisions Summary
                if !session.decisions.isEmpty {
                    minutesSection(
                        title: "決定事項",
                        icon: "checkmark.seal.fill",
                        color: GlassNotebook.Accent.lecture
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(session.decisions) { decision in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(GlassNotebook.Accent.lecture)
                                        .font(.subheadline)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(decision.content)
                                            .font(.subheadline)
                                        
                                        if let assignee = decision.assignee {
                                            Text("担当: \(assignee)")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // ToDo Summary
                if !session.tasks.isEmpty {
                    minutesSection(
                        title: "ToDoリスト",
                        icon: "checklist",
                        color: .red
                    ) {
                        let incompleteTasks = session.tasks.filter { !$0.isCompleted }
                        let completedTasks = session.tasks.filter { $0.isCompleted }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(incompleteTasks) { task in
                                TaskSummaryRow(task: task)
                            }
                            
                            if !completedTasks.isEmpty {
                                Divider()
                                
                                Text("完了済み (\(completedTasks.count))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                
                                ForEach(completedTasks) { task in
                                    TaskSummaryRow(task: task)
                                }
                            }
                        }
                    }
                }
                
                // Next Steps
                if let summary = session.meetingSummary, let nextSteps = summary.nextSteps, !nextSteps.isEmpty {
                    minutesSection(
                        title: "次のステップ",
                        icon: "arrow.right.circle.fill",
                        color: GlassNotebook.Accent.primary
                    ) {
                        Text(nextSteps)
                            .font(.body)
                            .foregroundStyle(.primary)
                    }
                }
                
                // Tags
                if !session.tags.isEmpty {
                    minutesSection(
                        title: "タグ",
                        icon: "tag.fill",
                        color: .purple
                    ) {
                        SessionTagsRow(tags: session.tags)
                    }
                }
            }
            .padding(16)
        }
    }
    
    @ViewBuilder
    private func minutesSection<Content: View>(
        title: String,
        icon: String,
        color: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.subheadline)
                
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Task Summary Row

struct TaskSummaryRow: View {
    let task: MeetingTask
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? .green : .secondary)
                .font(.subheadline)
            
            Text(task.title)
                .font(.subheadline)
                .strikethrough(task.isCompleted)
                .foregroundStyle(task.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            if let assignee = task.assignee {
                Text(assignee)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    MinutesTabView(
        session: Session(
            id: "test",
            title: "AI倫理会議",
            mode: "meeting",
            status: "transcribed",
            transcriptText: nil,
            summary: "AI倫理に関する初回ミーティング。ガイドライン作成と社内勉強会の開催が決定した。",
            quizMarkdown: nil,
            createdAt: Date(),
            meetingSummary: MeetingSummary(
                overview: "AI倫理に関する初回ミーティングを実施。公平性とバイアスについて議論し、今後の方針を決定した。",
                participants: ["佐藤", "山田", "鈴木"],
                decisions: ["ガイドライン作成", "勉強会開催"],
                actionItems: [],
                nextSteps: "次回は2週間後に進捗確認ミーティングを実施"
            ),
            tags: [
                SessionTag(text: "AI倫理"),
                SessionTag(text: "ガイドライン")
            ],
            decisions: [
                MeetingDecision(content: "AI倫理ガイドライン作成", assignee: "佐藤", timeStart: 0, timeEnd: 0)
            ],
            tasks: [
                MeetingTask(title: "ドラフト作成", assignee: "佐藤", priority: 4)
            ]
        )
    )
}
