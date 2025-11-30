import Foundation

class ChatClient {
    private let apiKey: String
    
    init() {
        self.apiKey = Secrets.openAIAPIKey
    }
    
    // MARK: - Streaming API
    
    /// Send message with streaming - calls onChunk for each text chunk as it arrives
    func sendMessageStreaming(
        query: String,
        history: [(MessageRole, String)],
        historyContext: HistorySummary,
        intentRouter: IntentRouter,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            throw NSError(domain: "ChatClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        // Build request components
        let (apiMessages, tools) = await buildRequestComponents(history: history)
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Debug: print system prompt length
        if let systemContent = apiMessages.first?["content"] as? String {
            print("📝 System prompt length: \(systemContent.count) chars")
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-5-mini",
            "messages": apiMessages,
            "tools": tools,
            "tool_choice": "auto",
            "max_completion_tokens": 400,
            "stream": true
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        // Use URLSession bytes for streaming
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "ChatClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        if httpResponse.statusCode != 200 {
            // Try to read error body
            var errorBody = ""
            for try await line in bytes.lines {
                errorBody += line
            }
            print("❌ API Error \(httpResponse.statusCode): \(errorBody)")
            throw NSError(domain: "ChatClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error (\(httpResponse.statusCode)): \(errorBody.prefix(200))"])
        }
        
        var fullContent = ""
        var toolCallsData: [String: (name: String, arguments: String)] = [:]
        var lineCount = 0
        
        // Process SSE stream
        for try await line in bytes.lines {
            lineCount += 1
            
            guard line.hasPrefix("data: ") else { continue }
            let jsonString = String(line.dropFirst(6))
            
            if jsonString == "[DONE]" { 
                print("✅ Stream complete, content length: \(fullContent.count), tool calls: \(toolCallsData.count)")
                break 
            }
            
            guard let data = jsonString.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any] else {
                continue
            }
            
            // Handle text content (supports string or array parts)
            if let content = delta["content"] as? String {
                fullContent += content
                onChunk(content)
            } else if let contentParts = delta["content"] as? [[String: Any]] {
                for part in contentParts {
                    if let text = part["text"] as? String {
                        fullContent += text
                        onChunk(text)
                    } else if let nested = part["content"] as? String {
                        fullContent += nested
                        onChunk(nested)
                    }
                }
            }
            
            // Handle tool calls (accumulate)
            if let toolCalls = delta["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    let index = tc["index"] as? Int ?? 0
                    let key = "\(index)"
                    
                    if let id = tc["id"] as? String {
                        toolCallsData[id] = toolCallsData[key] ?? (name: "", arguments: "")
                        if let existing = toolCallsData[key] {
                            toolCallsData[id] = existing
                            toolCallsData.removeValue(forKey: key)
                        }
                    }
                    
                    if let function = tc["function"] as? [String: Any] {
                        let currentKey = tc["id"] as? String ?? key
                        var existing = toolCallsData[currentKey] ?? (name: "", arguments: "")
                        if let name = function["name"] as? String {
                            existing.name = name
                        }
                        if let args = function["arguments"] as? String {
                            existing.arguments += args
                        }
                        toolCallsData[currentKey] = existing
                    }
                }
            }
        }
        
        // Handle tool calls if any
        if !toolCallsData.isEmpty {
            print("🔧 Processing \(toolCallsData.count) tool calls")
            var toolResults: [(id: String, result: ToolResult)] = []
            
            for (toolId, toolData) in toolCallsData {
                print("🔧 Tool: \(toolData.name), args: \(toolData.arguments.prefix(100))")
                guard !toolData.name.isEmpty,
                      let argsData = toolData.arguments.data(using: .utf8),
                      let argsDict = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
                    print("⚠️ Failed to parse tool arguments")
                    continue
                }
                
                let anyCodableArgs = argsDict.mapValues { AnyCodable($0) }
                let toolCall = ToolCall(id: toolId, name: toolData.name, arguments: anyCodableArgs)
                
                let result = try await intentRouter.execute(toolCall)
                print("🔧 Tool result: \(result.message.prefix(100))")
                toolResults.append((id: toolId, result: result))
            }
            
            if !toolResults.isEmpty {
                let toolResponse = await sendToolResultsStreamingResponse(
                    toolResults: toolResults,
                    messages: apiMessages,
                    toolCallsData: toolCallsData,
                    onChunk: onChunk
                )
                print("🔧 Final tool response: \(toolResponse.prefix(100))")
                return toolResponse
            }
        }
        
        print("⚠️ No content and no tool calls processed")
        return fullContent.isEmpty ? "I'm not sure how to respond to that." : fullContent
    }
    
    // MARK: - Non-streaming API (fallback)
    
    func sendMessage(
        query: String,
        history: [(MessageRole, String)],
        historyContext: HistorySummary,
        intentRouter: IntentRouter
    ) async throws -> String {
        guard !apiKey.isEmpty && apiKey != "YOUR_API_KEY_HERE" else {
            throw NSError(domain: "ChatClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        let (apiMessages, tools) = await buildRequestComponents(history: history)
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-5-mini",
            "messages": apiMessages,
            "tools": tools,
            "tool_choice": "auto",
            "max_completion_tokens": 400
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let errorString = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ChatClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorString)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any] else {
            throw NSError(domain: "ChatClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])
        }
        
        // Check for tool calls
        if let toolCalls = message["tool_calls"] as? [[String: Any]],
           !toolCalls.isEmpty {
            
            var toolResults: [(id: String, result: ToolResult)] = []
            
            for toolCallData in toolCalls {
                guard let function = toolCallData["function"] as? [String: Any],
                      let functionName = function["name"] as? String,
                      let argumentsString = function["arguments"] as? String,
                      let argumentsData = argumentsString.data(using: .utf8),
                      let argumentsDict = try? JSONSerialization.jsonObject(with: argumentsData) as? [String: Any] else {
                    continue
                }
                
                let toolCallId = toolCallData["id"] as? String ?? UUID().uuidString
                let anyCodableArgs = argumentsDict.mapValues { AnyCodable($0) }
                let toolCall = ToolCall(id: toolCallId, name: functionName, arguments: anyCodableArgs)
                
                let result = try await intentRouter.execute(toolCall)
                toolResults.append((id: toolCallId, result: result))
            }
            
            return await sendToolResultsAndGetResponse(
                toolResults: toolResults,
                messages: apiMessages,
                assistantMessage: message
            )
        }
        
        if let content = message["content"] as? String {
            return content
        }
        
        return "I'm not sure how to respond to that."
    }
    
    // MARK: - Shared Helpers
    
    private func buildRequestComponents(history: [(MessageRole, String)]) async -> ([[String: Any]], [[String: Any]]) {
        // Fetch rotation data and PRs in parallel for speed
        let historyProvider = HistorySummaryProvider()
        async let rotationSummaryTask = historyProvider.getSummary(windowDays: 90)
        async let allTimePRsTask = historyProvider.getSummary(windowDays: 3650)
        
        let rotationSummary = await rotationSummaryTask
        let allTimePRs = await allTimePRsTask
        let rotationRec = await historyProvider.getRotationRecommendation()
        
        // Get today's workout context
        let todayWorkoutInfo = await MainActor.run { buildTodayWorkoutContext() }
        
        // Build system prompt
        var systemPrompt = """
        You are an experienced personal trainer. Be BRIEF - under 100 chars unless asked for detail.
        
        TODAY'S RECOMMENDATION: \(rotationRec)
        
        \(todayWorkoutInfo)
        
        Rotation status (days since):
        """
        
        let primaryTypes = ["leg", "push", "pull"]
        for workoutType in primaryTypes {
            if let daysSince = rotationSummary.daysSinceByWorkoutType[workoutType] {
                systemPrompt += "\n- \(workoutType): \(daysSince)d"
            }
        }
        
        if let lastAchilles = rotationSummary.lastAchillesIntensity {
            systemPrompt += "\nLast Achilles: \(lastAchilles) → do \(lastAchilles == "heavy" ? "LIGHT" : "HEAVY") today"
        }
        
        if !allTimePRs.personalRecords.isEmpty {
            systemPrompt += "\n\nPRs:"
            for pr in allTimePRs.personalRecords.sorted(by: { $0.exercise < $1.exercise }) {
                let weightString = String(format: "%.0f", pr.weight)
                systemPrompt += "\n- \(pr.exercise): \(weightString)×\(pr.reps)"
            }
        }
        
        systemPrompt += """
        
        
        RULES:
        - When asked "what should I do today?" → JUST say the recommendation above. Don't list exercises unless asked.
        - When asked about exercises, sets, or weights → refer to TODAY'S WORKOUT above.
        - Keep answers SHORT. No exercise lists unless specifically requested.
        - Only use tools for actions (logging sets, navigating), not for info questions.
        """
        
        var apiMessages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]
        
        let recentHistory = history.suffix(6)
        for (role, content) in recentHistory {
            let roleString = role == .user ? "user" : "assistant"
            apiMessages.append(["role": roleString, "content": content])
        }
        
        let tools = ToolSchemas.allTools.map { tool in
            [
                "type": "function",
                "function": [
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
            ]
        }
        
        return (apiMessages, tools)
    }
    
    /// Build a description of today's workout including exercises and sets
    @MainActor
    private func buildTodayWorkoutContext() -> String {
        let dailyWorkout = DailyWorkoutSession.shared
        let configManager = WorkoutConfigManager.shared
        
        var result = "TODAY'S WORKOUT: \(dailyWorkout.combinedDayName)\n\nEXERCISES:"
        
        // Primary exercises
        let primaryExercises = configManager.getExercisesForDay(dayId: dailyWorkout.dayId)
        for (index, exercise) in primaryExercises.enumerated() {
            let sets = dailyWorkout.getSets(for: exercise)
            result += "\n\(index + 1). \(exercise)"
            if sets.isEmpty {
                result += " (no sets yet)"
            } else {
                result += ":"
                for (setIndex, set) in sets.enumerated() {
                    let status = set.completed ? "✓" : "○"
                    let dataType = ExerciseDataType.type(for: exercise)
                    switch dataType {
                    case .weightReps:
                        result += "\n   \(status) Set \(setIndex + 1): \(Int(set.weight)) lbs × \(set.reps) reps"
                    case .time:
                        let mins = set.minutes ?? 0
                        let secs = set.seconds ?? 0
                        result += "\n   \(status) Set \(setIndex + 1): \(mins)m \(secs)s"
                    case .shots:
                        let shots = set.shotsMade ?? 0
                        result += "\n   \(status) Set \(setIndex + 1): \(shots) shots"
                    case .count:
                        result += "\n   \(status) Set \(setIndex + 1): \(set.reps) count"
                    }
                    if set.warmup {
                        result += " (warmup)"
                    }
                }
            }
        }
        
        // Secondary exercises (if dual focus)
        if let secId = dailyWorkout.secondaryDayId,
           let secName = dailyWorkout.secondaryDayName {
            let secondaryExercises = configManager.getExercisesForDay(dayId: secId)
            if !secondaryExercises.isEmpty {
                result += "\n\n[\(secName)]:"
                let offset = primaryExercises.count
                for (index, exercise) in secondaryExercises.enumerated() {
                    let sets = dailyWorkout.getSets(for: exercise)
                    result += "\n\(offset + index + 1). \(exercise)"
                    if sets.isEmpty {
                        result += " (no sets yet)"
                    } else {
                        result += ":"
                        for (setIndex, set) in sets.enumerated() {
                            let status = set.completed ? "✓" : "○"
                            let dataType = ExerciseDataType.type(for: exercise)
                            switch dataType {
                            case .weightReps:
                                result += "\n   \(status) Set \(setIndex + 1): \(Int(set.weight)) lbs × \(set.reps) reps"
                            case .time:
                                let mins = set.minutes ?? 0
                                let secs = set.seconds ?? 0
                                result += "\n   \(status) Set \(setIndex + 1): \(mins)m \(secs)s"
                            case .shots:
                                let shots = set.shotsMade ?? 0
                                result += "\n   \(status) Set \(setIndex + 1): \(shots) shots"
                            case .count:
                                result += "\n   \(status) Set \(setIndex + 1): \(set.reps) count"
                            }
                            if set.warmup {
                                result += " (warmup)"
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func sendToolResultsStreamingResponse(
        toolResults: [(id: String, result: ToolResult)],
        messages: [[String: Any]],
        toolCallsData: [String: (name: String, arguments: String)],
        onChunk: @escaping (String) -> Void
    ) async -> String {
        var updatedMessages = messages
        
        // Build assistant message with tool calls
        let toolCallsArray = toolCallsData.map { (id, data) in
            [
                "id": id,
                "type": "function",
                "function": [
                    "name": data.name,
                    "arguments": data.arguments
                ]
            ] as [String: Any]
        }
        
        updatedMessages.append([
            "role": "assistant",
            "tool_calls": toolCallsArray
        ])
        
        for (toolCallId, result) in toolResults {
            var resultData: [String: Any] = [
                "success": result.success,
                "message": result.message
            ]
            if let data = result.data {
                resultData["data"] = data.mapValues { $0.value }
            }
            
            let resultString: String
            do {
                let resultJSON = try JSONSerialization.data(withJSONObject: resultData)
                resultString = String(data: resultJSON, encoding: .utf8) ?? "{}"
            } catch {
                resultString = "{\"success\":\(result.success),\"message\":\"\(result.message)\"}"
            }
            
            updatedMessages.append([
                "role": "tool",
                "content": resultString,
                "tool_call_id": toolCallId
            ])
        }
        
        do {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = [
                "model": "gpt-5-mini",
                "messages": updatedMessages,
                "max_completion_tokens": 400,
                "stream": true
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (bytes, _) = try await URLSession.shared.bytes(for: request)
            
            var fullContent = ""
            
            for try await line in bytes.lines {
                guard line.hasPrefix("data: ") else { continue }
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" { break }
                
                guard let data = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let delta = choices.first?["delta"] as? [String: Any],
                      let content = delta["content"] as? String else {
                    continue
                }
                
                fullContent += content
                onChunk(content)
            }
            
            return fullContent
        } catch {
            print("Error getting streaming response: \(error)")
        }
        
        if let firstResult = toolResults.first {
            return firstResult.result.message
        }
        
        return "I completed the action, but couldn't get a response."
    }
    
    private func sendToolResultsAndGetResponse(
        toolResults: [(id: String, result: ToolResult)],
        messages: [[String: Any]],
        assistantMessage: [String: Any]
    ) async -> String {
        var updatedMessages = messages
        updatedMessages.append(assistantMessage)
        
        for (toolCallId, result) in toolResults {
            var resultData: [String: Any] = [
                "success": result.success,
                "message": result.message
            ]
            if let data = result.data {
                resultData["data"] = data.mapValues { $0.value }
            }
            
            let resultString: String
            do {
                let resultJSON = try JSONSerialization.data(withJSONObject: resultData)
                resultString = String(data: resultJSON, encoding: .utf8) ?? "{}"
            } catch {
                resultString = "{\"success\":\(result.success),\"message\":\"\(result.message)\"}"
            }
            
            updatedMessages.append([
                "role": "tool",
                "content": resultString,
                "tool_call_id": toolCallId
            ])
        }
        
        do {
            let url = URL(string: "https://api.openai.com/v1/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = [
                "model": "gpt-5-mini",
                "messages": updatedMessages,
                "max_completion_tokens": 400
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {
            print("Error getting final response: \(error)")
        }
        
        if let firstResult = toolResults.first {
            return firstResult.result.message
        }
        
        return "I completed the action, but couldn't get a response."
    }
}
