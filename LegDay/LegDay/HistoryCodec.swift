import Foundation

// LegDay History file format (.legday): JSON, versioned, UTF-8
//
// {
//   "version": 1,
//   "exportedAt": 1734567890.0,
//   "workouts": [
//     {
//       "date": 1734480000.0,                // seconds since 1970
//       "day": "Leg Day" | "Push Day" | "Pull Day" | "Core Day" | "Leg Day, Core Day",
//       "notes": "optional notes",
//       "exercises": {
//         "Bench Press": [ {"weight": 135.0, "reps": 10, "warmup": true}, ... ]
//       }
//     }
//   ]
// }

struct LegDayHistory: Codable {
    var version: Int
    var exportedAt: TimeInterval
    var workouts: [Workout]
}

struct Workout: Codable {
    var date: TimeInterval
    var day: String?
    var notes: String?
    var exercises: [String: [SetEntry]]
}

struct SetEntry: Codable {
    var weight: Double
    var reps: Int
    var warmup: Bool
}

enum HistoryCodec {
    static let currentVersion = 1
    static let fileExtension = "legday"
    
    // Helper to load saved workouts from UserDefaults
    static func loadSavedWorkouts() -> [[String: Any]] {
        if let data = UserDefaults.standard.data(forKey: "savedWorkouts"),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return array
        }
        return []
    }
    
    static func exportToData() throws -> Data {
        // Load from Data format in UserDefaults
        var saved: [[String: Any]] = []
        if let data = UserDefaults.standard.data(forKey: "savedWorkouts"),
           let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            saved = array
        }
        
        let workouts: [Workout] = saved.map { dict in
            let date = dict["date"] as? TimeInterval ?? Date().timeIntervalSince1970
            let day = dict["day"] as? String
            let notes = dict["notes"] as? String
            var exercises: [String: [SetEntry]] = [:]
            if let ex = dict["exercises"] as? [String: [[String: Any]]] {
                for (name, arr) in ex {
                    let sets = arr.compactMap { entry -> SetEntry? in
                        guard let w = entry["weight"] as? Double,
                              let r = entry["reps"] as? Int,
                              let warm = entry["warmup"] as? Bool else { return nil }
                        return SetEntry(weight: w, reps: r, warmup: warm)
                    }
                    exercises[name] = sets
                }
            }
            return Workout(date: date, day: day, notes: notes, exercises: exercises)
        }
        let payload = LegDayHistory(version: currentVersion, exportedAt: Date().timeIntervalSince1970, workouts: workouts)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(payload)
    }
    
    static func importFromData(_ data: Data) throws {
        let dec = JSONDecoder()
        let payload = try dec.decode(LegDayHistory.self, from: data)
        guard payload.version == currentVersion else {
            throw NSError(domain: "legday.codec", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file version \(payload.version)"])
        }
        
        // Load existing saved workouts
        var saved: [[String: Any]] = []
        if let existingData = UserDefaults.standard.data(forKey: "savedWorkouts"),
           let existingArray = try? JSONSerialization.jsonObject(with: existingData) as? [[String: Any]] {
            saved = existingArray
        }
        
        for w in payload.workouts {
            var dict: [String: Any] = [
                "date": w.date,
                "day": w.day as Any,
                "notes": w.notes as Any
            ]
            var ex: [String: [[String: Any]]] = [:]
            for (name, sets) in w.exercises {
                ex[name] = sets.map { [
                    "weight": $0.weight,
                    "reps": $0.reps,
                    "warmup": $0.warmup
                ] }
            }
            dict["exercises"] = ex
            // dedupe by day
            saved.removeAll { existing in
                if let ts = existing["date"] as? TimeInterval {
                    return Calendar.current.isDate(Date(timeIntervalSince1970: ts), inSameDayAs: Date(timeIntervalSince1970: w.date))
                }
                return false
            }
            saved.append(dict)
        }
        saved.sort { ($0["date"] as? TimeInterval ?? 0) < ($1["date"] as? TimeInterval ?? 0) }
        
        // Encode to Data before saving
        if let jsonData = try? JSONSerialization.data(withJSONObject: saved) {
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
        }
    }
    
    // Utility function to split combined workouts into separate entries
    // This fixes old history where multiple days were combined into one entry
    static func splitCombinedWorkouts() {
        let saved = loadSavedWorkouts()
        var updatedWorkouts: [[String: Any]] = []
        
        for workout in saved {
            guard let dayString = workout["day"] as? String else {
                updatedWorkouts.append(workout)
                continue
            }
            
            // Check if this is a combined workout (contains comma or multiple day names)
            let dayNames = dayString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            
            if dayNames.count > 1 {
                // This is a combined workout - split it
                
                guard let date = workout["date"] as? TimeInterval,
                      let exercises = workout["exercises"] as? [String: [[String: Any]]],
                      let notes = workout["notes"] as? String else {
                    updatedWorkouts.append(workout)
                    continue
                }
                
                // Split notes by day (format: "Day Name: notes")
                let notesLines = notes.components(separatedBy: "\n")
                var notesByDay: [String: String] = [:]
                for line in notesLines {
                    for dayName in dayNames {
                        if line.hasPrefix("\(dayName):") {
                            let noteContent = String(line.dropFirst(dayName.count + 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                            notesByDay[dayName] = noteContent
                            break
                        }
                    }
                }
                
                // Determine which exercises belong to which day based on workout day configurations
                // We'll need to check against WorkoutConfigManager, but for now, use heuristics
                // Common exercise patterns for each day type
                let legDayExercises = ["Squat", "Leg Press", "Lunge", "Calf", "Hamstring", "Quad", "Bulgarian", "RDL", "Extension", "Curl"]
                let pushDayExercises = ["Bench", "Press", "Push", "Tricep", "Shoulder", "Dips", "Incline"]
                let pullDayExercises = ["Pull", "Row", "Lat", "Curl", "Back", "Chin"]
                _ = ["Achilles", "Calf", "Rehab"]  // achillesExercises - used in pattern matching below
                
                var exercisesByDay: [String: [String: [[String: Any]]]] = [:]
                
                for (exerciseName, sets) in exercises {
                    var assigned = false
                    
                    // Check for Achilles rehab exercises first
                    if exerciseName.lowercased().contains("achilles") {
                        if exerciseName.lowercased().contains("light") {
                            if exercisesByDay["Achilles Rehab Light"] == nil {
                                exercisesByDay["Achilles Rehab Light"] = [:]
                            }
                            exercisesByDay["Achilles Rehab Light"]?[exerciseName] = sets
                            assigned = true
                        } else if exerciseName.lowercased().contains("heavy") {
                            if exercisesByDay["Achilles Rehab Heavy"] == nil {
                                exercisesByDay["Achilles Rehab Heavy"] = [:]
                            }
                            exercisesByDay["Achilles Rehab Heavy"]?[exerciseName] = sets
                            assigned = true
                        }
                    }
                    
                    if !assigned {
                        // Try to match to workout days
                        let exerciseLower = exerciseName.lowercased()
                        
                        for dayName in dayNames {
                            if dayName.lowercased().contains("leg") {
                                if legDayExercises.contains(where: { exerciseLower.contains($0.lowercased()) }) {
                                    if exercisesByDay[dayName] == nil {
                                        exercisesByDay[dayName] = [:]
                                    }
                                    exercisesByDay[dayName]?[exerciseName] = sets
                                    assigned = true
                                    break
                                }
                            } else if dayName.lowercased().contains("push") {
                                if pushDayExercises.contains(where: { exerciseLower.contains($0.lowercased()) }) {
                                    if exercisesByDay[dayName] == nil {
                                        exercisesByDay[dayName] = [:]
                                    }
                                    exercisesByDay[dayName]?[exerciseName] = sets
                                    assigned = true
                                    break
                                }
                            } else if dayName.lowercased().contains("pull") {
                                if pullDayExercises.contains(where: { exerciseLower.contains($0.lowercased()) }) {
                                    if exercisesByDay[dayName] == nil {
                                        exercisesByDay[dayName] = [:]
                                    }
                                    exercisesByDay[dayName]?[exerciseName] = sets
                                    assigned = true
                                    break
                                }
                            }
                        }
                    }
                    
                    // If not assigned, assign to first matching day or first day
                    if !assigned {
                        let targetDay = dayNames.first ?? "Unknown"
                        if exercisesByDay[targetDay] == nil {
                            exercisesByDay[targetDay] = [:]
                        }
                        exercisesByDay[targetDay]?[exerciseName] = sets
                    }
                }
                
                // Create separate entries for each day
                for dayName in dayNames {
                    if let dayExercises = exercisesByDay[dayName], !dayExercises.isEmpty {
                        let workoutData: [String: Any] = [
                            "date": date,
                            "exercises": dayExercises,
                            "notes": notesByDay[dayName] ?? "",
                            "day": dayName
                        ]
                        updatedWorkouts.append(workoutData)
                    }
                }
                
                // Also check for Achilles Rehab entries
                if let achillesLight = exercisesByDay["Achilles Rehab Light"], !achillesLight.isEmpty {
                    let workoutData: [String: Any] = [
                        "date": date,
                        "exercises": achillesLight,
                        "notes": notesByDay["Achilles Rehab Light"] ?? "",
                        "day": "Achilles Rehab Light"
                    ]
                    updatedWorkouts.append(workoutData)
                }
                
                if let achillesHeavy = exercisesByDay["Achilles Rehab Heavy"], !achillesHeavy.isEmpty {
                    let workoutData: [String: Any] = [
                        "date": date,
                        "exercises": achillesHeavy,
                        "notes": notesByDay["Achilles Rehab Heavy"] ?? "",
                        "day": "Achilles Rehab Heavy"
                    ]
                    updatedWorkouts.append(workoutData)
                }
            } else {
                // Not combined, keep as is
                updatedWorkouts.append(workout)
            }
        }
        
        // Sort by date
        updatedWorkouts.sort { ($0["date"] as? TimeInterval ?? 0) < ($1["date"] as? TimeInterval ?? 0) }
        
        // Save updated workouts
        if let jsonData = try? JSONSerialization.data(withJSONObject: updatedWorkouts) {
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
        }
    }
}


