import Foundation
import Combine
import AVFoundation

// MARK: - Home View Model

@MainActor
final class HomeViewModel: ObservableObject {
    // Recording Mode
    @Published var selectedMode: SessionType = .lecture
    @Published var showPermissionAlert: Bool = false

    // Copy for the main action button
    var primaryTitle: String {
        switch selectedMode {
        case .lecture: return "講義を記録開始"
        case .meeting: return "会議を記録開始"
        }
    }

    var subtitle: String {
        switch selectedMode {
        case .lecture: return "講義用（長時間向け）"
        case .meeting: return "会議用（共有・タスク化）"
        }
    }

    // MARK: - Permission Check

    func checkPermission() -> Bool {
        let status = AVAudioSession.sharedInstance().recordPermission
        switch status {
        case .granted:
            return true
        case .denied:
            showPermissionAlert = true
            return false
        case .undetermined:
            return true
        @unknown default:
            return false
        }
    }

    func switchMode(_ mode: SessionType) {
        selectedMode = mode
        Haptics.selection()
    }
}
