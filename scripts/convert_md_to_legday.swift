#!/usr/bin/env swift
import Foundation

struct SetEntry: Codable { let weight: Double; let reps: Int; let warmup: Bool }
struct Workout: Codable { let date: TimeInterval; var day: String?; var notes: String?; var exercises: [String:[SetEntry]] }
struct LegDayHistory: Codable { let version: Int; let exportedAt: TimeInterval; let workouts: [Workout] }

// MARK: - Parse helpers copied/simplified from in-app importer
// Returns detected date and the remainder of the line after the date token (if inline)
func parseDateAndRemainder(_ line: String) -> (Date, String)? {
    let fmts = ["M/d/yyyy, EEEE","M/d/yyyy","MMM d, yyyy","MMM d yyyy","MMM d","MMMM d, yyyy","yyyy-MM-dd"]
    for f in fmts {
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = f
        if let d = df.date(from: line) { return (d, "") }
    }
    // inline like "Oct 6 ..." or "Sept 25 ..."
    // Month + optional space + day + optional ordinal suffix
    let pattern = "(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)[a-z]*\\s*\\d{1,2}(?:st|nd|rd|th)?"
    if let rx = try? NSRegularExpression(pattern: pattern), let m = rx.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)), let r = Range(m.range, in: line) {
        var token = String(line[r]).replacingOccurrences(of: "Sept", with: "Sep")
        token = token.replacingOccurrences(of: "st", with: "").replacingOccurrences(of: "nd", with: "").replacingOccurrences(of: "rd", with: "").replacingOccurrences(of: "th", with: "")
        let df = DateFormatter(); df.locale = Locale(identifier: "en_US_POSIX"); df.dateFormat = "MMM d"
        if let base = df.date(from: token) {
            let y = Calendar.current.component(.year, from: Date())
            let d = Calendar.current.date(bySetting: .year, value: y, of: base)!
            // Remainder is everything after the token
            let after = String(line[r.upperBound...]).trimmingCharacters(in: CharacterSet(charactersIn: "-–—:,. "))
            return (d, after)
        }
    }
    // Numeric dotted format like "8.13 ..."
    // Numeric formats like 8.13 or 8/13/2025
    let dotPattern = "\\b(\\d{1,2})[\\./](\\d{1,2})(?:[\\./](\\d{2,4}))?\\b"
    if let rx = try? NSRegularExpression(pattern: dotPattern), let m = rx.firstMatch(in: line, range: NSRange(location: 0, length: line.utf16.count)) {
        func rng(_ i: Int) -> Range<String.Index>? { guard let r = Range(m.range(at: i), in: line) else { return nil }; return r }
        if let mr = rng(1), let dr = rng(2) {
            let month = Int(line[mr]) ?? 1
            let day = Int(line[dr]) ?? 1
            var comps = DateComponents(); comps.year = (Int((rng(3).map { String(line[$0]) } ?? "")) ?? Calendar.current.component(.year, from: Date())); comps.month = month; comps.day = day
            let cal = Calendar.current
            if let d = cal.date(from: comps) {
                let afterIdx = rng(0)!.upperBound
                let after = String(line[afterIdx...]).trimmingCharacters(in: CharacterSet(charactersIn: "-–—:,. "))
                return (d, after)
            }
        }
    }
    return nil
}

func extractSets(_ line: String) -> [[String:Any]] {
    // tokens like 10x115 or 3.5 x 205
    let pattern = "(?:(?:^)|(?:\\t)|(?:\\s))([0-9]+(?:\\.[0-9]+)?)\\s*x\\s*([0-9]+(?:\\.[0-9]+)?)"
    guard let rx = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
    let ns = NSRange(line.startIndex..<line.endIndex, in: line)
    var out: [[String:Any]] = []
    rx.enumerateMatches(in: line, range: ns) { m, _, _ in
        guard let m = m, let r1 = Range(m.range(at: 1), in: line), let r2 = Range(m.range(at: 2), in: line) else { return }
        let reps = Int(Double(String(line[r1])) ?? 0)
        let weight = Double(String(line[r2])) ?? 0
        out.append(["weight": weight, "reps": reps, "warmup": weight == 0])
    }
    return out
}

func inferGroup(for name: String, into set: inout Set<String>) {
    let n = name.lowercased()
    if n.contains("bench") || n.contains("dip") { set.insert("Push Day") }
    if n.contains("row") || n.contains("pull") || n.contains("curl") { set.insert("Pull Day") }
    if n.contains("bulgar") || n.contains("leg press") || n.contains("calf") || n.contains("hamstring") { set.insert("Leg Day") }
    if n.contains("core") || n.contains("crunch") || n.contains("hanging") { set.insert("Core Day") }
}

