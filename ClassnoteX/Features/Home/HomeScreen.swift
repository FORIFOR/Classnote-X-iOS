import SwiftUI

struct HomeScreen: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var recording: RecordingCoordinator
    @Binding var path: NavigationPath

    var body: some View {
        ZStack {
            Tokens.Color.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Brand Header (DeepNote + Date)
                HStack {
                    BrandHeader()
                    Spacer()
                }
                .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                .padding(.top, Tokens.Spacing.md)

                Spacer().frame(height: Tokens.Spacing.xl)

                // 2. Mode Selector (講義/会議) - positioned higher
                if !recording.isActive {
                    ModeSelectorPill(selection: $viewModel.selectedMode)
                        .padding(.horizontal, Tokens.Spacing.screenHorizontal)
                }

                Spacer()

                // 3. Record Button (center)
                recordingSection

                Spacer()

                // Bottom padding for TabBar + Recording Pill
                Spacer().frame(height: Tokens.Spacing.tabBarHeight + (recording.isActive ? 80 : 40))
            }
        }
        .navigationDestination(for: Session.self) { session in
            SessionDetailScreen(session: session)
        }
        .alert("マイクの許可が必要です", isPresented: $viewModel.showPermissionAlert) {
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("キャンセル", role: .cancel) { }
        }
    }

    // MARK: - Recording Section

    private var recordingSection: some View {
        VStack(spacing: Tokens.Spacing.md) {
            // Record Button
            RecordMicButton(
                color: recordButtonColor,
                isRecording: recording.isActive
            ) {
                handleMicTap()
            }
            .scaleEffect(recording.isActive ? 0.8 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: recording.isActive)

            // Labels
            VStack(spacing: 4) {
                Text(recording.isActive ? "録音中" : viewModel.primaryTitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Tokens.Color.textPrimary)

                Text(recording.isActive ? "タップで詳細を表示" : viewModel.subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(Tokens.Color.textSecondary)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: recording.isActive)
    }

    // MARK: - Helpers

    private var recordButtonColor: Color {
        viewModel.selectedMode == .lecture
            ? Tokens.Color.lectureAccent
            : Tokens.Color.meetingAccent
    }

    private func handleMicTap() {
        if recording.isActive {
            recording.isSheetPresented = true
            return
        }
        if viewModel.checkPermission() {
            recording.startRecording(type: viewModel.selectedMode, presentSheet: false)
        }
    }
}
