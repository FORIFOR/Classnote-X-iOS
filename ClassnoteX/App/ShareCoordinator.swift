import Foundation
import Combine
import FirebaseAuth

@MainActor
final class ShareCoordinator: ObservableObject {
    @Published var pendingShareToken: String?
    @Published var pendingSessionId: String?
    @Published var errorMessage: String?

    func handleIncomingURL(_ url: URL) {
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count >= 2, components[0] == "share" else { return }
        let token = components[1]
        pendingShareToken = token
        Task { await processPendingShareIfPossible() }
    }

    func processPendingShareIfPossible() async {
        guard let token = pendingShareToken else { return }
        guard Auth.auth().currentUser != nil else { return }
        do {
            let response = try await APIClient.shared.acceptShare(shareToken: token)
            pendingSessionId = response.sessionId
            pendingShareToken = nil
        } catch {
            errorMessage = "共有リンクの参加に失敗しました。"
        }
    }

    func joinSessionByCode(_ code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let token = extractShareToken(from: trimmed)
        do {
            let response = try await APIClient.shared.acceptShare(shareToken: token)
            pendingSessionId = response.sessionId
        } catch {
            errorMessage = "共有リンクの参加に失敗しました。"
        }
    }

    func shareSessionByUserCode(sessionId: String, targetShareCode: String, role: ShareRole? = nil) async {
        let trimmed = targetShareCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            _ = try await APIClient.shared.shareSessionByCode(sessionId: sessionId, targetShareCode: trimmed, role: role)
        } catch {
            errorMessage = "共有に失敗しました。"
        }
    }

    private func extractShareToken(from input: String) -> String {
        guard let url = URL(string: input) else { return input }
        let components = url.pathComponents.filter { $0 != "/" }
        if let index = components.firstIndex(of: "share"), components.count > index + 1 {
            return components[index + 1]
        }
        return components.last ?? input
    }
}
