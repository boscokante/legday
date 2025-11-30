import Foundation
import AVFoundation

class OpenAIRealtimeSession {
    private var webSocketTask: URLSessionWebSocketTask?
    private var audioCapture: AudioCapture?
    private var audioPlayer: RealtimeAudioPlayer?
    
    private let onTranscript: (String) -> Void
    private let onToolCall: (ToolCall) -> Void
    private let onAudioLevel: (Float) -> Void
    private let onStateChange: (AgentState) -> Void
    
    private var isListening = false
    private var sessionId: String?
    private var pendingConfig: (() async throws -> Void)?
    
    init(
        onTranscript: @escaping (String) -> Void,
        onToolCall: @escaping (ToolCall) -> Void,
        onAudioLevel: @escaping (Float) -> Void,
        onStateChange: @escaping (AgentState) -> Void
    ) {
        self.onTranscript = onTranscript
        self.onToolCall = onToolCall
        self.onAudioLevel = onAudioLevel
        self.onStateChange = onStateChange
    }
    
    func connect(historyContext: HistorySummary) async throws {
        // Get API key from Secrets.swift (gitignored config file)
        let apiKey = Secrets.openAIAPIKey
        
        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            throw NSError(domain: "OpenAIRealtime", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured. Please add your API key to Secrets.swift (see Secrets.example.swift for template)."])
        }
        
        // Create WebSocket connection to OpenAI Realtime API
        let url = URL(string: "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-12-17")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: request)
        
        // Set up audio capture and playback
        audioCapture = AudioCapture { [weak self] audioData in
            self?.sendAudio(audioData)
        } onLevelUpdate: { [weak self] level in
            Task { @MainActor in
                self?.onAudioLevel(level)
            }
        }
        
        audioPlayer = RealtimeAudioPlayer()
        
        // Start WebSocket connection
        webSocketTask?.resume()
        
        // Start receiving messages
        receiveMessages()
        
