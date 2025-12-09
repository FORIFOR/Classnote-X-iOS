import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var sessions: [Session] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isNavigatingToRecording = false
    @State private var createdSessionId: String?
    @State private var animateHero = false
    @State private var showModeSelector = false
    @State private var selectedRecordingMode: SessionMode = .lecture
    
    private var apiClient: ClassnoteAPIClient {
        ClassnoteAPIClient(baseURL: URL(string: "https://classnote-api-900324644592.asia-northeast1.run.app")!)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - Header
                    HStack(spacing: 4) {
                        Text("CLASSNOTE")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(GlassNotebook.Accent.primary)
                        Text("-X")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(GlassNotebook.Accent.secondary)
                        Spacer()
                        
                        // Profile Avatar - Navigate to Settings Tab
                        Button {
                            model.selectedTab = 3
                        } label: {
                            Circle()
                                .fill(GlassNotebook.Gradient.hero)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 18, weight: .medium))
                                )
                                .shadow(color: GlassNotebook.Accent.primary.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    
                    // MARK: - Hero Card (Pill Recording Button)
                    Button(action: { showModeSelector = true }) {
                        ZStack {
                            // Glass Background
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(GlassNotebook.Gradient.hero)
                            
                            // Content
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("新しい録音を始める")
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                    
                                    Text("AIがリアルタイムで文字起こし")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.85))
                                }
                                
                                Spacer()
                                
                                // Animated Mic Button
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.2))
                                        .frame(width: 70, height: 70)
                                        .scaleEffect(animateHero ? 1.2 : 1.0)
                                        .opacity(animateHero ? 0.4 : 0.8)
                                    
                                    Circle()
                                        .fill(Color.white.opacity(0.25))
                                        .frame(width: 56, height: 56)
                                    
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        }
                        .frame(height: 140)
                        .shadow(color: GlassNotebook.Accent.primary.opacity(0.35), radius: 20, x: 0, y: 10)
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 20)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                            animateHero = true
                        }
                    }
                    
                    // MARK: - Quick Stats
                    HStack(spacing: 12) {
                        StatCard(icon: "doc.text.fill", value: "\(sessions.count)", label: "録音数", color: AppColors.primaryBlue)
                        StatCard(icon: "clock.fill", value: "--", label: "総時間", color: AppColors.primaryIndigo)
                        StatCard(icon: "checkmark.circle.fill", value: "--", label: "完了", color: AppColors.success)
                    }
                    .padding(.horizontal, 20)
                    
                    // MARK: - Recent Sessions
                    if !sessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("最近の録音")
                                    .font(.headline.weight(.bold))
                                Spacer()
                                Button {
                                    model.selectedTab = 1 // Switch to Sessions tab
                                } label: {
                                    Text("すべて見る")
                                        .font(.subheadline)
                                        .foregroundColor(GlassNotebook.Accent.primary)
                                }
                            }
                            .padding(.horizontal, 24)
                            
                            ForEach(sessions.prefix(5)) { session in
                                NavigationLink(destination: SessionDetailView(sessionId: session.id, apiClient: apiClient)) {
                                    RichSessionRow(session: session)
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .padding(.horizontal, 20)
                        }
                    } else if !isLoading {
                        // Empty State
                        VStack(spacing: 20) {
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 64))
                                .foregroundStyle(
                                    LinearGradient(colors: [AppColors.primaryBlue, AppColors.primaryTeal], startPoint: .top, endPoint: .bottom)
                                )
                                .padding(.top, 40)
                            
                            Text("録音を始めましょう")
                                .font(.title3.weight(.semibold))
                            
                            Text("上のカードをタップして\n最初の講義を記録しましょう")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                            .padding(.vertical, 40)
                    }
                    

                    
                    Spacer(minLength: 100)
                }
            }
            .background(GlassNotebook.Background.primary.ignoresSafeArea())
            .navigationBarHidden(true)
            .task { await fetchSessions() }
            .navigationDestination(isPresented: $isNavigatingToRecording) {
                if let id = createdSessionId {
                    RecordView(sessionId: id, mode: selectedRecordingMode, apiClient: apiClient)
                }
            }
            .sheet(isPresented: $showModeSelector) {
                ModeSelectionSheet(
                    selectedMode: $selectedRecordingMode,
                    onStart: { startNewRecording() }
                )
                .presentationDetents([.height(320)])
            }
        }
    }
    
    private func fetchSessions() {
        Task {
            isLoading = true
            let uid = model.userEmail.isEmpty ? "guest" : model.userEmail
            let allSessions = (try? await apiClient.getSessions(userId: uid)) ?? []
            // Filter out "recording" status sessions (stale/incomplete)
            sessions = allSessions.filter { $0.status != "recording" }
            isLoading = false
        }
    }
    
    private func startNewRecording() {
        print("[HomeView] ========== START NEW RECORDING ==========")
        triggerHaptic(.medium)
        
        Task {
            print("[HomeView] Creating session via API...")
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            let title = "\(formatter.string(from: Date())) 録音"
            let userId = model.userEmail.isEmpty ? "guest" : model.userEmail
            
            do {
                let session = try await apiClient.createSession(title: title, mode: selectedRecordingMode.rawValue, userId: userId)
                print("[HomeView] ✅ Session created: \(session.id)")
                await MainActor.run {
                    createdSessionId = session.id
                    isNavigatingToRecording = true
                    print("[HomeView] Navigation triggered to RecordView")
                }
            } catch {
                print("[HomeView] ❌ API failed: \(error)")
                print("[HomeView] Creating local fallback session...")
                
                // Create a local mock session ID
                let mockId = "local-\(UUID().uuidString.prefix(8))"
                print("[HomeView] Mock session ID: \(mockId)")
                
                await MainActor.run {
                    createdSessionId = mockId
                    isNavigatingToRecording = true
                    print("[HomeView] Navigation triggered with mock ID")
                }
            }
        }
    }
}

