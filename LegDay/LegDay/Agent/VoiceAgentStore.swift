import Foundation
import SwiftUI
import Combine

enum AgentState: Equatable {
    case idle
    case listening
    case thinking
    case speaking
    case error(String)
}

// Persistable chat message
struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}

@MainActor
class VoiceAgentStore: ObservableObject {
    @Published var state: AgentState = .idle
    @Published var transcript: String = ""
    @Published var isActive: Bool = false
    @Published var audioLevel: Float = 0.0
    @Published var chatMessages: [ChatMessage] = []
    
    private var realtimeSession: OpenAIRealtimeSession?
    let intentRouter: IntentRouter
    private let historyProvider: HistorySummaryProvider
    private let weightService: WeightRecommendationService
    let chatClient: ChatClient
    
    private let chatStorageKey = "coachChatMessages"
    
    init() {
        self.intentRouter = IntentRouter()
        self.historyProvider = HistorySummaryProvider()
        self.weightService = WeightRecommendationService()
        self.chatClient = ChatClient()
        loadChatMessages()
    }
    
    // MARK: - Chat Persistence
    
    private func loadChatMessages() {
        guard let data = UserDefaults.standard.data(forKey: chatStorageKey),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return
        }
        chatMessages = messages
    }
    
    private func saveChatMessages() {
        guard let data = try? JSONEncoder().encode(chatMessages) else { return }
        UserDefaults.standard.set(data, forKey: chatStorageKey)
    }
    
    func addChatMessage(_ message: ChatMessage) {
        chatMessages.append(message)
        saveChatMessages()
    }
    
    /// Update the content of an existing message (for streaming)
    func updateChatMessage(id: UUID, content: String) {
        if let index = chatMessages.firstIndex(where: { $0.id == id }) {
            let oldMessage = chatMessages[index]
            chatMessages[index] = ChatMessage(
                id: oldMessage.id,
                role: oldMessage.role,
                content: content,
                timestamp: oldMessage.timestamp
            )
            // Don't save during streaming - save when complete
        }
    }
    
    /// Finalize a streaming message (save to storage)
    func finalizeChatMessage(id: UUID) {
        saveChatMessages()
    }
    
    func clearChatHistory() {
        chatMessages.removeAll()
        UserDefaults.standard.removeObject(forKey: chatStorageKey)
    }
    
    func startSession() async {
        guard !isActive else { return }
        
        do {
            isActive = true
            state = .listening
            
            let session = OpenAIRealtimeSession(
                onTranscript: { [weak self] text in
                    Task { @MainActor in
                        self?.transcript = text
                    }
                },
                onToolCall: { [weak self] toolCall in
                    Task { @MainActor in
                        await self?.handleToolCall(toolCall)
                    }
                },
                onAudioLevel: { [weak self] level in
                    Task { @MainActor in
                        self?.audioLevel = level
                    }
                },
                onStateChange: { [weak self] newState in
                    Task { @MainActor in
                        self?.state = newState
                    }
                }
            )
            
            self.realtimeSession = session
            
            // Get history summary for context
            let historySummary = await historyProvider.getSummary(windowDays: 30)
            
            try await session.connect(historyContext: historySummary)
            
        } catch {
            print("❌ Voice agent error: \(error)")
            state = .error(error.localizedDescription)
            isActive = false
        }
    }
    
    func stopSession() {
        realtimeSession?.disconnect()
        realtimeSession = nil
        isActive = false
        state = .idle
        transcript = ""
    }
    
    func toggleListening() {
        if isActive {
            realtimeSession?.toggleListening()
        }
    }
    
    private func handleToolCall(_ toolCall: ToolCall) async {
        state = .thinking
        
        do {
            let result = try await intentRouter.execute(toolCall)
            
            // Send result back to LLM
            await realtimeSession?.sendToolResult(
                toolCallId: toolCall.id,
                result: result
            )
            
            state = .listening
        } catch {
            state = .error("Tool execution failed: \(error.localizedDescription)")
        }
    }
    
    // Expose services for programmatic access
    var weightRecommendationService: WeightRecommendationService {
        return weightService
    }
    
    var historySummaryProvider: HistorySummaryProvider {
        return historyProvider
    }
}

