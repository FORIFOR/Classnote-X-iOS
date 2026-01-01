import Foundation
import Speech

enum LocalTranscriptionError: LocalizedError {
    case fileMissing
    case fileEmpty
    case notAuthorized
    case recognizerUnavailable
    case onDeviceUnavailable
    case noResult

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "ローカル音声ファイルが見つかりません。"
        case .fileEmpty:
            return "ローカル音声ファイルが空です。"
        case .notAuthorized:
            return "音声認識の許可がありません。"
        case .recognizerUnavailable:
            return "音声認識が利用できません。"
        case .onDeviceUnavailable:
            return "オンデバイス音声認識が利用できません。"
        case .noResult:
            return "ローカル文字起こしの結果が空でした。"
        }
    }
}

struct LocalTranscriptionSegment: Equatable {
    let text: String
    let startTime: Double
    let endTime: Double
}

struct LocalTranscriptionResult: Equatable {
    let text: String
    let segments: [LocalTranscriptionSegment]
}

enum LocalBatchTranscriber {
    static func transcribe(url: URL, locale: Locale = Locale(identifier: "ja-JP")) async throws -> String {
        let result = try await transcribeWithSegments(url: url, locale: locale)
        return result.text
    }

    static func transcribeWithSegments(
        url: URL,
        locale: Locale = Locale(identifier: "ja-JP")
    ) async throws -> LocalTranscriptionResult {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LocalTranscriptionError.fileMissing
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attrs[.size] as? Int, size <= 0 {
            throw LocalTranscriptionError.fileEmpty
        }

        let authorized = await requestSpeechAuthorization()
        guard authorized else {
            throw LocalTranscriptionError.notAuthorized
        }

        let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer(locale: Locale.current)
        guard let recognizer, recognizer.isAvailable else {
            throw LocalTranscriptionError.recognizerUnavailable
        }
        guard recognizer.supportsOnDeviceRecognition else {
            throw LocalTranscriptionError.onDeviceUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false

        let result: SFSpeechRecognitionResult = try await withCheckedThrowingContinuation { cont in
            var didFinish = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                if didFinish { return }
                if let error {
                    didFinish = true
                    cont.resume(throwing: error)
                    return
                }
                guard let result else { return }
                if result.isFinal {
                    didFinish = true
                    cont.resume(returning: result)
                }
            }
            _ = task
        }

        let text = result.bestTranscription.formattedString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if text.isEmpty {
            throw LocalTranscriptionError.noResult
        }

        let segments = result.bestTranscription.segments.map { segment in
            LocalTranscriptionSegment(
                text: segment.substring,
                startTime: segment.timestamp,
                endTime: segment.timestamp + segment.duration
            )
        }

        return LocalTranscriptionResult(text: text, segments: segments)
    }

    private static func requestSpeechAuthorization() async -> Bool {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    cont.resume(returning: newStatus == .authorized)
                }
            }
        default:
            return false
        }
    }
}
