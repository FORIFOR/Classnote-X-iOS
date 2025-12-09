import SwiftUI

// MARK: - Meeting Mode Tab Enum

enum MeetingTab: String, CaseIterable {
    case timeline = "タイムライン"
    case decisions = "決定"
    case todos = "ToDo"
    case minutes = "議事録"
    
    var icon: String {
        switch self {
        case .timeline: return "waveform"
        case .decisions: return "checkmark.seal.fill"
        case .todos: return "checklist"
        case .minutes: return "doc.text.fill"
        }
    }
}

// MARK: - Meeting Tabs Container

struct MeetingTabsView: View {
    let session: Session
    @Binding var playbackTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    @State private var selectedTab: MeetingTab = .timeline
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab Picker
            HStack(spacing: 0) {
                ForEach(MeetingTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.subheadline)
                            Text(tab.rawValue)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(selectedTab == tab ? GlassNotebook.Accent.meeting : GlassNotebook.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab 
                                ? GlassNotebook.Accent.meeting.opacity(0.12) 
                                : Color.clear
                        )
                    }
                }
            }
            .background(GlassNotebook.Background.elevated)
            
            // Tab Content
            TabView(selection: $selectedTab) {
                // Timeline Tab
                TimelineTabContent(
                    session: session,
                    currentTime: playbackTime,
                    onSeek: onSeek
                )
                .tag(MeetingTab.timeline)
                
                // Decisions Tab
                DecisionsTabView(
                    decisions: session.decisions,
                    chapters: session.chapters,
                    onSeek: onSeek
                )
                .tag(MeetingTab.decisions)
                
                // ToDo Tab
                TodoTabView(
                    tasks: session.tasks,
                    decisions: session.decisions,
                    onSeek: onSeek
                )
                .tag(MeetingTab.todos)
                
                // Minutes Tab
                MinutesTabView(
                    session: session
                )
                .tag(MeetingTab.minutes)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

// MARK: - Timeline Tab Content

struct TimelineTabContent: View {
    let session: Session
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    // Adapter for DiarizedTranscriptView
    private var displaySegments: [DiarizedSegment] {
        if !session.diarizedSegments.isEmpty {
            return session.diarizedSegments
        }
        // Fallback for legacy segments
        return (session.segments ?? []).map { seg in
            DiarizedSegment(
                id: seg.id,
                start: seg.start,
                end: seg.end,
                speakerId: seg.speaker,
                text: seg.text
            )
        }
    }
    
    private var displaySpeakers: [Speaker] {
        if !session.speakers.isEmpty {
            return session.speakers
        }
        // Generate dummy speakers from segments
        let uniqueIDs = Set((session.segments ?? []).map { $0.speaker })
        return uniqueIDs.sorted().map { id in
            Speaker(id: id, label: id, displayName: "話者 \(id)")
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Chapters (if available)
                if !session.chapters.isEmpty {
                    ChapterTimelineView(
                        chapters: session.chapters,
                        currentTime: currentTime,
                        onSeek: onSeek
                    )
                }
                
                // Speaker segments (if available) - using new DiarizedTranscriptView
                if !displaySegments.isEmpty {
                    DiarizedTranscriptView(
                        segments: displaySegments,
                        speakers: displaySpeakers,
                        currentTime: currentTime,
                        onSeek: onSeek
                    )
                }
                
                // AI Tags (if available)
                if !session.aiTags.isEmpty {
                    AITagsSection(
                        aiTags: session.aiTags,
                        currentTime: currentTime,
                        onSeek: onSeek
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - AI Tags Section

struct AITagsSection: View {
    let aiTags: [AITimelineTag]
    let currentTime: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AIタグ", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(aiTags.count)件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            FlowLayout(spacing: 8) {
                ForEach(aiTags) { tag in
                    AITagChip(
                        tag: tag,
                        isActive: isActive(tag),
                        onTap: { onSeek(tag.timeSeconds) }
                    )
                }
            }
        }
        .padding(16)
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    private func isActive(_ tag: AITimelineTag) -> Bool {
        abs(currentTime - tag.timeSeconds) < 5
    }
}

// MARK: - AI Tag Chip

struct AITagChip: View {
    let tag: AITimelineTag
    let isActive: Bool
    let onTap: () -> Void
    
    private var chipColor: Color {
        switch tag.type {
        case .decision: return .blue
        case .todo: return .red
        case .topic: return .orange
        case .question: return .green
        case .casual: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: tag.type.icon)
                    .font(.caption2)
                
                Text(tag.type.rawValue)
                    .font(.caption.weight(.medium))
                
                Text(tag.timeSeconds.mmssString)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(chipColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(chipColor.opacity(isActive ? 0.2 : 0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isActive ? chipColor : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    MeetingTabsView(
        session: Session(
            id: "test",
            title: "AI倫理会議",
            mode: "meeting",
            status: "transcribed",
            transcriptText: nil,
            summary: nil,
            quizMarkdown: nil,
            createdAt: Date(),
            chapters: [
                ChapterMarker(timeSeconds: 0, title: "導入"),
                ChapterMarker(timeSeconds: 120, title: "議題1")
            ],
            decisions: [
                MeetingDecision(content: "AI倫理ガイドライン作成", assignee: "佐藤", timeStart: 60, timeEnd: 90)
            ],
            tasks: [
                MeetingTask(title: "ドラフト作成", assignee: "佐藤", priority: 4)
            ]
        ),
        playbackTime: .constant(30),
        onSeek: { _ in }
    )
}
