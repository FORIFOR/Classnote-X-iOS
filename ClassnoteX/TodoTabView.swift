import SwiftUI

// MARK: - ToDo Tab View

struct TodoTabView: View {
    let tasks: [MeetingTask]
    let decisions: [MeetingDecision]
    let onSeek: (TimeInterval) -> Void
    
    @State private var showAddTask = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Add Task Button
                Button {
                    showAddTask = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("新しいToDoを追加")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(GlassNotebook.Accent.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GlassNotebook.Background.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(GlassNotebook.Accent.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    )
                }
                
                if tasks.isEmpty {
                    EmptyTodoView()
                } else {
                    // Task List
                    LazyVStack(spacing: 12) {
                        ForEach(sortedTasks) { task in
                            TaskRow(
                                task: task,
                                relatedDecision: decisions.first { $0.id == task.relatedDecisionId },
                                onSeek: { onSeek(task.timeSeconds) },
                                onToggle: { /* TODO: Toggle completion */ }
                            )
                        }
                    }
                }
            }
            .padding(16)
        }
    }
    
    private var sortedTasks: [MeetingTask] {
        // Incomplete first, then by priority (high to low)
        tasks.sorted { lhs, rhs in
            if lhs.isCompleted != rhs.isCompleted {
                return !lhs.isCompleted
            }
            return lhs.priority > rhs.priority
        }
    }
}

// MARK: - Empty ToDo View

struct EmptyTodoView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("ToDoがありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("会議で抽出されたタスクがここに表示されます")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: MeetingTask
    let relatedDecision: MeetingDecision?
    let onSeek: () -> Void
    let onToggle: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d(E)"
        f.locale = Locale(identifier: "ja_JP")
        return f
    }()
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Title
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                
                // Metadata row
                HStack(spacing: 12) {
                    // Assignee pill
                    if let assignee = task.assignee {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange.gradient)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Text(String(assignee.prefix(1)))
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                )
                            Text(assignee)
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.orange)
                    }
                    
                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dateFormatter.string(from: dueDate))
                                .font(.caption)
                        }
                        .foregroundStyle(isDuesSoon(dueDate) ? .red : .secondary)
                    }
                    
                    Spacer()
                    
                    // Priority stars
                    PriorityStars(priority: task.priority)
                }
                
                // Related decision link
                if let decision = relatedDecision {
                    Button {
                        // TODO: Navigate to decision
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.caption2)
                            Text("関連決定")
                                .font(.caption)
                        }
                        .foregroundStyle(GlassNotebook.Accent.meeting)
                    }
                }
                
                // Play button
                if task.timeSeconds > 0 {
                    Button(action: onSeek) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                            Text(task.timeSeconds.mmssString)
                                .font(.caption.monospacedDigit())
                        }
                        .foregroundStyle(GlassNotebook.Accent.primary)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(task.isCompleted ? Color.gray.opacity(0.08) : GlassNotebook.Background.card)
        )
    }
    
    private func isDuesSoon(_ date: Date) -> Bool {
        date.timeIntervalSinceNow < 86400 * 3 // 3 days
    }
}

// MARK: - Priority Stars

struct PriorityStars: View {
    let priority: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= priority ? "star.fill" : "star")
                    .font(.caption2)
                    .foregroundStyle(index <= priority ? Color.orange : Color.gray.opacity(0.3))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TodoTabView(
        tasks: [
            MeetingTask(
                title: "AI倫理ガイドラインのドラフト作成",
                assignee: "佐藤",
                dueDate: Date().addingTimeInterval(86400 * 5),
                priority: 4,
                isCompleted: false,
                timeSeconds: 623
            ),
            MeetingTask(
                title: "社内勉強会の日程調整",
                assignee: "山田",
                dueDate: Date().addingTimeInterval(86400 * 2),
                priority: 3,
                isCompleted: true,
                timeSeconds: 1201
            )
        ],
        decisions: [],
        onSeek: { _ in }
    )
}
