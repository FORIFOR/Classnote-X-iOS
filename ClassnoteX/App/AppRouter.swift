import SwiftUI
import FirebaseAuth
import Combine
import LineSDK

struct ContentView: View {
    @StateObject private var authState = AuthState()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var recordingCoordinator = RecordingCoordinator()
    @StateObject private var shareCoordinator = ShareCoordinator()
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.system.rawValue
    
    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }
    
    var body: some View {
        mainContent
            .cappedDynamicType()
            .preferredColorScheme(appearanceMode.colorScheme)
            .onAppear {
                authState.startListening()
            }
            .onOpenURL { url in
                if LoginManager.shared.application(UIApplication.shared, open: url, options: [:]) {
                    return
                }
                if ShareImportCoordinator.shared.canHandle(url) {
                    ShareImportCoordinator.shared.handleIncomingURL(url, recording: recordingCoordinator)
                } else {
                    shareCoordinator.handleIncomingURL(url)
                }
            }
            .onChange(of: authState.state) { _, state in
                if case .signedIn = state {
                    Task { await shareCoordinator.processPendingShareIfPossible() }
                }
            }
            .environmentObject(recordingCoordinator)
            .environmentObject(shareCoordinator)
            .alert(item: Binding(
                get: { authViewModel.errorMessage.map { AlertMessage(text: $0) } },
                set: { _ in authViewModel.errorMessage = nil }
            )) { alert in
                Alert(title: Text("エラー"), message: Text(alert.text), dismissButton: .default(Text("OK")))
            }
            .alert(
                "録音エラー",
                isPresented: Binding(
                    get: { recordingCoordinator.errorMessage != nil },
                    set: { if !$0 { recordingCoordinator.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(recordingCoordinator.errorMessage ?? "")
            }
            .alert(
                "共有エラー",
                isPresented: Binding(
                    get: { shareCoordinator.errorMessage != nil },
                    set: { if !$0 { shareCoordinator.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(shareCoordinator.errorMessage ?? "")
            }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch authState.state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Tokens.Color.background)
            case .signedOut:
                SignInScreen(authViewModel: authViewModel)
            case .usernameSetup(let user):
                UsernameSetupView { updatedUser in
                    authState.state = .signedIn(updatedUser)
                }
            case .signedIn(_):
                MainAppView()
            }
        }
    }
}

class AuthState: ObservableObject {
    enum State: Equatable {
        case loading
        case signedOut
        case usernameSetup(User)
        case signedIn(User)
    }
    
    @Published var state: State = .loading
    private var listener: AuthStateDidChangeListenerHandle?
    
    func startListening() {
        guard listener == nil else { return }
        listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { await self.resolveState(user: user) }
        }
        Task { await resolveState(user: Auth.auth().currentUser) }
    }
    
    private func resolveState(user: FirebaseAuth.User?) async {
        guard user != nil else {
            await MainActor.run { state = .signedOut }
            return
        }
        await MainActor.run { state = .loading }
        do {
            let me = try await APIClient.shared.getMe()
            await MainActor.run {
                if me.username == nil {
                    state = .usernameSetup(me)
                } else {
                    state = .signedIn(me)
                }
            }
        } catch {
            await MainActor.run { state = .signedOut }
        }
    }
}

struct AlertMessage: Identifiable {
    let id = UUID()
    let text: String
}
