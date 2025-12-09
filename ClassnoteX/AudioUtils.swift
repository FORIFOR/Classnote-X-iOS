import Foundation
import AVFoundation

enum AudioUtils {
    
    enum ConversionError: Error {
        case fileNotFound
        case formatInitializationFailed
        case conversionFailed
    }
    
    /// Converts an audio file at the given URL to 16kHz Mono PCM WAV float array.
    /// This format is required by Sherpa-Onnx models.
    static func decodeAudioFileToPCM(url: URL, sampleRate: Int = 16000) throws -> [Float] {
        // 1. Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConversionError.fileNotFound
        }
        
        // 2. Open file
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)
        
        // 3. Convert to 16kHz Mono if needed
        // Create an output format: 16kHz, 1 channel, Float32
        guard let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(sampleRate), channels: 1, interleaved: false) else {
            throw ConversionError.formatInitializationFailed
        }
        
        // Create converter
        guard let converter = AVAudioConverter(from: format, to: outputFormat) else {
            throw ConversionError.formatInitializationFailed
        }
        
        // Prepare buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            throw ConversionError.formatInitializationFailed
        }
        
        // 4. Perform conversion
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            // Create a buffer for the input file
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: inNumPackets)!
            do {
                try audioFile.read(into: inputBuffer)
                outStatus.pointee = .haveData
                return inputBuffer
            } catch {
                outStatus.pointee = .endOfStream
                return nil
            }
        }
        
        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
        
        if let error = error {
            print("[AudioUtils] Conversion error: \(error)")
            throw ConversionError.conversionFailed
        }
        
        // 5. Extract float array
        guard let channelData = outputBuffer.floatChannelData else {
            throw ConversionError.conversionFailed
        }
        
        let channelPointer = channelData[0] // Mono, so just take first channel
        let frameLength = Int(outputBuffer.frameLength)
        let floatArray = Array(UnsafeBufferPointer(start: channelPointer, count: frameLength))
        
        return floatArray
    }
}
