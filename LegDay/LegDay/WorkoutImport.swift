import Foundation

enum WorkoutGroup: String {
    case leg = "Leg Day"
    case push = "Push Day"
    case pull = "Pull Day"
    case core = "Core Day"
}

struct WorkoutImporter {
    // Public entry point: parses markdown and appends normalized sessions to savedWorkouts
    static func importFromMarkdown(_ content: String) {
        let sessions = parseMarkdown(content)
        guard !sessions.isEmpty else { return }

        var saved = UserDefaults.standard.array(forKey: "savedWorkouts") as? [[String: Any]] ?? []

        for session in sessions {
            // De-dup per day
            if let ts = session["date"] as? TimeInterval {
                let date = Date(timeIntervalSince1970: ts)
                saved.removeAll { existing in
                    if let ets = existing["date"] as? TimeInterval {
                        return Calendar.current.isDate(Date(timeIntervalSince1970: ets), inSameDayAs: date)
                    }
                    return false
                }
            }
            saved.append(session)
        }

        // Sort ascending by date
        saved.sort { lhs, rhs in
            let l = lhs["date"] as? TimeInterval ?? 0
            let r = rhs["date"] as? TimeInterval ?? 0
            return l < r
        }

        UserDefaults.standard.set(saved, forKey: "savedWorkouts")
    }

    // MARK: - Parsing
    private static func parseMarkdown(_ md: String) -> [[String: Any]] {
        var sessions: [[String: Any]] = []

        let lines = md.components(separatedBy: .newlines)

        var currentDate: Date? = nil
        var currentExercises: [String: [[String: Any]]] = [:]
        var notes: [String] = []
        var groupSet = Set<WorkoutGroup>()

        func flushSession() {
            guard let date = currentDate, !currentExercises.isEmpty || !notes.isEmpty else { return }
            var payload: [String: Any] = [:]
            payload["date"] = date.timeIntervalSince1970
            payload["exercises"] = currentExercises
            if !notes.isEmpty { payload["notes"] = notes.joined(separator: "\n") }
            if !groupSet.isEmpty { payload["day"] = Array(groupSet).map { $0.rawValue }.joined(separator: ", ") }
            sessions.append(payload)
            currentExercises = [:]
            notes.removeAll()
            groupSet.removeAll()
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if let d = parseDate(line) {
                // New date encountered -> flush previous
                flushSession()
                currentDate = d
                continue
            }

            // Exercise headers (case-insensitive contains)
            if isHeader(line) { continue }

            // Try to infer exercise name from line context
            if let (name, sets) = parseExerciseLine(line) {
                currentExercises[name, default: []] += sets
                inferGroup(for: name, groups: &groupSet)
                continue
            }

            // Otherwise treat as notes
            notes.append(line)
        }

        flushSession()
        return sessions
    }

    private static func parseDate(_ line: String) -> Date? {
        // Accept multiple formats
        let fmts = [
            "M/d/yyyy, EEEE",
            "M/d/yyyy",
            "MMM d, yyyy",
            "MMM d yyyy",
            "MMM d", // assume current year
            "MMMM d, yyyy",
            "yyyy-MM-dd"
        ]
        for f in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: line) { return d }
        }

        // Inline date inside text: e.g. "Oct 6 - ..." or "Sept 25 ..."
        let monthRegex = try? NSRegularExpression(pattern: "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\\s+\\d{1,2}")
        if let m = monthRegex?.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)),
           let r = Range(m.range, in: line) {
            let token = String(line[r]).replacingOccurrences(of: "Sept", with: "Sep")
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "MMM d"
            if let base = df.date(from: token) {
                // Assume current year
                let year = Calendar.current.component(.year, from: Date())
                return Calendar.current.date(bySetting: .year, value: year, of: base)
            }
        }
        return nil
    }

    private static func isHeader(_ line: String) -> Bool {
        let upper = line.uppercased()
        let headers = ["CHEST", "BENCH", "INCLINE", "CORE", "DIPS", "PULL", "LEGS", "LEG", "BACK"]
        return headers.contains { upper.contains($0) }
    }

    private static func parseExerciseLine(_ line: String) -> (String, [[String: Any]])? {
        // Identify exercise name by keywords and then extract sets
        let lower = line.lowercased()
        var name: String? = nil
        if lower.contains("bench") && !lower.contains("incline") { name = "Bench Press" }
        if lower.contains("incline bench") || (lower.contains("incline") && lower.contains("bench")) { name = "Incline Bench" }
        if lower.contains("dip") { name = "Dips" }
        if lower.contains("pull up") || lower.contains("pull-up") || lower.contains("pullups") { name = "Pull-Ups" }
        if lower.contains("lat pull") { name = "Lat Pulldown" }
        if lower.contains("curl") { name = "Dumbbell Curls" }
        if lower.contains("row") { name = "Single-Arm Row" }
        if lower.contains("bulgarian") { name = "Bulgarian Split Squat" }
        if lower.contains("leg press") { name = "Leg Press" }
        if lower.contains("extension") { name = "Single-Leg Extension" }
        if lower.contains("hamstring curl") { name = "Hamstring Curl" }
        if lower.contains("standing calf") { name = "Standing Calf Raise" }
        if lower.contains("seated calf") { name = "Seated Calf Raise" }
        if lower.contains("elliptical") || lower.contains("jog") || lower.contains("jump rope") { name = name ?? "Cardio" }
        if lower.contains("cable crunch") { name = "Cable Crunches" }
        if lower.contains("hanging") && (lower.contains("knee") || lower.contains("leg")) { name = "Hanging Knee Raises (Pike)" }
        
        let sets = extractSets(from: line)
        guard !sets.isEmpty else { return nil }
        return (name ?? "Unknown", sets)
    }

    private static func extractSets(from line: String) -> [[String: Any]] {
        // Find tokens like 10x115 or 3.5 x 205
        let pattern = "(\n|^|\t|\s)(\n|\t|\s)*([0-9]+(?:\\.[0-9]+)?)\\s*x\\s*([0-9]+(?:\\.[0-9]+)?)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let nsrange = NSRange(line.startIndex..<line.endIndex, in: line)
        var results: [[String: Any]] = []
        regex.enumerateMatches(in: line, options: [], range: nsrange) { match, _, _ in
            guard let match = match,
                  let repsRange = Range(match.range(at: 3), in: line),
                  let weightRange = Range(match.range(at: 4), in: line) else { return }
            let repsStr = String(line[repsRange])
            let weightStr = String(line[weightRange])
            let reps = Int(Double(repsStr) ?? 0)
            let weight = Double(weightStr) ?? 0
            results.append([
                "weight": weight,
                "reps": reps,
                "warmup": weight == 0
            ])
        }
        return results
    }

    private static func inferGroup(for exercise: String, groups: inout Set<WorkoutGroup>) {
        let name = exercise.lowercased()
        if name.contains("bench") || name.contains("dip") { groups.insert(.push) }
        if name.contains("row") || name.contains("pull") || name.contains("curl") { groups.insert(.pull) }
        if name.contains("bulgar") || name.contains("leg press") || name.contains("calf") || name.contains("hamstring") { groups.insert(.leg) }
        if name.contains("core") || name.contains("crunch") || name.contains("hanging") { groups.insert(.core) }
    }
}


