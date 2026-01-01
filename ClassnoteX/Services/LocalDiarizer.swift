import Foundation
import AVFoundation

enum LocalDiarizationError: LocalizedError {
    case modelMissing(String)
    case diarizerInitFailed
    case audioLoadFailed
    case diarizationFailed
    case noSegments
    case noAlignedText

    var errorDescription: String? {
        switch self {
        case .modelMissing(let name):
            return "話者分離モデルが見つかりません: \(name)"
        case .diarizerInitFailed:
            return "話者分離エンジンの初期化に失敗しました。"
        case .audioLoadFailed:
            return "音声の読み込みに失敗しました。"
        case .diarizationFailed:
            return "話者分離の実行に失敗しました。"
        case .noSegments:
            return "話者分離の結果が空でした。"
        case .noAlignedText:
            return "文字起こしと話者分離の整合に失敗しました。"
        }
    }
}

struct LocalDiarizationResult: Equatable {
    let transcriptText: String
    let blocks: [TranscriptBlock]
}

private struct DiarizationSegment {
    let start: Double
    let end: Double
    let speaker: Int
}

private struct TimedToken {
    let text: String
    let start: Double
    let end: Double

    var midpoint: Double { (start + end) / 2.0 }
}

enum LocalDiarizer {
    static func diarize(
        audioURL: URL,
        locale: Locale = Locale(identifier: "ja-JP")
    ) async throws -> LocalDiarizationResult {
        let transcription = try await LocalBatchTranscriber.transcribeWithSegments(url: audioURL, locale: locale)
        let diarizationSegments = try await Task.detached(priority: .userInitiated) {
            try computeDiarizationSegments(audioURL: audioURL)
        }.value

        let tokens = transcription.segments
            .map { TimedToken(text: $0.text, start: $0.startTime, end: $0.endTime) }
            .filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let blocks = alignTokens(tokens, to: diarizationSegments)
        if blocks.isEmpty {
            throw LocalDiarizationError.noAlignedText
        }

        return LocalDiarizationResult(transcriptText: transcription.text, blocks: blocks)
    }

    private static func computeDiarizationSegments(audioURL: URL) throws -> [DiarizationSegment] {
        guard let segmentationURL = Bundle.main.url(
            forResource: "model.int8",
            withExtension: "onnx",
            subdirectory: "Models/Diarization/sherpa-onnx-pyannote-segmentation-3-0"
        ) ?? Bundle.main.url(
            forResource: "model",
            withExtension: "onnx",
            subdirectory: "Models/Diarization/sherpa-onnx-pyannote-segmentation-3-0"
        ) else {
            throw LocalDiarizationError.modelMissing("pyannote segmentation")
        }

        guard let embeddingURL = Bundle.main.url(
            forResource: "3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k",
            withExtension: "onnx",
            subdirectory: "Models/Diarization"
        ) else {
            throw LocalDiarizationError.modelMissing("speaker embedding")
        }

        let diarizer = try createDiarizer(segmentationURL: segmentationURL, embeddingURL: embeddingURL)
        defer {
            SherpaOnnxDestroyOfflineSpeakerDiarization(diarizer)
        }

        let expectedSampleRate = Double(SherpaOnnxOfflineSpeakerDiarizationGetSampleRate(diarizer))
        let samples = try loadSamples(url: audioURL, targetSampleRate: expectedSampleRate)
        if samples.isEmpty {
            throw LocalDiarizationError.audioLoadFailed
        }

        let result = samples.withUnsafeBufferPointer { buffer in
            SherpaOnnxOfflineSpeakerDiarizationProcess(diarizer, buffer.baseAddress, Int32(buffer.count))
        }
        guard let result else {
            throw LocalDiarizationError.diarizationFailed
        }
        defer {
            SherpaOnnxOfflineSpeakerDiarizationDestroyResult(result)
        }

        let segmentCount = SherpaOnnxOfflineSpeakerDiarizationResultGetNumSegments(result)
        if segmentCount <= 0 {
            throw LocalDiarizationError.noSegments
        }

        guard let segmentPtr = SherpaOnnxOfflineSpeakerDiarizationResultSortByStartTime(result) else {
            throw LocalDiarizationError.noSegments
        }
        defer {
            SherpaOnnxOfflineSpeakerDiarizationDestroySegment(segmentPtr)
        }

        let segments = UnsafeBufferPointer(start: segmentPtr, count: Int(segmentCount)).map {
            DiarizationSegment(start: Double($0.start), end: Double($0.end), speaker: Int($0.speaker))
        }
        return mergeSegments(segments)
    }

