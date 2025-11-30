import Foundation

struct WeightRecommendation {
    let weight: Double
    let rationale: String
}

class WeightRecommendationService {
    func recommendWeight(exercise: String, targetReps: Int, rpe: Double? = nil) async -> WeightRecommendation {
        let workouts = HistoryCodec.loadSavedWorkouts()
        
        // Find last 3 sessions with this exercise
        var recentSets: [(weight: Double, reps: Int, date: Date)] = []
        
        for workout in workouts.sorted(by: { ($0["date"] as? TimeInterval ?? 0) > ($1["date"] as? TimeInterval ?? 0) }) {
            guard let timestamp = workout["date"] as? TimeInterval,
                  let exercises = workout["exercises"] as? [String: [[String: Any]]],
                  let sets = exercises[exercise] else { continue }
            
            let date = Date(timeIntervalSince1970: timestamp)
            
            for set in sets {
                guard let weight = set["weight"] as? Double,
                      let reps = set["reps"] as? Int,
                      weight > 0, reps > 0,
                      !(set["warmup"] as? Bool ?? false) else { continue }
                
                recentSets.append((weight, reps, date))
            }
            
            if recentSets.count >= 3 {
                break
            }
        }
        
        guard !recentSets.isEmpty else {
            // No history - suggest a conservative starting weight
            return WeightRecommendation(
                weight: 0,
                rationale: "No previous history for \(exercise). Start with a weight you can comfortably do \(targetReps) reps with."
            )
        }
        
        // Calculate trend
        let mostRecent = recentSets.first!
        _ = recentSets.map { $0.weight }.reduce(0, +) / Double(recentSets.count)
        _ = Double(recentSets.map { $0.reps }.reduce(0, +)) / Double(recentSets.count)
        
        // Calculate 1RM from most recent set
        let estimated1RM = LiftingMath.epley1RM(weight: mostRecent.weight, reps: mostRecent.reps)
        
        // Calculate target weight for desired reps (reverse Epley)
        // 1RM = weight * (1 + reps/30)
        // weight = 1RM / (1 + reps/30)
        let targetWeight = estimated1RM / (1.0 + Double(targetReps) / 30.0)
        
        // Adjust for RPE if provided (higher RPE = can do more weight)
        var adjustedWeight = targetWeight
        if let rpe = rpe {
            // RPE 10 = max effort, RPE 8 = 2 reps in reserve
            // Rough adjustment: RPE 10 = +5%, RPE 8 = -5%
            let rpeAdjustment = (rpe - 8.0) * 0.025 // 2.5% per RPE point above 8
            adjustedWeight = targetWeight * (1.0 + rpeAdjustment)
        }
        
        // Round to nearest 5 lbs
        let roundedWeight = round(adjustedWeight / 5.0) * 5.0
        
        // Build rationale
        var rationale = "Based on your last \(recentSets.count) session"
        if recentSets.count > 1 {
            rationale += "s"
        }
        rationale += " with \(exercise), "
        
        if mostRecent.reps == targetReps {
            rationale += "you did \(String(format: "%.0f", mostRecent.weight)) lbs for \(targetReps) reps last time. "
        } else {
            rationale += "your estimated 1RM is \(String(format: "%.0f", estimated1RM)) lbs. "
        }
        
        rationale += "For \(targetReps) reps, I recommend \(String(format: "%.0f", roundedWeight)) lbs."
        
        if let rpe = rpe {
            rationale += " (Adjusted for RPE \(String(format: "%.1f", rpe)))"
        }
        
        return WeightRecommendation(
            weight: roundedWeight,
            rationale: rationale
        )
    }
}

