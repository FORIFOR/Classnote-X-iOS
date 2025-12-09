import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedMode: SessionMode = .lecture
    @State private var query: String = ""
    @State private var animateContent = false
    @State private var selection = Set<String>()
    @State private var showDeleteConfirm = false
    @State private var isEditing = false  // Changed from @Environment

    var body: some View {
        ZStack {
            GlassNotebook.Background.primary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Mode picker
                Picker("モード", selection: $selectedMode) {
                    Label("講義", systemImage: "book.fill").tag(SessionMode.lecture)
                    Label("会議", systemImage: "person.2.fill").tag(SessionMode.meeting)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                if filteredSessions.isEmpty {
                    emptyState
                } else {
                    sessionsList
                }
            }
        }
        .navigationTitle("セッション")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "タイトルで検索")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(isEditing ? "完了" : "編集") {
                    withAnimation {
                        isEditing.toggle()
                        if !isEditing {
                            selection.removeAll()
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing && !selection.isEmpty {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("\(selection.count)")
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "\(selection.count)件のセッションを削除しますか？",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                Task {
                    await deleteSessions()
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません")
        }
        .onAppear {
            print("[SessionsView] ========== VIEW APPEARED ==========")
            print("[SessionsView] Selected mode: \(selectedMode.rawValue)")
            print("[SessionsView] model.lectures count: \(model.lectures.count)")
            print("[SessionsView] model.meetings count: \(model.meetings.count)")
            
            if model.lectures.isEmpty && model.meetings.isEmpty {
                print("[SessionsView] ⚠️ No sessions in AppModel")
                print("[SessionsView] Will fetch from REST API...")
            } else {
                print("[SessionsView] ✅ Sessions available:")
                for (i, lecture) in model.lectures.prefix(5).enumerated() {
                    print("[SessionsView]   Lecture \(i+1): id=\(lecture.wrappedId), title=\(lecture.title ?? "nil"), date=\(lecture.createdAt?.description ?? "nil")")
                }
                for (i, meeting) in model.meetings.prefix(5).enumerated() {
                    print("[SessionsView]   Meeting \(i+1): id=\(meeting.wrappedId), title=\(meeting.title ?? "nil"), date=\(meeting.createdAt?.description ?? "nil")")
                }
            }
            
            print("[SessionsView] filteredSessions count: \(filteredSessions.count)")
            print("[SessionsView] ========== END ==========")
            
            withAnimation(.smoothSpring.delay(0.1)) {
                animateContent = true
            }
        }
        .task {
            // Fetch sessions from REST API instead of relying on Firestore
            await model.reloadSessionsFromAPI()
        }
        .onChange(of: selectedMode) { _, _ in
            selection.removeAll()
        }
    }
    
    private func deleteSessions() async {
        let idsToDelete = Array(selection)
        print("[SessionsView] Deleting \(idsToDelete.count) sessions...")
        
        // Call API to delete from server
        let apiClient = ClassnoteAPIClient(baseURL: URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!)
        try? await apiClient.batchDeleteSessions(ids: idsToDelete)
        
        // Remove from local model
        await MainActor.run {
            if selectedMode == .lecture {
                model.lectures.removeAll { idsToDelete.contains($0.id) }
            } else {
                model.meetings.removeAll { idsToDelete.contains($0.id) }
            }
            
            selection.removeAll()
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        
        print("[SessionsView] ✅ Deleted \(idsToDelete.count) sessions")
    }
    
    private var emptyState: some View {
        VStack {
            Spacer()
            
            EmptyStateView(
                icon: selectedMode == .lecture ? "book.closed" : "person.2.slash",
                title: query.isEmpty ? "セッションがありません" : "検索結果がありません",
                message: query.isEmpty 
                    ? "録音後に自動でここに追加されます" 
                    : "「\(query)」に一致するセッションが見つかりませんでした"
            )
            
            Spacer()
        }
        .opacity(animateContent ? 1 : 0)
    }
    
    // API Client
    private var apiClient: ClassnoteAPIClient {
        ClassnoteAPIClient(baseURL: URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!)
    }

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredSessions.enumerated()), id: \.element.wrappedId) { index, session in
                    HStack(spacing: 12) {
                        // Show checkbox in edit mode
                        if isEditing {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    if selection.contains(session.wrappedId) {
                                        selection.remove(session.wrappedId)
                                    } else {
                                        selection.insert(session.wrappedId)
                                    }
                                }
                            } label: {
                                Image(systemName: selection.contains(session.wrappedId) ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(selection.contains(session.wrappedId) ? .red : .secondary)
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Session row (with or without navigation)
                        if isEditing {
                            SessionListRow(session: session)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if selection.contains(session.wrappedId) {
                                            selection.remove(session.wrappedId)
                                        } else {
                                            selection.insert(session.wrappedId)
                                        }
                                    }
                                }
                        } else {
                            NavigationLink(destination: SessionDetailView(sessionId: session.wrappedId, apiClient: apiClient)) {
                                SessionListRow(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.smoothSpring.delay(Double(index) * 0.05), value: animateContent)
                    
                    if index < filteredSessions.count - 1 {
                        Divider()
                            .padding(.leading, isEditing ? 84 : 72)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var filteredSessions: [SessionItem] {
        let sessions = selectedMode == .lecture ? model.lectures : model.meetings
        // Filter out "recording" status sessions (stale/incomplete recordings)
        let validSessions = sessions.filter { $0.status != "recording" }
        let sorted = validSessions.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.title?.localizedCaseInsensitiveContains(query) == true }
    }
}

// MARK: - Session List Row

struct SessionListRow: View {
    let session: SessionItem
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Color Line (Lecture=Green, Meeting=Blue)
            RoundedRectangle(cornerRadius: 2)
                .fill(modeColor)
                .frame(width: 4)
                .padding(.vertical, 4)
            
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(modeColor.opacity(0.12))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: session.mode == "meeting" ? "person.2.fill" : "book.fill")
                        .font(.title3)
                        .foregroundStyle(modeColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title ?? "無題")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Mode Tag
                        Text(session.mode == "meeting" ? "会議" : "講義")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(modeColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(modeColor.opacity(0.12))
                            .clipShape(Capsule())
                        
                        // Date
                        if let date = session.createdAt {
                            Text(formattedDate(date))
                                .font(.caption)
                                .foregroundStyle(GlassNotebook.Text.secondary)
                        }
                        
                        // Duration
                        if let duration = session.durationSec {
                            Text("• \(Int(duration/60))分")
                                .font(.caption)
                                .foregroundStyle(GlassNotebook.Text.secondary)
                        }
                    }
                    
                    // Summary preview
                    if let overview = session.summary?.overview {
                        Text(overview)
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GlassNotebook.Text.secondary)
            }
            .padding(.leading, 12)
        }
        .padding(.vertical, 14)
        .padding(.trailing, 16)
        .background(GlassNotebook.Background.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
    }
    
    private var modeColor: Color {
        session.mode == "meeting" ? GlassNotebook.Accent.meeting : GlassNotebook.Accent.lecture
    }
    
    private var statusColor: Color {
        switch session.status {
        case "completed", "done":
            return GlassNotebook.Accent.secondary
        case "processing", "transcribing":
            return Color.orange
        default:
            return GlassNotebook.Text.secondary
        }
    }
    
    private var localizedStatus: String {
        switch session.status {
        case "completed", "done": return "完了"
        case "processing": return "処理中"
        case "transcribing": return "文字起こし中"
        default: return session.status ?? "不明"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }
}
