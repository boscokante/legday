import Foundation

struct HistorySummary {
    let highlights: String
    let lastSessions: [SessionSummary]
    let personalRecords: [PersonalRecord]
    let recentExercises: [String]
    let daysSinceLastWorkout: Int?
    let lastWorkoutDay: String?
    let daysSinceByWorkoutType: [String: Int]  // e.g. ["leg": 2, "push": 1, "pull": 3]
    let lastAchillesIntensity: String?  // "heavy" or "light"
}

struct SessionSummary {
    let date: Date
    let day: String?
    let exercises: [String]
    let totalSets: Int
}

struct PersonalRecord {
    let exercise: String
    let weight: Double
    let reps: Int
    let date: Date
}

class HistorySummaryProvider {
    func getSummary(windowDays: Int = 30) async -> HistorySummary {
        let workouts = HistoryCodec.loadSavedWorkouts()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -windowDays, to: Date()) ?? Date()
        
        let recentWorkouts = workouts.filter { workout in
            guard let timestamp = workout["date"] as? TimeInterval else { return false }
            let date = Date(timeIntervalSince1970: timestamp)
            return date >= cutoffDate
        }
        
        // Calculate days since last workout
        let lastWorkoutDate = recentWorkouts
            .compactMap { $0["date"] as? TimeInterval }
            .map { Date(timeIntervalSince1970: $0) }
            .max()
        
