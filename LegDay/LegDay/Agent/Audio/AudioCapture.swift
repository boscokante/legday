import Foundation
import AVFoundation

class AudioCapture {
    private let engine = AVAudioEngine()
    private let onAudioData: (Data) -> Void
    private let onLevelUpdate: (Float) -> Void
    
    init(onAudioData: @escaping (Data) -> Void, onLevelUpdate: @escaping (Float) -> Void) {
        self.onAudioData = onAudioData
        self.onLevelUpdate = onLevelUpdate
    }
    
    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap using the input node's native format
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Get float channel data
            guard let floatChannelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let channelData = floatChannelData[0]
            
            // Calculate audio level
            var sum: Float = 0
            for i in 0..<frameLength {
                sum += abs(channelData[i])
            }
            let average = sum / Float(frameLength)
            let level = min(1.0, average * 10.0)
            self.onLevelUpdate(level)
            
            // Convert float samples to 16-bit PCM for OpenAI
            var int16Samples = [Int16](repeating: 0, count: frameLength)
            for i in 0..<frameLength {
                let sample = max(-1.0, min(1.0, channelData[i])) // Clamp
                int16Samples[i] = Int16(sample * 32767.0)
            }
            
            let audioData = Data(bytes: int16Samples, count: frameLength * 2)
            self.onAudioData(audioData)
        }
        
        try engine.start()
    }
    
    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }
}