func parseMarkdown(_ text: String) -> [Workout] {
    let lines = text.components(separatedBy: .newlines)
    var currentDate: Date? = nil
    var currentExercises: [String:[[String:Any]]] = [:]
    var notes: [String] = []
    var groups = Set<String>()
    var currentExerciseName: String? = nil
    var byDate: [TimeInterval: Workout] = [:]
    var currentGroupLabel: String? = nil

    func flush() {
        guard let d = currentDate, (!currentExercises.isEmpty || !notes.isEmpty) else { return }
        let ts = d.timeIntervalSince1970
        var target = byDate[ts] ?? Workout(date: ts, day: nil, notes: nil, exercises: [:])
        // Merge exercises
        for (k, v) in currentExercises {
            var existing = target.exercises[k] ?? []
            for e in v {
                if let w = e["weight"] as? Double, let r = e["reps"] as? Int, let warm = e["warmup"] as? Bool {
                    existing.append(SetEntry(weight: w, reps: r, warmup: warm))
                }
            }
            target.exercises[k] = existing
        }
        // Merge notes
        if !notes.isEmpty {
            let block = notes.joined(separator: "\n")
            target.notes = [target.notes, block].compactMap { $0 }.joined(separator: target.notes == nil ? "" : "\n")
        }
        // Merge day labels
        if !groups.isEmpty {
            let existing = Set((target.day ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }).filter { !$0.isEmpty }
            let merged = existing.union(groups)
            target.day = merged.sorted().joined(separator: ", ")
        }
        byDate[ts] = target
        currentExercises = [:]; notes.removeAll(); groups.removeAll()
    }

    for raw in lines {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        // High-level day headers
        let lowerHeader = line.lowercased()
        if lowerHeader.starts(with: "leg day") { currentGroupLabel = "Leg Day"; continue }
        if lowerHeader.starts(with: "pull day") { currentGroupLabel = "Pull Day"; continue }
        if lowerHeader.starts(with: "push day") { currentGroupLabel = "Push Day"; continue }
        if lowerHeader.starts(with: "core") { currentGroupLabel = "Core Day"; continue }
        
        // Explicit exercise section headers set the current exercise context
        if lowerHeader.contains("bulgarian split") { currentExerciseName = "Bulgarian Split Squat"; continue }
        if lowerHeader == "leg press" || lowerHeader.contains("leg press") { currentExerciseName = "Leg Press"; continue }
        if lowerHeader.contains("seated calf") { currentExerciseName = "Seated Calf Raise"; continue }
        if lowerHeader == "calf raises" || lowerHeader.contains("calf raises") { currentExerciseName = "Standing Calf Raise"; continue }
        if lowerHeader.contains("leg curl") { currentExerciseName = "Hamstring Curl"; continue }
        if lowerHeader.contains("leg extension") { currentExerciseName = "Single-Leg Extension"; continue }
        if lowerHeader.contains("rdl barbell") { currentExerciseName = "RDL (Barbell)"; continue }
        if lowerHeader.contains("rdl dumbbell") { currentExerciseName = "RDL (Dumbbells)"; continue }

        if let (d, remainder) = parseDateAndRemainder(line) { flush(); currentDate = d; if !remainder.isEmpty { // also parse sets on same line
                let lower = remainder.lowercased()
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
                let sets = extractSets(remainder)
                if !sets.isEmpty {
                    let exName = name ?? currentExerciseName ?? "Unknown"
                    currentExercises[exName, default: []] += sets
                    inferGroup(for: exName, into: &groups)
                    if let g = currentGroupLabel { groups.insert(g) }
                } else {
                    notes.append(remainder)
                }
            }
            continue }
        // Identify exercise name keywords quickly
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

        let sets = extractSets(line)
        if !sets.isEmpty {
            let exName = name ?? currentExerciseName ?? "Unknown"
            currentExercises[exName, default: []] += sets
            inferGroup(for: exName, into: &groups)
            if let g = currentGroupLabel { groups.insert(g) }
            continue
        }
        notes.append(line)
    }
    flush()
    return byDate.values.sorted { $0.date < $1.date }
}

// MARK: - CLI
let cwd = FileManager.default.currentDirectoryPath
let src = CommandLine.arguments.dropFirst().first ?? cwd + "/LegDay/LegDay/boskoworkoutlog.md"
let dst = CommandLine.arguments.dropFirst(2).first ?? cwd + "/art/boskoworkoutlog.legday"

guard let content = try? String(contentsOfFile: src, encoding: .utf8) else {
    fputs("Could not read source markdown: \(src)\n", stderr)
    exit(1)
}

let workouts = parseMarkdown(content)
let payload = LegDayHistory(version: 1, exportedAt: Date().timeIntervalSince1970, workouts: workouts)
let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
let data = try enc.encode(payload)

try? FileManager.default.createDirectory(atPath: (dst as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
try data.write(to: URL(fileURLWithPath: dst))
print("✅ Exported \(workouts.count) workouts to \(dst)")


