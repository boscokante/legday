import Foundation

struct ToolCall: Codable {
    let id: String
    let name: String
    let arguments: [String: AnyCodable]
}

struct ToolDefinition: Codable {
    let name: String
    let description: String
    let parameters: JSONSchema
}

struct JSONSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]?
    let required: [String]?
}

struct PropertySchema: Codable {
    let type: String
    let description: String?
    let enumValues: [String]?
    
    enum CodingKeys: String, CodingKey {
        case type, description
        case enumValues = "enum"
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

extension ToolCall {
    func getString(_ key: String) -> String? {
        return arguments[key]?.value as? String
    }
    
    func getInt(_ key: String) -> Int? {
        if let int = arguments[key]?.value as? Int {
            return int
        }
        if let double = arguments[key]?.value as? Double {
            return Int(double)
        }
        return nil
    }
    
    func getDouble(_ key: String) -> Double? {
        if let double = arguments[key]?.value as? Double {
            return double
        }
        if let int = arguments[key]?.value as? Int {
            return Double(int)
        }
        return nil
    }
    
    func getBool(_ key: String) -> Bool? {
        return arguments[key]?.value as? Bool
    }
}

struct ToolSchemas {
    static let allTools: [ToolDefinition] = [
        ToolDefinition(
            name: "suggest_workout_day",
            description: "ONLY use this when the user explicitly asks what workout they should do today, or asks for a workout recommendation. Do NOT use this for general questions about their history or personal records.",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "history_focus": PropertySchema(type: "string", description: "Optional focus area (e.g., 'legs', 'upper body')", enumValues: nil)
                ],
                required: []
            )
        ),
        ToolDefinition(
            name: "navigate",
            description: "Navigates to a specific screen in the app",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "destination": PropertySchema(type: "string", description: "Screen to navigate to", enumValues: ["today", "history", "templates", "exercises"]),
                    "argument": PropertySchema(type: "string", description: "Optional argument (e.g., exercise name, template name)", enumValues: nil)
                ],
                required: ["destination"]
            )
        ),
        ToolDefinition(
            name: "select_exercise",
            description: "Selects an exercise in the current workout",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "name": PropertySchema(type: "string", description: "Name of the exercise", enumValues: nil)
                ],
                required: ["name"]
            )
        ),
        ToolDefinition(
            name: "recommend_weight",
            description: "Recommends weight for an exercise based on history and target reps",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "exercise": PropertySchema(type: "string", description: "Exercise name", enumValues: nil),
                    "reps": PropertySchema(type: "integer", description: "Target number of reps", enumValues: nil),
                    "rpe": PropertySchema(type: "number", description: "Optional RPE (Rate of Perceived Exertion) 1-10", enumValues: nil)
                ],
                required: ["exercise", "reps"]
            )
        ),
        ToolDefinition(
            name: "log_set",
            description: "Logs a completed set for an exercise",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "exercise": PropertySchema(type: "string", description: "Exercise name", enumValues: nil),
                    "reps": PropertySchema(type: "integer", description: "Number of reps completed", enumValues: nil),
                    "weight": PropertySchema(type: "number", description: "Weight used in pounds", enumValues: nil),
                    "rpe": PropertySchema(type: "number", description: "Optional RPE 1-10", enumValues: nil),
                    "notes": PropertySchema(type: "string", description: "Optional notes", enumValues: nil)
                ],
                required: ["exercise", "reps", "weight"]
            )
        ),
        ToolDefinition(
            name: "undo_last_set",
            description: "Undoes the last logged set for an exercise",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "exercise": PropertySchema(type: "string", description: "Optional exercise name. If not provided, undoes last set from any exercise", enumValues: nil)
                ],
                required: []
            )
        ),
        ToolDefinition(
            name: "summarize_history",
            description: "Provides detailed summary of workout history including personal records, recent sessions, and exercise data. Use this when asked about specific exercises, max weights, workout history, or when you need more detailed information than what's in the initial context.",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "windowDays": PropertySchema(type: "integer", description: "Number of days to look back (default: 30, use larger numbers like 90 or 365 for all-time records)", enumValues: nil)
                ],
                required: []
            )
        ),
        ToolDefinition(
            name: "set_superset",
            description: "Sets the two exercises to display in the superset dashboard at the top of the chat. Use this when the user starts a workout or asks to do specific exercises. The dashboard shows current set, weight, reps, and a Done button for each exercise.",
            parameters: JSONSchema(
                type: "object",
                properties: [
                    "exercise_a": PropertySchema(type: "string", description: "Primary exercise name (e.g., 'Bench Press')", enumValues: nil),
                    "exercise_b": PropertySchema(type: "string", description: "Secondary/alternate exercise to superset with (e.g., 'Standing Calf Raise')", enumValues: nil)
                ],
                required: []
            )
        )
    ]
}



