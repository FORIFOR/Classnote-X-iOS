import Foundation

@MainActor
final class ShareImportCoordinator {
    static let shared = ShareImportCoordinator()

    private let appGroupId = "group.jp.horioshuhei.deepnote"
    private let pendingFileName = "pending_voice_memo_import.json"

    func canHandle(_ url: URL) -> Bool {
        url.scheme == "deepnote" && url.host == "import"
    }

    func handleIncomingURL(_ url: URL, recording: RecordingCoordinator) {
        guard canHandle(url) else { return }
        Task { await consumePendingImport(recording: recording) }
    }

    private func consumePendingImport(recording: RecordingCoordinator) async {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            return
        }
        let jsonURL = container.appendingPathComponent(pendingFileName)
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        guard let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let path = payload["filePath"] as? String else {
            return
        }

        try? FileManager.default.removeItem(at: jsonURL)

        let fileURL = URL(fileURLWithPath: path)
        recording.importAudioFile(
            from: fileURL,
            type: .meeting,
            title: "ボイスメモ共有",
            cleanupOriginalURL: fileURL
        )
    }
}
