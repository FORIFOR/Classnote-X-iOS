import Foundation
import SwiftUI

// MARK: - Dedicated Models for Session Detail UI

// Removed duplicate SpeakerSegment and ChapterMarker. Using ClassnoteAPIClient definitions.

struct SessionNote: Identifiable, Hashable, Codable {
    var id: UUID = UUID()
    let timeSec: Double
    let text: String
}

// MARK: - Session Item Extensions

extension SessionItem {
    var speakerSegments: [SpeakerSegment] {
        // Map from backend segments if available
        segments?.compactMap { seg in
            guard let start = seg.startSec, let end = seg.endSec else { return nil }
            return SpeakerSegment(
                speaker: String(seg.speakerTag ?? 0),
                speakerName: nil,
                start: start,
                end: end,
                text: seg.text ?? ""
            )
        } ?? []
    }
    
    var chapterMarkers: [ChapterMarker] {
        // TODO: Map from actual chapters if available in backend
        // For now, return empty or mock if needed
        [] 
    }
    
    var notes: [SessionNote] {
        localNotes ?? [] 
    }
}

// MARK: - Compatibility with Session struct (from API Client)

extension Session {
    var speakerSegments: [SpeakerSegment] {
        diarizedSegments.map { seg in
            // Lookup speaker info
            let spk = speakers.first(where: { $0.id == seg.speakerId })
            
            return SpeakerSegment(
                speaker: spk?.label ?? seg.speakerId,
                speakerName: spk?.displayName,
                start: seg.start,
                end: seg.end,
                text: seg.text
            )
        }
    }
    
    var chapterMarkers: [ChapterMarker] {
        chapters
    }
    
    var notes: [SessionNote] {
        // Since Session is API model, it might not have localNotes property directly unless we add it.
        // However, the UI mainly interacts with AppModel for persistence.
        // If we want to use Session in DetailView, we should probably access notes via AppModel or pass them in.
        // For now, let's assume we read from AppModel separately or map it.
        // But the user's code snippet used `SessionItem?`.
        [] 
    }
}
