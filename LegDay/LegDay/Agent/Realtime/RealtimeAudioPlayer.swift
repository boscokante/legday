import Foundation
import AVFoundation

class RealtimeAudioPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isPlaying = false
    
    init() {
        engine.attach(playerNode)
        
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        do {
            try engine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func playAudio(_ audioData: Data) {
        guard !audioData.isEmpty else { return }
        
        // Convert Data to AVAudioPCMBuffer
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 24000, channels: 1, interleaved: false)!
        let frameCount = audioData.count / 2 // 2 bytes per sample
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }
        
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        // Copy audio data to buffer
        audioData.withUnsafeBytes { bytes in
            guard let int16Pointer = bytes.bindMemory(to: Int16.self).baseAddress else { return }
            buffer.int16ChannelData![0].update(from: int16Pointer, count: frameCount)
        }
        
        // Schedule buffer for playback
        playerNode.scheduleBuffer(buffer) {
            // Buffer completed
        }
        
        if !isPlaying {
            playerNode.play()
            isPlaying = true
        }
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
    }
    
    deinit {
        engine.stop()
    }
}




