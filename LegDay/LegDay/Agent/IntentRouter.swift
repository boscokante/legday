import Foundation

struct ToolResult: Codable {
    let success: Bool
    let message: String
    let data: [String: AnyCodable]?
    
    init(success: Bool, message: String, data: [String: AnyCodable]? = nil) {
        self.success = success
        self.message = message
        self.data = data
    }
}

class IntentRouter {
    private var navigationHandler: ((String, String?) -> Void)?
    private var exerciseSelectionHandler: ((String) -> Void)?
    private var logSetHandler: ((String, Int, Double, Double?, String?) -> Void)?
    private var undoSetHandler: ((String?) -> Void)?
    private var dailyWorkout: DailyWorkoutSession?
    private var weightService: WeightRecommendationService?
    private var historyProvider: HistorySummaryProvider?
    
    func setNavigationHandler(_ handler: @escaping (String, String?) -> Void) {
        self.navigationHandler = handler
    }
    
    func setExerciseSelectionHandler(_ handler: @escaping (String) -> Void) {
        self.exerciseSelectionHandler = handler
    }
    
    func setLogSetHandler(_ handler: @escaping (String, Int, Double, Double?, String?) -> Void) {
        self.logSetHandler = handler
    }
    
    func setUndoSetHandler(_ handler: @escaping (String?) -> Void) {
        self.undoSetHandler = handler
    }
    
    func setDailyWorkout(_ workout: DailyWorkoutSession) {
        self.dailyWorkout = workout
    }
    
    func setWeightService(_ service: WeightRecommendationService) {
        self.weightService = service
    }
    
    func setHistoryProvider(_ provider: HistorySummaryProvider) {
        self.historyProvider = provider
    }
    
    func execute(_ toolCall: ToolCall) async throws -> ToolResult {
        switch toolCall.name {
        case "suggest_workout_day":
            return try await handleSuggestWorkoutDay(toolCall)
            
        case "navigate":
            return try await handleNavigate(toolCall)
            
        case "select_exercise":
            return try await handleSelectExercise(toolCall)
            
        case "recommend_weight":
            return try await handleRecommendWeight(toolCall)
            
        case "log_set":
            return try await handleLogSet(toolCall)
            
        case "undo_last_set":
            return try await handleUndoLastSet(toolCall)
            
        case "summarize_history":
            return try await handleSummarizeHistory(toolCall)
            
        default:
            return ToolResult(success: false, message: "Unknown tool: \(toolCall.name)")
        }
    }
    
    private func handleSuggestWorkoutDay(_ toolCall: ToolCall) async throws -> ToolResult {
        let historyFocus = toolCall.getString("history_focus")
        let summary: HistorySummary
        if let provider = historyProvider {
            summary = await provider.getSummary(windowDays: 30)
        } else {
            summary = await HistorySummaryProvider().getSummary(windowDays: 30)
        }
        
        // Simple logic: suggest based on days since last workout and focus
        let daysSince = summary.daysSinceLastWorkout ?? 999
        let lastDay = summary.lastWorkoutDay ?? ""
        
        var recommendation = "Leg Day"
        var rationale = "Based on your workout history"
        
        if daysSince >= 3 && lastDay.contains("Leg") {
            recommendation = "Leg Day"
            rationale = "It's been \(daysSince) days since your last leg workout. Time for leg day!"
        } else if daysSince >= 2 {
            // Rotate through days
            let configManager = WorkoutConfigManager.shared
            let allDays = configManager.workoutDays
            if let lastDayConfig = allDays.first(where: { $0.name == lastDay }),
               let lastIndex = allDays.firstIndex(where: { $0.id == lastDayConfig.id }),
               lastIndex + 1 < allDays.count {
                recommendation = allDays[lastIndex + 1].name
                rationale = "Rotating to \(recommendation) after \(lastDay)"
            }
        }
        
        if let focus = historyFocus {
            rationale += " (Focus: \(focus))"
        }
        
        return ToolResult(
            success: true,
            message: "Suggested workout day",
            data: [
                "recommendation": AnyCodable(recommendation),
                "rationale": AnyCodable(rationale)
            ]
        )
    }
    
    private func handleNavigate(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let destination = toolCall.getString("destination") else {
            return ToolResult(success: false, message: "Missing destination parameter")
        }
        
        let argument = toolCall.getString("argument")
        
        navigationHandler?(destination, argument)
        
        return ToolResult(
            success: true,
            message: "Navigated to \(destination)",
            data: ["destination": AnyCodable(destination)]
        )
    }
    
    private func handleSelectExercise(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let name = toolCall.getString("name") else {
            return ToolResult(success: false, message: "Missing name parameter")
        }
        
        exerciseSelectionHandler?(name)
        
        return ToolResult(
            success: true,
            message: "Selected exercise: \(name)",
            data: ["exercise": AnyCodable(name)]
        )
    }
    
    private func handleRecommendWeight(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let exercise = toolCall.getString("exercise"),
              let reps = toolCall.getInt("reps") else {
            return ToolResult(success: false, message: "Missing exercise or reps parameter")
        }
        
        let rpe = toolCall.getDouble("rpe")
        let service = weightService ?? WeightRecommendationService()
        let recommendation = await service.recommendWeight(exercise: exercise, targetReps: reps, rpe: rpe)
        
        return ToolResult(
            success: true,
            message: recommendation.rationale,
            data: [
                "weight": AnyCodable(recommendation.weight),
                "rationale": AnyCodable(recommendation.rationale)
            ]
        )
    }
    
    private func handleLogSet(_ toolCall: ToolCall) async throws -> ToolResult {
        guard let exercise = toolCall.getString("exercise"),
              let reps = toolCall.getInt("reps"),
              let weight = toolCall.getDouble("weight") else {
            return ToolResult(success: false, message: "Missing required parameters: exercise, reps, weight")
        }
        
        let rpe = toolCall.getDouble("rpe")
        let notes = toolCall.getString("notes")
        
        logSetHandler?(exercise, reps, weight, rpe, notes)
        
        let weightString = String(format: "%.0f", weight)
        return ToolResult(
            success: true,
            message: "Logged \(reps) reps at \(weightString) lbs for \(exercise)",
            data: [
                "exercise": AnyCodable(exercise),
                "reps": AnyCodable(reps),
                "weight": AnyCodable(weight)
            ]
        )
    }
    
    private func handleUndoLastSet(_ toolCall: ToolCall) async throws -> ToolResult {
        let exercise = toolCall.getString("exercise")
        
        undoSetHandler?(exercise)
        
        let message = if let exercise = exercise {
            "Undid last set for \(exercise)"
        } else {
            "Undid last set"
        }
        
        return ToolResult(success: true, message: message)
    }
    
    private func handleSummarizeHistory(_ toolCall: ToolCall) async throws -> ToolResult {
        let windowDays = toolCall.getInt("windowDays") ?? 30
        let provider = historyProvider ?? HistorySummaryProvider()
        let summary = await provider.getSummary(windowDays: windowDays)
        
        let summaryJSON = await provider.getSummaryJSON(windowDays: windowDays)
        
        return ToolResult(
            success: true,
            message: summary.highlights,
            data: [
                "summary": AnyCodable(summaryJSON),
                "highlights": AnyCodable(summary.highlights)
            ]
        )
    }
}