// MARK: - Subviews

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct RichSessionRow: View {
    let session: Session
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(statusGradient.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: statusIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusGradient)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    if let date = session.createdAt {
                        Text(relativeDate(date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(session.mode == "lecture" ? "講義" : "会議")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status Chip
            Text(statusLabel)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusGradient)
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var statusGradient: LinearGradient {
        switch session.status {
        case "recording":
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        case "transcribing":
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case "transcribed":
            return LinearGradient(colors: [AppColors.success, Color(hex: "11998e")], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
        }
    }
    
    private var statusIcon: String {
        switch session.status {
        case "recording": return "waveform"
        case "transcribing": return "text.badge.checkmark"
        case "transcribed": return "checkmark.circle.fill"
        default: return "doc.text"
        }
    }
    
    private var statusLabel: String {
        switch session.status {
        case "recording": return "録音中"
        case "transcribing": return "処理中"
        case "transcribed": return "完了"
        default: return session.status
        }
    }
    
    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.locale = Locale(identifier: "ja_JP")
            return "今日 \(formatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            formatter.locale = Locale(identifier: "ja_JP")
            return "昨日 \(formatter.string(from: date))"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d HH:mm"
            formatter.locale = Locale(identifier: "ja_JP")
            return formatter.string(from: date)
        }
    }
}

// MARK: - Mode Selection Sheet

struct ModeSelectionSheet: View {
    @Binding var selectedMode: SessionMode
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("録音モードを選択")
                    .font(.title2.bold())
                
                Text("内容に合わせて最適な要約を生成します")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            
            // Mode Cards
            HStack(spacing: 16) {
                // Lecture Card
                ModeCard(
                    icon: "book.fill",
                    title: "講義",
                    description: "ポイント整理・復習クイズ",
                    color: GlassNotebook.Accent.lecture,
                    isSelected: selectedMode == .lecture
                ) {
                    selectedMode = .lecture
                    Haptic.selection.trigger()
                }
                
                // Meeting Card
                ModeCard(
                    icon: "person.2.fill",
                    title: "会議",
                    description: "話者分離・アクションアイテム",
                    color: GlassNotebook.Accent.meeting,
                    isSelected: selectedMode == .meeting
                ) {
                    selectedMode = .meeting
                    Haptic.selection.trigger()
                }
            }
            .padding(.horizontal)
            
            // Start Button
            Button {
                dismiss()
                onStart()
            } label: {
                Text("録音を開始")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GlassNotebook.Gradient.hero)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 24)
    }
}

struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(GlassNotebook.Background.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? color.opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}
