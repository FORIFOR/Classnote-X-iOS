import Foundation

// MARK: - Local Audio Mapping

/// Manages persistent mapping between session IDs and local audio file names
/// This ensures we always play the correct audio file for each session
enum LocalAudioMapping {
    private static let userDefaultsKey = "LocalAudioFileMapping"

    /// Save the mapping of sessionId → audioFileName
    static func save(sessionId: String, audioFileName: String) {
        var mapping = getAll()
        mapping[sessionId] = audioFileName
        UserDefaults.standard.set(mapping, forKey: userDefaultsKey)
        print("[LocalAudioMapping] Saved: \(sessionId) → \(audioFileName)")
    }

    /// Get the audio file name for a session
    static func getFileName(for sessionId: String) -> String? {
        let mapping = getAll()
        return mapping[sessionId]
    }

    /// Get all mappings
    static func getAll() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: userDefaultsKey) as? [String: String] ?? [:]
    }

    /// Remove mapping for a session
    static func remove(sessionId: String) {
        var mapping = getAll()
        mapping.removeValue(forKey: sessionId)
        UserDefaults.standard.set(mapping, forKey: userDefaultsKey)
    }

    /// Clean up mappings for files that no longer exist
    static func cleanupOrphaned() {
        guard let dir = AudioFileLocator.recordingsDirectory() else { return }
        var mapping = getAll()
        var removed = 0

        for (sessionId, fileName) in mapping {
            let fileURL = dir.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                mapping.removeValue(forKey: sessionId)
                removed += 1
            }
        }

        if removed > 0 {
            UserDefaults.standard.set(mapping, forKey: userDefaultsKey)
            print("[LocalAudioMapping] Cleaned up \(removed) orphaned entries")
        }
    }
}

// MARK: - Audio File Locator

enum AudioFileLocator {
    /// Find the local audio URL for a session
    /// Priority:
    /// 1. Explicit mapping (sessionId → fileName)
    /// 2. Timestamp-based heuristic matching (legacy fallback)
    static func findAudioURL(for session: Session) -> URL? {
        guard let dir = recordingsDirectory() else { return nil }

        // 1. Check explicit mapping first (most reliable)
        if let fileName = LocalAudioMapping.getFileName(for: session.id) {
            let url = dir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                // Verify file is valid (not empty/corrupted)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int, size > 44_000 { // > 1 second of 16kHz 16-bit mono
                    print("[AudioFileLocator] Using mapped file: \(fileName) (size: \(size) bytes)")
                    return url
                } else {
                    print("[AudioFileLocator] ⚠️ Mapped file exists but too small or corrupted: \(fileName)")
                }
            } else {
                print("[AudioFileLocator] ⚠️ Mapped file not found: \(fileName)")
            }
        }

        // 2. Fallback to timestamp-based matching (legacy)
        guard let createdAt = session.startedAt else {
            print("[AudioFileLocator] No startedAt for session \(session.id)")
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"

        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        let candidates = files.filter { $0.pathExtension.lowercased() == "wav" }

        let scored: [(url: URL, delta: TimeInterval)] = candidates.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "_")
            guard parts.count >= 2 else { return nil }
            // Format: lecture_YYYYMMDD_HHmmss or meeting_YYYYMMDD_HHmmss
            let timestamp = parts.suffix(2).joined(separator: "_")
            guard let date = formatter.date(from: timestamp) else { return nil }
            return (url, abs(date.timeIntervalSince(createdAt)))
        }

        // Only accept matches within 30 seconds (to avoid picking wrong day's file)
        if let best = scored.sorted(by: { $0.delta < $1.delta }).first, best.delta < 30 {
            print("[AudioFileLocator] Using timestamp-matched file: \(best.url.lastPathComponent) (delta: \(best.delta)s)")
            return best.url
        }

        print("[AudioFileLocator] No matching file found for session \(session.id)")
        return nil
    }

    static func recordingsDirectory() -> URL? {
        guard let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return docDir.appendingPathComponent("Recordings", isDirectory: true)
    }
}
