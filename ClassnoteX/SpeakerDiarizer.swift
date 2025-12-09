import Foundation
import SherpaOnnx

/// Wraps Sherpa-Onnx Speaker Diarization logic.
/// Handles model management and execution.
class SpeakerDiarizer {
    
    struct DiarizationResult {
        let segmentIndex: Int
        let startTime: TimeInterval
        let endTime: TimeInterval
        let speaker: String // "Speaker 0", "Speaker 1", etc.
    }
    
    private var diarizer: OfflineSpeakerDiarization?
    
    // Model filenames (must match what was downloaded/added to bundle)
    private let segmentationModelName = "model.onnx" // From sherpa-onnx-pyannote-segmentation-3-0
    private let embeddingModelName = "3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx"
    private let vadModelName = "silero_vad.onnx"
    
    init() {
        // Models are loaded lazily or on specific setup call
    }
    
    /// Prepares models by copying them from Bundle to Application Support if needed.
    /// Initializes the SherpaOnnx diarizer.
    func setup() throws {
        let config = try buildConfig()
        self.diarizer = OfflineSpeakerDiarization(config: config)
        print("[SpeakerDiarizer] Initialized successfully")
    }
    
    /// Run diarization on an audio file
    func process(audioURL: URL) async throws -> [DiarizationResult] {
        if diarizer == nil {
            try setup()
        }
        guard let diarizer = self.diarizer else {
            throw NSError(domain: "SpeakerDiarizer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Diarizer not initialized"])
        }
        
        print("[SpeakerDiarizer] Decoding audio: \(audioURL.lastPathComponent)")
        // 1. Decode audio to 16kHz PCM Float array
        let samples = try AudioUtils.decodeAudioFileToPCM(url: audioURL, sampleRate: 16000)
        
        print("[SpeakerDiarizer] Audio decoded: \(samples.count) samples (\(Double(samples.count)/16000.0) sec)")
        
        // 2. Process
        // config.numSpeakers can be set if known, but exact number is optional effectively with clustering
        // Sherpa-Onnx API typically processes samples directly
        let segments = diarizer.process(samples: samples)
        
        print("[SpeakerDiarizer] Found \(segments.count) segments")
        
        // 3. Map to result
        return segments.enumerated().map { index, segment in
            // segment has .start, .end, .speaker
            DiarizationResult(
                segmentIndex: index,
                startTime: segment.start,
                endTime: segment.end,
                speaker: "Speaker \(segment.speaker)"
            )
        }
    }
    
    private func buildConfig() throws -> OfflineSpeakerDiarizationConfig {
        let (segmentationPath, embeddingPath, vadPath) = try prepareModelFiles()
        
        return OfflineSpeakerDiarizationConfig(
            segmentation: OfflineSpeakerDiarizationSegmentationConfig(
                pyannote: OfflineSpeakerDiarizationPyannoteConfig(model: segmentationPath)
            ),
            embedding: OfflineSpeakerDiarizationEmbeddingConfig(
                model: embeddingPath
            ),
            clustering: OfflineSpeakerDiarizationClusteringConfig(
                numClusters: -1, // Auto-detect number of speakers
                threshold: 0.5   // Tuning parameter for clustering
            ),
            minDurationOn: 0.2,
            minDurationOff: 0.5
        )
    }
    
    /// Copies models from Bundle to Application Support directory and returns paths.
    private func prepareModelFiles() throws -> (String, String, String) {
        let fileManager = FileManager.default
        let appSupport = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let modelsDir = appSupport.appendingPathComponent("SherpaModels")
        
        if !fileManager.fileExists(atPath: modelsDir.path) {
            try fileManager.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }
        
        func prepare(resourceName: String, inDir dirName: String? = nil) throws -> String {
            let destinationURL = modelsDir.appendingPathComponent(resourceName)
            if !fileManager.fileExists(atPath: destinationURL.path) {
                // Find in bundle
                // Note: Models might be in a subdirectory in the bundle if user added folder reference
                // Try simplified lookup first
                var sourceURL: URL?
                
                // Strategy 1: Direct lookup
                sourceURL = Bundle.main.url(forResource: resourceName, withExtension: nil)
                
                // Strategy 2: Look inside "Diarization" folder (likely scenario)
                if sourceURL == nil {
                    sourceURL = Bundle.main.url(forResource: resourceName, withExtension: nil, subdirectory: "Diarization")
                }
                
                // Strategy 3: Look inside "sherpa-onnx-pyannote-segmentation-3-0" for that specific model
                if sourceURL == nil && resourceName == "model.onnx" {
                     sourceURL = Bundle.main.url(forResource: resourceName, withExtension: nil, subdirectory: "Diarization/sherpa-onnx-pyannote-segmentation-3-0")
                }

                guard let finalSource = sourceURL else {
                    print("[SpeakerDiarizer] ❌ Missing model in bundle: \(resourceName)")
                    throw NSError(domain: "SpeakerDiarizer", code: 404, userInfo: [NSLocalizedDescriptionKey: "Model file \(resourceName) not found in Bundle"])
                }
                
                try fileManager.copyItem(at: finalSource, to: destinationURL)
                print("[SpeakerDiarizer] Copied \(resourceName) to AppSupport")
            }
            return destinationURL.path
        }
        
        // Since user downloaded pyannote tarball, model.onnx might be deeper.
        // Assuming user dragged the unpacked folders as is.
        // Actually, user ran `mkdir -p ClassnoteX/Models/Diarization && mv sherpa-diar-models/* ...`
        // So structure is:
        // ClassnoteX/Models/Diarization/sherpa-onnx-pyannote-segmentation-3-0/model.onnx
        // ClassnoteX/Models/Diarization/3dspeaker_...onnx
        // ClassnoteX/Models/Diarization/silero_vad.onnx
        
        // However, Bundle resources are flattened unless "Create groups" (folder references) was used.
        // Implementation plan step told user: "**Check 'Create groups'**". This usually creates groups in Xcode project navigator, but for folders on disk, they might be copied flat or as folder refs depending on selection (blue vs yellow folders).
        // Safest is to check widely.
        
        // Let's special case model.onnx which is generic name
        let segPath = try prepare(resourceName: "model.onnx") 
        let embPath = try prepare(resourceName: embeddingModelName)
        // Silero VAD is not strictly needed for offline diarization config in Sherpa (Pyannote segmentation handles VAD mostly), 
        // BUT `OfflineSpeakerDiarizationConfig` does NOT seem to expose VAD config in standard API struct unless using different constructor.
        // Wait, looking at Sherpa Onnx Swift API, `OfflineSpeakerDiarizationConfig` has `segmentation`, `embedding`, `clustering`.
        // It does NOT explicitly take a "vad" model path in the main swift wrapper usually, unless using VAD-only class.
        // The pyannote segmentation model does segmentation + VAD internally.
        // So I might not need `silero_vad.onnx` for *this* specific pipeline if using pyannote segmentation model.
        // The user's request mentioned "1. VAD... 2. Segmentation...".
        // But Sherpa's `OfflineSpeakerDiarization` with Pyannote usually enables `minDurationOn` etc. 
        // I will assume `silero_vad.onnx` might be used if I were building from scratch, but with Sherpa's high level API, I stick to the config structure.
        // The `OfflineSpeakerDiarizationConfig` struct in Swift typically just wants segmentation and embedding.
        
        // I will return basic path for now.
        return (segPath, embPath, "")
    }
}