        let daysSince = lastWorkoutDate.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 }
        
        // Get last workout day
        let lastWorkout = recentWorkouts
            .sorted { ($0["date"] as? TimeInterval ?? 0) > ($1["date"] as? TimeInterval ?? 0) }
            .first
        let lastDay = lastWorkout?["day"] as? String
        
        // Build session summaries
        let sessions = recentWorkouts.map { workout -> SessionSummary in
            let timestamp = workout["date"] as? TimeInterval ?? Date().timeIntervalSince1970
            let date = Date(timeIntervalSince1970: timestamp)
            let day = workout["day"] as? String
            let exercises = workout["exercises"] as? [String: [[String: Any]]] ?? [:]
            let totalSets = exercises.values.reduce(0) { $0 + $1.count }
            
            return SessionSummary(
                date: date,
                day: day,
                exercises: Array(exercises.keys),
                totalSets: totalSets
            )
        }
        
        // Find personal records - actual highest weight lifted (not calculated 1RM)
        var prs: [PersonalRecord] = []
        var exerciseMaxes: [String: (weight: Double, reps: Int, date: Date)] = [:]
        
        for workout in recentWorkouts {
            guard let timestamp = workout["date"] as? TimeInterval,
                  let exercises = workout["exercises"] as? [String: [[String: Any]]] else { continue }
            
            let date = Date(timeIntervalSince1970: timestamp)
            
            for (exerciseName, sets) in exercises {
                for set in sets {
                    guard let weight = set["weight"] as? Double,
                          let reps = set["reps"] as? Int,
                          weight > 0, reps > 0 else { continue }
                    
                    // Track actual highest weight (not calculated 1RM)
                    if let existing = exerciseMaxes[exerciseName] {
                        // Compare by weight first, then by reps if weights are equal
                        if weight > existing.weight || (weight == existing.weight && reps > existing.reps) {
                            exerciseMaxes[exerciseName] = (weight, reps, date)
                        }
                    } else {
                        exerciseMaxes[exerciseName] = (weight, reps, date)
                    }
                }
            }
        }
        
        prs = exerciseMaxes.map { exercise, data in
            PersonalRecord(exercise: exercise, weight: data.weight, reps: data.reps, date: data.date)
        }
        
        // Get recent exercises (last 7 days)
        let recentExercises = Array(Set(sessions
            .filter { Calendar.current.dateComponents([.day], from: $0.date, to: Date()).day ?? 0 <= 7 }
            .flatMap { $0.exercises }))
        
        // Build highlights string
        var highlights: [String] = []
        
        if let daysSince = daysSince {
            if daysSince == 0 {
                highlights.append("You worked out today")
            } else if daysSince == 1 {
                highlights.append("Last workout was yesterday")
            } else {
                highlights.append("Last workout was \(daysSince) days ago")
            }
        }
        
        if let lastDay = lastDay {
            highlights.append("Last workout was \(lastDay)")
        }
        
        if !prs.isEmpty {
            highlights.append("\(prs.count) personal records in the last \(windowDays) days")
        }
        
        if sessions.count > 0 {
            highlights.append("\(sessions.count) workouts in the last \(windowDays) days")
        }
        
        let highlightsText = highlights.joined(separator: ". ") + "."
        
        // Calculate days since last for each workout type
        var daysSinceByType: [String: Int] = [:]
        var lastAchilles: String? = nil
        
        // Get all workout types we care about
        let workoutTypes = ["leg", "push", "pull", "core", "achilles-heavy", "achilles-light", "achilles", "hoop", "bike"]
        let today = Calendar.current.startOfDay(for: Date())
        
        for workoutType in workoutTypes {
            // Find most recent workout of this type
            let matchingWorkouts = workouts.filter { workout in
                guard let day = workout["day"] as? String else { return false }
                let dayLower = day.lowercased()
                let typeLower = workoutType.lowercased()
                
                // For combined "achilles" type, match any achilles workout
                if typeLower == "achilles" {
                    return dayLower.contains("achilles")
                }
                
                return dayLower.contains(typeLower) || typeLower.contains(dayLower)
            }
            
            if let mostRecent = matchingWorkouts
                .compactMap({ $0["date"] as? TimeInterval })
                .map({ Date(timeIntervalSince1970: $0) })
                .max() {
                let daysSince = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: mostRecent), to: today).day ?? 0
                daysSinceByType[workoutType] = daysSince
            }
        }
        
        // Determine last Achilles intensity
        let achillesWorkouts = workouts.filter { workout in
            guard let day = workout["day"] as? String else { return false }
            return day.lowercased().contains("achilles")
        }.sorted { ($0["date"] as? TimeInterval ?? 0) > ($1["date"] as? TimeInterval ?? 0) }
        
        if let lastAchillesWorkout = achillesWorkouts.first,
           let day = lastAchillesWorkout["day"] as? String {
            if day.lowercased().contains("heavy") {
                lastAchilles = "heavy"
            } else if day.lowercased().contains("light") {
                lastAchilles = "light"
            }
        }
        
        return HistorySummary(
            highlights: highlightsText,
            lastSessions: sessions.sorted { $0.date > $1.date },
            personalRecords: prs,
            recentExercises: recentExercises,
            daysSinceLastWorkout: daysSince,
            lastWorkoutDay: lastDay,
            daysSinceByWorkoutType: daysSinceByType,
            lastAchillesIntensity: lastAchilles
        )
    }
    
    func getSummaryJSON(windowDays: Int = 30) async -> String {
        let summary = await getSummary(windowDays: windowDays)
        
        var json: [String: Any] = [
            "highlights": summary.highlights,
            "recentExercises": summary.recentExercises,
            "daysSinceLastWorkout": summary.daysSinceLastWorkout as Any,
            "lastWorkoutDay": summary.lastWorkoutDay as Any,
            "daysSinceByWorkoutType": summary.daysSinceByWorkoutType,
            "lastAchillesIntensity": summary.lastAchillesIntensity as Any
        ]
        
        json["lastSessions"] = summary.lastSessions.map { session in
            [
                "date": ISO8601DateFormatter().string(from: session.date),
                "day": session.day as Any,
                "exercises": session.exercises,
                "totalSets": session.totalSets
            ]
        }
        
        json["personalRecords"] = summary.personalRecords.map { pr in
            [
                "exercise": pr.exercise,
                "weight": pr.weight,
                "reps": pr.reps,
                "date": ISO8601DateFormatter().string(from: pr.date)
            ]
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return "{}"
    }
    
    /// Get rotation recommendation based on what's been longest since last done
    /// - Parameter daysFromNow: 0 for today, 1 for tomorrow, etc.
    func getRotationRecommendation(daysFromNow: Int = 0) async -> String {
        let summary = await getSummary(windowDays: 90)
        let profile = TrainingProfileManager.shared.profile
        
        // For future days, we need to project forward
        // Assume user follows recommendations: today's primary gets done, etc.
        var projectedDaysSince = summary.daysSinceByWorkoutType
        var projectedLastAchillesIntensity = summary.lastAchillesIntensity
        
        // Project each day forward
        for _ in 0..<daysFromNow {
            // Calculate what would be recommended for this intermediate day
            let sortedPrimary = profile.primaryRotationGroups
                .map { ($0, projectedDaysSince[$0] ?? 999) }
                .sorted { $0.1 > $1.1 }
            
            guard let todayPrimary = sortedPrimary.first?.0 else { continue }
            
            // Determine Achilles for this day
            let daysSinceAchilles = projectedDaysSince["achilles"] ?? 999
            let isRestDay = daysSinceAchilles != 1
            
            let achillesIntensity: String
            if isRestDay {
                achillesIntensity = "heavy"
            } else if profile.alternateAchillesIntensity {
                achillesIntensity = projectedLastAchillesIntensity == "heavy" ? "light" : "heavy"
            } else {
                achillesIntensity = "heavy"
            }
            
            // Update projections for next iteration
            // Increment all days by 1, reset the ones done today to 0
            for key in projectedDaysSince.keys {
                projectedDaysSince[key] = (projectedDaysSince[key] ?? 0) + 1
            }
            projectedDaysSince[todayPrimary] = 0
            projectedDaysSince["achilles"] = 0
            projectedDaysSince["achilles-\(achillesIntensity)"] = 0
            projectedLastAchillesIntensity = achillesIntensity
            
            // If it's a light Achilles day with core needed, mark core done too
            let daysSinceCore = projectedDaysSince["core"] ?? 999
            if achillesIntensity == "light" && daysSinceCore >= 2 {
                projectedDaysSince["core"] = 0
            }
        }
        
        // Now calculate the recommendation for the target day
        let sortedPrimary = profile.primaryRotationGroups
            .map { ($0, projectedDaysSince[$0] ?? 999) }
            .sorted { $0.1 > $1.1 }
        
        guard let recommended = sortedPrimary.first else {
            return "No rotation data available"
        }
        
        // Determine Achilles intensity for target day
        let daysSinceAchilles = projectedDaysSince["achilles"] ?? 999
        let isRestDay = daysSinceAchilles != 1
        
        let achillesRecommendation: String
        if profile.dailyAchillesRehab {
            if isRestDay {
                achillesRecommendation = "achilles-heavy"
            } else if profile.alternateAchillesIntensity {
                achillesRecommendation = projectedLastAchillesIntensity == "heavy" ? "achilles-light" : "achilles-heavy"
            } else {
                achillesRecommendation = "achilles-heavy"
            }
        } else {
            achillesRecommendation = ""
        }
        
        // Format result
        let primaryName = recommended.0.capitalized
        let achillesName = achillesRecommendation == "achilles-light" ? "Achilles Light" : "Achilles Heavy"
        
        var result = "\(primaryName) + \(achillesName)"
        
        // Add Core if:
        // - It's a light Achilles day (can't add core with heavy - too much)
        // - Days since core >= 2 (every other day)
        let daysSinceCore = projectedDaysSince["core"] ?? 999
        if achillesRecommendation == "achilles-light" && daysSinceCore >= 2 {
            result += " + Core"
        }
        
        return result
    }
}




