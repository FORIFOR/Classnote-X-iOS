import Foundation

struct RealtimeWord: Codable, Identifiable {
    let id = UUID()
    let word: String
    let startSec: Double
    let endSec: Double
    let speakerTag: Int
}

struct RealtimeSegment: Codable, Identifiable {
    let id = UUID()
    let sessionId: String
    let isFinal: Bool
    let transcript: String
    let words: [RealtimeWord]
}

final class RealtimeTranscriptionClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let decodeQueue = DispatchQueue(label: "RealtimeTranscriptionClient.decode")

    var onSegment: ((RealtimeSegment) -> Void)?

    init() {
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config)
    }

    func connect(url: URL,
                 languageCode: String = "ja-JP",
                 speakerCount: Int = 2,
                 sampleRate: Int = 16_000,
                 model: String = "default") {
        print("[RealtimeWS] connect -> \(url)")
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        sendStart(languageCode: languageCode, speakerCount: speakerCount, sampleRate: sampleRate, model: model)
        receiveLoop()
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    handleData(data)
                case .string(let text):
                    if let data = text.data(using: .utf8) { handleData(data) }
                @unknown default:
                    break
                }
                self.receiveLoop()
            case .failure(let error):
                print("[RealtimeWS] receive error: \(error)")
            }
        }
    }

    private func handleData(_ data: Data) {
        decodeQueue.async { [weak self] in
            guard let self else { return }
            do {
                // まず Codable でトライ
                if let msg = try? self.decoder.decode(StreamResultMessage.self, from: data) {
                    print("[RealtimeWS] message event=\(msg.event)")
                    switch msg.event {
                    case "partial", "final":
                        let words = (msg.words ?? []).map {
                            RealtimeWord(word: $0.word, startSec: $0.start, endSec: $0.end, speakerTag: $0.speakerTag ?? 0)
                        }
                        let seg = RealtimeSegment(
                            sessionId: msg.sessionId ?? "",
                            isFinal: msg.event == "final",
                            transcript: msg.transcript ?? "",
                            words: words
                        )
                        DispatchQueue.main.async {
                            self.onSegment?(seg)
                        }
                    case "error":
                        print("[RealtimeWS] server error: \(msg.message ?? "")")
                    default:
                        break
                    }
                    return
                }
                // フォールバック: JSON辞書でパース（text / speakerTag 形式）
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let event = json["event"] as? String {
                    print("[RealtimeWS] message(fallback) event=\(event)")
                    if event == "partial" || event == "final" || event == "transcript" {
                        let text = (json["transcript"] as? String)
                            ?? (json["text"] as? String) ?? ""
                        let speakerTag = (json["speakerTag"] as? Int)
                            ?? (json["speaker"] as? Int) ?? 0
                        let seg = RealtimeSegment(
                            sessionId: (json["sessionId"] as? String) ?? "",
                            isFinal: event == "final",
                            transcript: text,
                            words: [RealtimeWord(word: text, startSec: 0, endSec: 0, speakerTag: speakerTag)]
                        )
                        DispatchQueue.main.async { self.onSegment?(seg) }
                    } else if event == "error" {
                        print("[RealtimeWS] server error: \(json["message"] ?? "")")
                    }
                    return
                }
            } catch {
                print("Streaming decode error: \(error)")
            }
        }
    }

    func sendAudioChunk(_ data: Data) {
        webSocketTask?.send(.data(data)) { error in
            if let error { print("WebSocket audio send error: \(error)") }
        }
    }

    func sendStop() {
        let stopPayload: [String: Any] = ["event": "stop"]
        sendJSON(stopPayload)
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    private func sendStart(languageCode: String, speakerCount: Int, sampleRate: Int, model: String) {
        let startPayload: [String: Any] = [
            "event": "start",
            "config": [
                "languageCode": languageCode,
                "sampleRateHertz": sampleRate,
                "enableSpeakerDiarization": true,
                "speakerCount": speakerCount,
                "model": model
            ]
        ]
        print("[RealtimeWS] send start payload: \(startPayload)")
        sendJSON(startPayload)
    }

    private func sendJSON(_ json: [String: Any]) {
        guard let webSocketTask = webSocketTask else { return }
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else {
            return
        }

        webSocketTask.send(.string(text)) { error in
            if let error = error {
                print("[RealtimeWS] send error: \(error)")
            }
        }
    }
}
