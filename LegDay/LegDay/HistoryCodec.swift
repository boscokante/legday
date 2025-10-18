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
    
    static func exportToData() throws -> Data {
        let saved = UserDefaults.standard.array(forKey: "savedWorkouts") as? [[String: Any]] ?? []
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
        var saved = UserDefaults.standard.array(forKey: "savedWorkouts") as? [[String: Any]] ?? []
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
        UserDefaults.standard.set(saved, forKey: "savedWorkouts")
    }
}


