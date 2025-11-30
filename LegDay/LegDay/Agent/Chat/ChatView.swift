import SwiftUI

struct ChatView: View {
    @EnvironmentObject var voiceAgent: VoiceAgentStore
    @State private var inputText: String = ""
    @State private var isStreaming: Bool = false
    @State private var streamingMessageId: UUID? = nil
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages list
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(voiceAgent.chatMessages) { message in
                                ChatBubble(message: message, isStreaming: message.id == streamingMessageId)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: voiceAgent.chatMessages.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: voiceAgent.chatMessages.last?.content) { _, _ in
                        // Scroll as content streams in
                        if streamingMessageId != nil {
                            scrollToBottom(proxy: proxy)
                        }
                    }
                    .onAppear {
                        scrollToBottom(proxy: proxy)
                    }
                }
                
                Divider()
                
                // Input area
                HStack(spacing: 12) {
                    TextField("Ask about your workout...", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(inputText.isEmpty || isStreaming)
                }
                .padding()
            }
            .navigationTitle("Coach Chat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            voiceAgent.clearChatHistory()
                            addWelcomeMessage()
                        } label: {
                            Label("Clear Chat", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                if voiceAgent.chatMessages.isEmpty {
                    addWelcomeMessage()
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = voiceAgent.chatMessages.last {
            withAnimation(.easeOut(duration: 0.15)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
    
    private func addWelcomeMessage() {
        let welcome = ChatMessage(
            role: .assistant,
            content: "Hey! Ready to work out? Ask me what you should do today, and I'll check your history and give you recommendations! 💪"
        )
        voiceAgent.addChatMessage(welcome)
    }
    
    private func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }
        
        // Save the query
        let query = trimmedInput
        
        // Dismiss keyboard and clear input
        isInputFocused = false
        
        // Clear on next run loop to ensure SwiftUI picks up the change
        DispatchQueue.main.async {
            self.inputText = ""
        }
        
        // Add user message
        let userMessage = ChatMessage(role: .user, content: query)
        voiceAgent.addChatMessage(userMessage)
        
        // Create placeholder for streaming response
        let responseId = UUID()
        let placeholderMessage = ChatMessage(id: responseId, role: .assistant, content: "")
        voiceAgent.addChatMessage(placeholderMessage)
        
        streamingMessageId = responseId
        isStreaming = true
        
        Task {
            do {
                setupIntentRouterHandlers()
                
                var accumulatedContent = ""
                
                _ = try await voiceAgent.chatClient.sendMessageStreaming(
                    query: query,
                    history: voiceAgent.chatMessages.dropLast().map { ($0.role, $0.content) }, // Exclude placeholder
                    historyContext: await voiceAgent.historySummaryProvider.getSummary(windowDays: 30),
                    intentRouter: voiceAgent.intentRouter,
                    onChunk: { chunk in
                        accumulatedContent += chunk
                        Task { @MainActor in
                            voiceAgent.updateChatMessage(id: responseId, content: accumulatedContent)
                        }
                    }
                )
                
                await MainActor.run {
                    // Finalize the message
                    if accumulatedContent.isEmpty {
                        voiceAgent.updateChatMessage(id: responseId, content: "I'm not sure how to respond to that.")
                    }
                    voiceAgent.finalizeChatMessage(id: responseId)
                    streamingMessageId = nil
                    isStreaming = false
                }
            } catch {
                await MainActor.run {
                    voiceAgent.updateChatMessage(id: responseId, content: "Sorry, I encountered an error: \(error.localizedDescription)")
                    voiceAgent.finalizeChatMessage(id: responseId)
                    streamingMessageId = nil
                    isStreaming = false
                }
            }
        }
    }
    
    private func setupIntentRouterHandlers() {
        // Set up basic handlers - full implementation will wire to DailyWorkoutSession
        // For now, these handlers will just log actions
        voiceAgent.intentRouter.setNavigationHandler { destination, argument in
            print("Navigate to \(destination): \(argument ?? "")")
        }
        
        voiceAgent.intentRouter.setExerciseSelectionHandler { exerciseName in
            print("Select exercise: \(exerciseName)")
        }
        
        voiceAgent.intentRouter.setLogSetHandler { exercise, reps, weight, rpe, notes in
            print("Log set: \(exercise) - \(reps) reps @ \(weight) lbs")
        }
        
        voiceAgent.intentRouter.setUndoSetHandler { exerciseName in
            print("Undo last set for: \(exerciseName ?? "any exercise")")
        }
        
        // Wire up services
        voiceAgent.intentRouter.setWeightService(voiceAgent.weightRecommendationService)
        voiceAgent.intentRouter.setHistoryProvider(voiceAgent.historySummaryProvider)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    var isStreaming: Bool = false
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if message.content.isEmpty && isStreaming {
                        // Show typing indicator when waiting for first chunk
                        HStack(spacing: 4) {
                            ForEach(0..<3) { i in
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 6, height: 6)
                                    .opacity(0.6)
                            }
                        }
                        .padding(12)
                    } else {
                        Text(message.content)
                            .padding(12)
                    }
                    
                    if isStreaming && !message.content.isEmpty {
                        // Cursor indicator while streaming
                        Rectangle()
                            .fill(Color.primary)
                            .frame(width: 2, height: 16)
                            .opacity(0.6)
                    }
                }
                .background(message.role == .user ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.role == .user ? .white : .primary)
                .cornerRadius(16)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

