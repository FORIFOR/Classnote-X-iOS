import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.isAuthenticated {
                MainTabView()
            } else {
                AuthView()
            }
        }
        .environmentObject(model)
        .preferredColorScheme(preferredScheme)
        .alert(item: Binding(
            get: { model.errorMessage.map { IdentifiedError(message: $0) } },
            set: { _ in model.errorMessage = nil })
        ) { err in
            Alert(title: Text("エラー"), message: Text(err.message), dismissButton: .default(Text("OK")))
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                model.recordingModel.prepareForBackgroundIfNeeded()
            case .active:
                model.recordingModel.resumeIfNeededAfterForeground()
            default:
                break
            }
        }
        .onAppear {
            model.recordingModel.prepareAudioSession()
        }
    }

    private var preferredScheme: ColorScheme? {
        switch model.colorScheme {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct IdentifiedError: Identifiable {
    let id = UUID()
    let message: String
}
