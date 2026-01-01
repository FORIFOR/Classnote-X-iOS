import SwiftUI

struct MainAppView: View {
    @EnvironmentObject private var recording: RecordingCoordinator
    @EnvironmentObject private var shareCoordinator: ShareCoordinator
    @State private var activeTab: TabItem = .home
    
    @State private var homePath = NavigationPath()
    @State private var sessionsPath = NavigationPath()
    @State private var calendarPath = NavigationPath()
    @State private var recordingDetent: PresentationDetent = .medium

    // Hide native tab bar
    init() {
        UITabBar.appearance().isHidden = true
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            
            // Content
            TabView(selection: $activeTab) {
                NavigationStack(path: $homePath) {
                    HomeScreen(path: $homePath)
                }
                .tag(TabItem.home)
                
                NavigationStack(path: $sessionsPath) {
                    SessionListScreen()
                }
                .tag(TabItem.sessions)
                
                NavigationStack(path: $calendarPath) {
                    CalendarScreen()
                }
                .tag(TabItem.calendar)
                
                SettingsScreen()
                    .tag(TabItem.settings)
            }
            .ignoresSafeArea() // Allow content to go behind tab bar? Spec says "floating glass pill". Yes.
            
            // Tab Bar
            VStack(spacing: Tokens.Spacing.sm) {
                if recording.isActive {
                    RecordingMiniBar()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onTapGesture {
                            recording.isSheetPresented = true
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.height < -12 {
                                        recording.isSheetPresented = true
                                    }
                                }
                        )
                }

                GlassTabBar(activeTab: $activeTab)
            }
            .padding(.bottom, Tokens.Layout.tabBarBottomPadding)
        }
        .ignoresSafeArea(.keyboard) // Prevent tab bar from rushing up
        .animation(.easeOut(duration: 0.25), value: recording.isActive)
        .sheet(isPresented: $recording.isSheetPresented) {
            RecordingSheet(selectedDetent: $recordingDetent)
                .presentationDetents([.medium, .large], selection: $recordingDetent)
                .presentationDragIndicator(.visible)
        }
        .onChange(of: recording.isSheetPresented) { _, isPresented in
            if isPresented {
                recordingDetent = .medium
            }
        }
        .onChange(of: recording.completedSession) { _, session in
            guard let session else { return }
            // Navigate to session detail via home path
            activeTab = .home
            homePath.append(session)
            recording.completedSession = nil
        }
        .onChange(of: shareCoordinator.pendingSessionId) { _, sessionId in
            guard let sessionId else { return }
            Task {
                do {
                    let session = try await APIClient.shared.getSession(id: sessionId)
                    await MainActor.run {
                        // Navigate to shared session via sessions path
                        activeTab = .sessions
                        sessionsPath.append(session)
                        shareCoordinator.pendingSessionId = nil
                    }
                } catch {
                    await MainActor.run {
                        shareCoordinator.errorMessage = "共有セッションの取得に失敗しました。"
                        shareCoordinator.pendingSessionId = nil
                    }
                }
            }
        }
        .confirmationDialog(
            "録音を終了しますか？",
            isPresented: Binding(
                get: { recording.showStopConfirm && recording.errorMessage == nil },
                set: { if !$0 { recording.showStopConfirm = false } }
            ),
            titleVisibility: .visible
        ) {
            Button("保存して終了") {
                recording.finishRecording(save: true)
            }
            Button("破棄", role: .destructive) {
                recording.finishRecording(save: false)
            }
            Button("キャンセル", role: .cancel) {}
        }
    }
}