        // Store config to send after session.created
        pendingConfig = { [weak self] in
            try await self?.configureSession(historyContext: historyContext)
            
            // Start audio capture after config is sent
            if let cap = self?.audioCapture {
                do {
                    try cap.start()
                } catch {
                    print("Failed to start audio capture: \(error)")
                }
            }
            
            self?.isListening = true
            self?.onStateChange(.listening)
        }
    }
    
    private func configureSession(historyContext: HistorySummary) async throws {
        // Send session.update with tools
        let tools = ToolSchemas.allTools.map { tool in
            [
                "type": "function",
                "name": tool.name,
                "description": tool.description,
                "parameters": [
                    "type": tool.parameters.type,
                    "properties": tool.parameters.properties?.mapValues { prop in
                        var dict: [String: Any] = ["type": prop.type]
                        if let desc = prop.description {
                            dict["description"] = desc
                        }
                        if let enumVals = prop.enumValues {
                            dict["enum"] = enumVals
                        }
                        return dict
                    } ?? [:],
                    "required": tool.parameters.required ?? []
                ]
            ]
        }
        
        let systemPrompt = """
        You are a friendly, motivating personal trainer assistant. You help users track their workouts, suggest exercises, recommend weights based on their history, and log sets hands-free.
        
        User's workout history context:
        \(historyContext.highlights)
        
        Recent exercises: \(historyContext.recentExercises.joined(separator: ", "))
        
        Be conversational, encouraging, and concise. When recommending weights, explain your reasoning based on their history.
        """
        
        let configMessage: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "model": "gpt-4o-realtime-preview-2024-12-17",
                "instructions": systemPrompt,
                "voice": "alloy",
                "tools": tools,
                "tool_choice": "auto"
            ]
        ]
        
        try await sendMessage(configMessage)
    }
    
    private func sendMessage(_ message: [String: Any]) async throws {
        guard let webSocketTask = webSocketTask else { return }
        
        let jsonData = try JSONSerialization.data(withJSONObject: message)
        let messageString = String(data: jsonData, encoding: .utf8)!
        
        if let type = message["type"] as? String, type == "session.update" {
            print("➡️ Sending session.update: \(messageString)")
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(messageString)
        try await webSocketTask.send(wsMessage)
    }
    
    private var audioBuffer = Data()
    private var lastCommitTime = Date()
    
    private func sendAudio(_ audioData: Data) {
        guard isListening, webSocketTask != nil else { return }
        
        Task {
            do {
                // Accumulate audio data
                audioBuffer.append(audioData)
                
                // Only send when we have at least 100ms of audio (16kHz * 2 bytes * 0.1s = 3200 bytes minimum)
                let now = Date()
                let timeSinceLastCommit = now.timeIntervalSince(lastCommitTime)
                
                if audioBuffer.count >= 3200 || timeSinceLastCommit >= 0.5 {
                    // Convert to base64
                    let base64 = audioBuffer.base64EncodedString()
                    let message: [String: Any] = [
                        "type": "input_audio_buffer.append",
                        "audio": base64
                    ]
                    try await sendMessage(message)
                    
                    // Clear buffer and update commit time
                    audioBuffer.removeAll()
                    lastCommitTime = now
                }
            } catch {
                print("Error sending audio: \(error)")
            }
        }
    }
    
    private func receiveMessages() {
        guard let webSocketTask = webSocketTask else { return }
        
        webSocketTask.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    Task {
                        await self?.handleMessage(text)
                    }
                case .data(let data):
                    // Handle binary audio data
                    self?.audioPlayer?.playAudio(data)
                @unknown default:
                    break
                }
                
                // Continue receiving
                self?.receiveMessages()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                Task { @MainActor in
                    self?.onStateChange(.error(error.localizedDescription))
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        switch type {
        case "session.created":
            if let sessionId = json["session_id"] as? String {
                self.sessionId = sessionId
                print("✅ OpenAI session created: \(sessionId)")
            }
            // Send pending configuration now that session is ready
            if let config = pendingConfig {
                Task {
                    do {
                        try await config()
                        pendingConfig = nil
                    } catch {
                        print("❌ Failed to configure session: \(error)")
                        onStateChange(.error(error.localizedDescription))
                    }
                }
            }
            
        case "response.audio_transcript.delta":
            if let delta = json["delta"] as? String {
                // This is partial transcript - we'll accumulate it
                // For now, just pass it through
                onTranscript(delta)
            }
            
        case "response.audio_transcript.done":
            if let transcript = json["text"] as? String {
                onTranscript(transcript)
            }
            
        case "response.function_call_arguments.done":
            if let name = json["name"] as? String,
               let arguments = json["arguments"] as? String,
               let argsData = arguments.data(using: .utf8),
               let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] {
                
                let toolCallId = json["id"] as? String ?? UUID().uuidString
                let anyCodableArgs = argsDict.mapValues { AnyCodable($0) }
                let toolCall = ToolCall(id: toolCallId, name: name, arguments: anyCodableArgs)
                
                onToolCall(toolCall)
            }
            
        case "response.done":
            // Response complete
            onStateChange(.listening)
            
        case "error":
            if let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ OpenAI Realtime error: \(message)")
                print("   Full error: \(error)")
                onStateChange(.error(message))
            } else {
                print("❌ OpenAI Realtime unknown error: \(json)")
            }
            
        default:
            break
        }
    }
    
    func toggleListening() {
        isListening.toggle()
        if isListening {
            if let cap = audioCapture {
                do {
                    try cap.start()
                } catch {
                    print("Failed to start audio capture: \(error)")
                }
            }
            onStateChange(.listening)
        } else {
            audioCapture?.stop()
            onStateChange(.idle)
        }
    }
    
    func sendToolResult(toolCallId: String, result: ToolResult) async {
        var resultData: [String: Any] = [
            "success": result.success,
            "message": result.message
        ]
        
        if let data = result.data {
            resultData["data"] = data.mapValues { $0.value }
        }
        
        let message: [String: Any] = [
            "type": "response.create",
            "response": [
                "type": "function_call_output",
                "id": toolCallId,
                "output": try! JSONSerialization.data(withJSONObject: resultData).base64EncodedString()
            ]
        ]
        
        do {
            try await sendMessage(message)
        } catch {
            print("Error sending tool result: \(error)")
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        audioCapture?.stop()
        audioPlayer?.stop()
        isListening = false
    }
}

