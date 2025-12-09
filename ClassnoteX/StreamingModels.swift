import Foundation

struct StreamWordInfo: Codable, Identifiable {
    var id: UUID = UUID()
    let word: String
    let start: Double
    let end: Double
    let speakerTag: Int?
}

struct StreamResultMessage: Codable {
    let event: String
    let sessionId: String?
    let transcript: String?
    let confidence: Double?
    let words: [StreamWordInfo]?
    let message: String?
}

// MARK: - Live Line (App Model)

struct LiveLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let speakerTag: Int
    let isFinal: Bool
    let timestamp: Date
}

