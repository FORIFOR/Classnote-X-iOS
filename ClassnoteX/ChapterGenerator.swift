import Foundation
import Combine

// MARK: - Chapter Generator

/// Generates YouTube-style chapter markers from transcript segments
@MainActor
class ChapterGenerator: ObservableObject {
    
    @Published var chapters: [ChapterMarker] = []
    @Published var isGenerating: Bool = false
    
    private let apiClient: ClassnoteAPIClient
    
    init(apiClient: ClassnoteAPIClient) {
        self.apiClient = apiClient
    }
    
    // MARK: - Generate Chapters from Segments
    
    /// Convert transcript segments to chapter markers
    /// Uses LLM to generate concise titles for each segment
    func generateFromSegments(_ segments: [TranscriptSegment], sessionId: String, mode: String) async {
        guard !segments.isEmpty else {
            print("[ChapterGen] No segments to process")
            return
        }
        
        print("[ChapterGen] ========== GENERATING CHAPTERS ==========")
        print("[ChapterGen] Segments count: \(segments.count)")
        print("[ChapterGen] Mode: \(mode)")
        
        isGenerating = true
        
        var generatedChapters: [ChapterMarker] = []
        
        for segment in segments {
            // Generate a title for each segment
            let title = await generateTitle(for: segment, mode: mode)
            
            let chapter = ChapterMarker(
                id: "ch-\(segment.index)",
                timeSeconds: segment.startTimeSeconds,
                title: title
            )
            generatedChapters.append(chapter)
            
            print("[ChapterGen] ✅ Chapter \(segment.index): \(segment.startTimeSeconds.mmssString) - \(title)")
        }
        
        // Update on main actor
        chapters = generatedChapters
        isGenerating = false
        
        print("[ChapterGen] Generated \(chapters.count) chapters")
    }
    
    // MARK: - Generate Title for Segment
    
    /// Generate a concise title for a segment using local heuristics
    /// Falls back to simple extraction if API fails
    private func generateTitle(for segment: TranscriptSegment, mode: String) async -> String {
        let text = segment.text
        
        // Simple local heuristic: extract first meaningful phrase
        let title = extractMeaningfulTitle(from: text, mode: mode)
        
        return title
    }
    
    /// Extract a meaningful title from segment text
    private func extractMeaningfulTitle(from text: String, mode: String) -> String {
        // Remove leading/trailing whitespace
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Try to find first sentence or phrase
        let separators = CharacterSet(charactersIn: "。.、,！!？?")
        let sentences = trimmed.components(separatedBy: separators)
        
        guard let firstSentence = sentences.first, !firstSentence.isEmpty else {
            return mode == "meeting" ? "会議内容" : "講義内容"
        }
        
        // Take first 20 characters max for title
        let maxLength = 20
        let title = String(firstSentence.prefix(maxLength))
        
        // Add ellipsis if truncated
        if firstSentence.count > maxLength {
            return title + "..."
        }
        
        return title
    }
    
    // MARK: - Quick Chapters (Simple Time-Based)
    
    /// Generate simple time-based chapters without AI
    /// For immediate display during recording
    func generateQuickChapters(recordingDuration: TimeInterval, segmentCount: Int) -> [ChapterMarker] {
        guard segmentCount > 0 else { return [] }
        
        let interval = recordingDuration / Double(segmentCount)
        var quickChapters: [ChapterMarker] = []
        
        for i in 0..<segmentCount {
            let time = Double(i) * interval
            let title = "セクション \(i + 1)"
            
            quickChapters.append(ChapterMarker(
                id: "quick-\(i)",
                timeSeconds: time,
                title: title
            ))
        }
        
        return quickChapters
    }
    
    // MARK: - Smart Chapters (AI-Powered)
    
    /// Request AI-generated chapters from backend
    func generateSmartChapters(sessionId: String) async {
        print("[ChapterGen] Requesting smart chapters from backend...")
        isGenerating = true
        
        do {
            let backendChapters = try await apiClient.generateChapters(sessionId: sessionId)
            
            if !backendChapters.isEmpty {
                chapters = backendChapters
                print("[ChapterGen] ✅ Received \(backendChapters.count) chapters from backend")
            } else {
                print("[ChapterGen] ⚠️ Backend returned empty chapters")
            }
        } catch {
            print("[ChapterGen] ❌ Failed to get chapters from backend: \(error)")
        }
        
        isGenerating = false
    }
    
    // MARK: - Merge Segments into Chapters
    
    /// Merge short segments into longer chapters
    /// Combines segments that are too short to be meaningful chapters
    func mergeIntoChapters(_ segments: [TranscriptSegment], minDuration: TimeInterval = 60) -> [ChapterMarker] {
        guard !segments.isEmpty else { return [] }
        
        var mergedChapters: [ChapterMarker] = []
        var currentStart = segments[0].startTimeSeconds
        var currentText = ""
        var currentIndex = 0
        
        for segment in segments {
            let duration = segment.endTimeSeconds - segment.startTimeSeconds
            
            if duration >= minDuration || segment == segments.last {
                // This segment is long enough to be its own chapter
                if !currentText.isEmpty {
                    // First, create chapter from accumulated short segments
                    mergedChapters.append(ChapterMarker(
                        id: "merged-\(currentIndex)",
                        timeSeconds: currentStart,
                        title: extractMeaningfulTitle(from: currentText, mode: "meeting")
                    ))
                    currentIndex += 1
                }
                
                // Then add this segment as its own chapter
                mergedChapters.append(ChapterMarker(
                    id: "ch-\(currentIndex)",
                    timeSeconds: segment.startTimeSeconds,
                    title: extractMeaningfulTitle(from: segment.text, mode: "meeting")
                ))
                currentIndex += 1
                currentText = ""
                currentStart = segment.endTimeSeconds
            } else {
                // Accumulate short segments
                if currentText.isEmpty {
                    currentStart = segment.startTimeSeconds
                }
                currentText += segment.text + " "
            }
        }
        
        return mergedChapters
    }
}

// MARK: - Extension for TranscriptSegment Equatable

extension TranscriptSegment: Equatable {
    static func == (lhs: TranscriptSegment, rhs: TranscriptSegment) -> Bool {
        lhs.id == rhs.id
    }
}
