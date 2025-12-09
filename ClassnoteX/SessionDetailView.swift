import SwiftUI
import AVFoundation
import Combine

struct SessionDetailView: View {
    let sessionId: String
    let apiClient: ClassnoteAPIClient
    @EnvironmentObject var appModel: AppModel
    
    // Playback ViewModel
    @StateObject private var playback: PlaybackViewModel
    
    // View State
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @Environment(\.dismiss) private var dismiss

    init(sessionId: String, apiClient: ClassnoteAPIClient) {
        self.sessionId = sessionId
        self.apiClient = apiClient
        _playback = StateObject(wrappedValue: PlaybackViewModel(sessionId: sessionId))
    }
    
    // Resolve Session from AppModel
    private var session: SessionItem? {
        appModel.sessions.first(where: { $0.id == sessionId })
    }
    
    // Combined or fallback audio URL
    private var audioURL: URL? {
        if let local = localAudioURL {
            return local
        }
        // Remote fallback logic would go here
        return nil
    }

    private var localAudioURL: URL? {
        // Try finding standard filename
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = docDir.appendingPathComponent("audio_\(sessionId).m4a")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        // Use API Client's smarter finder to locate matching file in Recordings
        return apiClient.findLocalAudioFile(sessionId: sessionId, createdAt: session?.createdAt)
    }
    
    // Resolved speaker segments (Session + Local Fallback)
    private var speakerSegments: [SpeakerSegment] {
        if let fromSession = session?.speakerSegments, !fromSession.isEmpty {
            return fromSession
        }
        
        // Fallback: load local
        let local = apiClient.loadLocalSegments(sessionId: sessionId)
        return local.map { seg in
            SpeakerSegment(
                speaker: String(seg.speakerTag ?? 0),
                speakerName: seg.speakerLabel ?? "話者 \(seg.speakerTag ?? 0)",
                start: seg.startTimeSeconds,
                end: seg.endTimeSeconds,
                text: seg.text
            )
        }
    }

    var body: some View {
        ZStack {
            // Background
            GlassNotebook.Background.main
                .ignoresSafeArea()
            
            if let session = session {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        headerView(session: session)
                        
                        // 1. Summary Card
                        if let summary = session.summary {
                            SummaryCardView(
                                title: session.title,
                                overview: summary.overview,
                                points: summary.points,
                                keywords: summary.keywords
                            )
                        } else {
                            // Placeholder or Loading state for summary
                            if session.summary == nil {
                                VStack(spacing: 12) {
                                    ProgressView()
                                    Text("要約を作成中…")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        
                        // 2. Playback Section
                        PlaybackSectionView(
                            playback: playback,
                            speakerSegments: speakerSegments, // Use computed prop with local fallback
                            chapters: session.chapterMarkers,
                            audioUrl: audioURL
                        )
                        
                        // 3. Notes Section
                        NotesSectionView(
                            playback: playback,
                            notes: session.localNotes ?? [],
                            onAddNote: { text, time in
                                appModel.addNote(text, at: time, to: sessionId)
                            },
                            onTapNote: { note in
                                playback.seek(to: note.timeSec)
                            }
                        )
                        
                        // Bottom Padding
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                }
            } else {
                Text("セッションが見つかりません")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(session?.title ?? "詳細")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("削除しますか？", isPresented: $showingDeleteAlert) {
            Button("削除", role: .destructive) {
                if let index = appModel.sessions.firstIndex(where: { $0.id == sessionId }) {
                    appModel.sessions.remove(at: index)
                    dismiss()
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .onAppear {
            playback.updateDuration()
        }
    }
    
    private func headerView(session: SessionItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(session.title)
                .font(.title2.weight(.bold))
            HStack {
                Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let duration = session.duration {
                    Text("• \(Int(duration / 60))分")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