    private static func createDiarizer(
        segmentationURL: URL,
        embeddingURL: URL
    ) throws -> OpaquePointer {
        let segmentationPath = segmentationURL.path
        let embeddingPath = embeddingURL.path
        let provider = "cpu"

        return try segmentationPath.withCString { segPtr in
            try embeddingPath.withCString { embPtr in
                try provider.withCString { providerPtr in
                    var pyannote = SherpaOnnxOfflineSpeakerSegmentationPyannoteModelConfig()
                    pyannote.model = segPtr

                    var segmentation = SherpaOnnxOfflineSpeakerSegmentationModelConfig()
                    segmentation.pyannote = pyannote
                    segmentation.num_threads = 2
                    segmentation.debug = 0
                    segmentation.provider = providerPtr

                    var embedding = SherpaOnnxSpeakerEmbeddingExtractorConfig()
                    embedding.model = embPtr
                    embedding.num_threads = 2
                    embedding.debug = 0
                    embedding.provider = providerPtr

                    var clustering = SherpaOnnxFastClusteringConfig()
                    clustering.num_clusters = 0
                    clustering.threshold = 0.8

                    var config = SherpaOnnxOfflineSpeakerDiarizationConfig()
                    config.segmentation = segmentation
                    config.embedding = embedding
                    config.clustering = clustering
                    config.min_duration_on = 0.3
                    config.min_duration_off = 0.5

                    guard let diarizer = SherpaOnnxCreateOfflineSpeakerDiarization(&config) else {
                        throw LocalDiarizationError.diarizerInitFailed
                    }
                    return diarizer
                }
            }
        }
    }

    private static func loadSamples(url: URL, targetSampleRate: Double) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw LocalDiarizationError.audioLoadFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw LocalDiarizationError.audioLoadFailed
        }

        var samples: [Float] = []
        let bufferSize: AVAudioFrameCount = 4096

        while file.framePosition < file.length {
            let remaining = file.length - file.framePosition
            let frameCount = AVAudioFrameCount(min(Int64(bufferSize), remaining))
            guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount) else {
                throw LocalDiarizationError.audioLoadFailed
            }
            try file.read(into: inputBuffer, frameCount: frameCount)

            let ratio = outputFormat.sampleRate / inputFormat.sampleRate
            let outputCapacity = AVAudioFrameCount(Double(frameCount) * ratio) + 1
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
                throw LocalDiarizationError.audioLoadFailed
            }

            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            if error != nil {
                throw LocalDiarizationError.audioLoadFailed
            }

            if let channel = outputBuffer.floatChannelData?.pointee {
                let count = Int(outputBuffer.frameLength)
                samples.append(contentsOf: UnsafeBufferPointer(start: channel, count: count))
            }
        }

        return samples
    }

    private static func alignTokens(
        _ tokens: [TimedToken],
        to segments: [DiarizationSegment]
    ) -> [TranscriptBlock] {
        var blocks: [TranscriptBlock] = []
        var tokenIndex = 0

        for segment in segments {
            var segmentTokens: [String] = []
            while tokenIndex < tokens.count {
                let token = tokens[tokenIndex]
                if token.midpoint < segment.start {
                    tokenIndex += 1
                    continue
                }
                if token.midpoint > segment.end {
                    break
                }
                let cleaned = token.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    segmentTokens.append(cleaned)
                }
                tokenIndex += 1
            }

            let text = segmentTokens.joined(separator: " ")
            guard !text.isEmpty else { continue }

            let speakerLabel = "話者\(segment.speaker + 1)"
            if let last = blocks.last,
               last.speaker == speakerLabel,
               segment.start - last.endTime < 0.2 {
                let mergedText = "\(last.text) \(text)"
                let merged = TranscriptBlock(
                    id: last.id,
                    speaker: speakerLabel,
                    text: mergedText,
                    startTime: last.startTime,
                    endTime: segment.end
                )
                blocks[blocks.count - 1] = merged
            } else {
                blocks.append(
                    TranscriptBlock(
                        id: UUID().uuidString,
                        speaker: speakerLabel,
                        text: text,
                        startTime: segment.start,
                        endTime: segment.end
                    )
                )
            }
        }

        return blocks
    }

    private static func mergeSegments(_ segments: [DiarizationSegment]) -> [DiarizationSegment] {
        guard let first = segments.first else { return [] }
        var merged: [DiarizationSegment] = []
        var current = first

        for segment in segments.dropFirst() {
            if segment.speaker == current.speaker && segment.start - current.end < 0.2 {
                current = DiarizationSegment(start: current.start, end: segment.end, speaker: current.speaker)
            } else {
                merged.append(current)
                current = segment
            }
        }
        merged.append(current)
        return merged
    }
}
