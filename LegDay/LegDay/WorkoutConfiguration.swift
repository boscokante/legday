import SwiftUI
import Foundation

struct WorkoutDayConfig: Identifiable, Codable {
    var id: String
    var name: String
    var exercises: [String]  // Exercise names
    var isDefault: Bool  // Can't delete default days
}

// Dual-focus preset for combining two workout types in one session
struct DualFocusPreset: Identifiable, Codable {
    var id: String
    var name: String
    var primaryDayId: String
    var secondaryDayId: String?
}

class WorkoutConfigManager: ObservableObject {
    @Published var workoutDays: [WorkoutDayConfig] = []
    @Published var allExercises: [String] = []  // Master exercise list
    @Published var dualFocusPresets: [DualFocusPreset] = []
    
    private let workoutDaysKey = "workoutDays"
    private let allExercisesKey = "allExercises"
    private let dualFocusPresetsKey = "dualFocusPresets"
    
    static let shared = WorkoutConfigManager()
    
    private init() {
        loadData()
        if workoutDays.isEmpty {
            initializeDefaultData()
        } else {
            migrateDefaultDays()
        }
    }
    
    private func loadData() {
        // Load workout days
        if let data = UserDefaults.standard.data(forKey: workoutDaysKey),
           let decoded = try? JSONDecoder().decode([WorkoutDayConfig].self, from: data) {
            workoutDays = decoded
        }
        
        // Load all exercises
        if let data = UserDefaults.standard.data(forKey: allExercisesKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            allExercises = decoded
        }
        
        // Load dual focus presets
        if let data = UserDefaults.standard.data(forKey: dualFocusPresetsKey),
           let decoded = try? JSONDecoder().decode([DualFocusPreset].self, from: data) {
            dualFocusPresets = decoded
        } else {
            initializeDefaultDualFocusPresets()
        }
    }
    
    private func initializeDefaultDualFocusPresets() {
        dualFocusPresets = [
            DualFocusPreset(id: "legs-achilles-heavy", name: "Legs + Achilles Heavy", primaryDayId: "leg", secondaryDayId: "achilles-heavy"),
            DualFocusPreset(id: "legs-achilles-light", name: "Legs + Achilles Light", primaryDayId: "leg", secondaryDayId: "achilles-light"),
            DualFocusPreset(id: "push-core", name: "Push + Core", primaryDayId: "push", secondaryDayId: "core"),
            DualFocusPreset(id: "push-achilles-heavy", name: "Push + Achilles Heavy", primaryDayId: "push", secondaryDayId: "achilles-heavy"),
            DualFocusPreset(id: "push-achilles-light", name: "Push + Achilles Light", primaryDayId: "push", secondaryDayId: "achilles-light"),
            DualFocusPreset(id: "pull-core", name: "Pull + Core", primaryDayId: "pull", secondaryDayId: "core"),
            DualFocusPreset(id: "pull-achilles-heavy", name: "Pull + Achilles Heavy", primaryDayId: "pull", secondaryDayId: "achilles-heavy"),
            DualFocusPreset(id: "pull-achilles-light", name: "Pull + Achilles Light", primaryDayId: "pull", secondaryDayId: "achilles-light"),
            DualFocusPreset(id: "hoop-achilles-light", name: "Hoop + Achilles Light", primaryDayId: "hoop", secondaryDayId: "achilles-light"),
            DualFocusPreset(id: "legs-core", name: "Legs + Core", primaryDayId: "leg", secondaryDayId: "core"),
        ]
        saveDualFocusPresets()
    }
    
    func saveDualFocusPresets() {
        if let encoded = try? JSONEncoder().encode(dualFocusPresets) {
            UserDefaults.standard.set(encoded, forKey: dualFocusPresetsKey)
        }
    }
    
    func saveData() {
        // Save workout days
        if let encoded = try? JSONEncoder().encode(workoutDays) {
            UserDefaults.standard.set(encoded, forKey: workoutDaysKey)
        }
        
        // Save all exercises
        if let encoded = try? JSONEncoder().encode(allExercises) {
            UserDefaults.standard.set(encoded, forKey: allExercisesKey)
        }
    }
    
    private func initializeDefaultData() {
        // Initialize default exercises
        allExercises = [
            // Leg Day exercises
            "Bulgarian Split Squat",
            "Leg Press",
            "Single-Leg Extension",
            "Hamstring Curl",
            "Standing Calf Raise",
            "Seated Calf Raise",
            "Box Jumps",
            
            // Push Day exercises
            "Bench Press",
            "Incline Bench",
            "Dips",
            
            // Pull Day exercises
            "Single-Arm Row",
            "Single-Arm Dumbbell Row",
            "Pull-Ups",
            "Lat Pulldown",
            "Dumbbell Curls",
            
            // Core Day exercises
            "Watkins Core Program",
            "Cable Crunches",
            "Hanging Knee Raises (Pike)",
            
            // Achilles Rehab exercises
            "Single Leg Heel Raises",
            "Standing Calf Stretch",
            "Band Walks (Ankles)",
            "Single Leg Stance on Foam",
            "Standing Calf Isometrics",
            "Sitting Calf Isometrics",
            
            // Hoop Day exercises
            "Five-on-five games",
            "One-on-one games",
            "10-minute shooting drill score",
            
            // Bike Day exercises
            "Yankee Hill laps",
            "Yankee Hill lap time",
            "Jog minutes"
        ]
        
        // Initialize default workout days
        workoutDays = [
            WorkoutDayConfig(
                id: "leg",
                name: "Leg Day",
                exercises: [
                    "Bulgarian Split Squat",
                    "Leg Press",
                    "Single-Leg Extension",
                    "Hamstring Curl",
                    "Standing Calf Raise",
                    "Seated Calf Raise",
                    "Box Jumps"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "push",
                name: "Push Day",
                exercises: [
                    "Bench Press",
                    "Incline Bench",
                    "Dips"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "pull",
                name: "Pull Day",
                exercises: [
                    "Single-Arm Row",
                    "Single-Arm Dumbbell Row",
                    "Pull-Ups",
                    "Lat Pulldown",
                    "Dumbbell Curls"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "core",
                name: "Core Day",
                exercises: [
                    "Watkins Core Program",
                    "Cable Crunches",
                    "Hanging Knee Raises (Pike)"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "achilles-heavy",
                name: "Achilles Rehab Heavy",
                exercises: [
                    "Single Leg Heel Raises",
                    "Standing Calf Stretch",
                    "Band Walks (Ankles)",
                    "Single Leg Stance on Foam"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "achilles-light",
                name: "Achilles Rehab Light",
                exercises: [
                    "Standing Calf Isometrics",
                    "Sitting Calf Isometrics"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "hoop",
                name: "Hoop Day",
                exercises: [
                    "Five-on-five games",
                    "One-on-one games",
                    "10-minute shooting drill score"
                ],
                isDefault: true
            ),
            WorkoutDayConfig(
                id: "bike",
                name: "Bike Day",
                exercises: [
                    "Yankee Hill laps",
                    "Yankee Hill lap time",
                    "Jog minutes"
                ],
                isDefault: true
            )
        ]
        
        saveData()
    }
    
    // MARK: - Workout Day Management
    
    func addWorkoutDay(name: String, exercises: [String]) {
        let newDay = WorkoutDayConfig(
            id: UUID().uuidString,
            name: name,
            exercises: exercises,
            isDefault: false
        )
        objectWillChange.send()
        workoutDays.append(newDay)
        saveData()
    }
    
    func updateWorkoutDay(id: String, name: String, exercises: [String]) {
        if let index = workoutDays.firstIndex(where: { $0.id == id }) {
            objectWillChange.send()
            workoutDays[index].name = name
            workoutDays[index].exercises = exercises
            saveData()
        }
    }
    
    func deleteWorkoutDay(id: String) {
        if let index = workoutDays.firstIndex(where: { $0.id == id }) {
            // Don't allow deletion of default days
            if !workoutDays[index].isDefault {
                objectWillChange.send()
                workoutDays.remove(at: index)
                saveData()
            }
        }
    }
    
    func getWorkoutDay(id: String) -> WorkoutDayConfig? {
        return workoutDays.first { $0.id == id }
    }
    
    // MARK: - Exercise Management
    
    func addExercise(name: String) {
        if !allExercises.contains(name) {
            objectWillChange.send()
            allExercises.append(name)
            allExercises.sort()
            saveData()
        }
    }
    
    func deleteExercise(name: String) {
        objectWillChange.send()
        allExercises.removeAll { $0 == name }
        // Remove from all workout days
        for i in 0..<workoutDays.count {
            workoutDays[i].exercises.removeAll { $0 == name }
        }
        saveData()
    }
    
    func updateExercise(oldName: String, newName: String) {
        if let index = allExercises.firstIndex(of: oldName) {
            objectWillChange.send()
            allExercises[index] = newName
            allExercises.sort()
            
            // Update in all workout days
            for i in 0..<workoutDays.count {
                if let exerciseIndex = workoutDays[i].exercises.firstIndex(of: oldName) {
                    workoutDays[i].exercises[exerciseIndex] = newName
                }
            }
            saveData()
        }
    }
    
    // MARK: - Restore Defaults
    private func defaultExercisesMap() -> [String: [String]] {
        return [
            "Leg Day": [
                "Bulgarian Split Squat",
                "Leg Press",
                "Single-Leg Extension",
                "Hamstring Curl",
                "Standing Calf Raise",
                "Seated Calf Raise",
                "Box Jumps"
            ],
            "Push Day": [
                "Bench Press",
                "Incline Bench",
                "Dips"
            ],
            "Pull Day": [
                "Single-Arm Row",
                "Single-Arm Dumbbell Row",
                "Pull-Ups",
                "Lat Pulldown",
                "Dumbbell Curls"
            ],
            "Core Day": [
                "Watkins Core Program",
                "Cable Crunches",
                "Hanging Knee Raises (Pike)"
            ],
            "Achilles Rehab Heavy": [
                "Single Leg Heel Raises",
                "Standing Calf Stretch",
                "Band Walks (Ankles)",
                "Single Leg Stance on Foam"
            ],
            "Achilles Rehab Light": [
                "Standing Calf Isometrics",
                "Sitting Calf Isometrics"
            ],
            "Hoop Day": [
                "Five-on-five games",
                "One-on-one games",
                "10-minute shooting drill score"
            ],
            "Bike Day": [
                "Yankee Hill laps",
                "Yankee Hill lap time",
                "Jog minutes"
            ]
        ]
    }

    @discardableResult
    func restoreDefaultExercises(forDayId dayId: String) -> Bool {
        guard let index = workoutDays.firstIndex(where: { $0.id == dayId }) else { return false }
        let day = workoutDays[index]
        guard day.isDefault, let defaults = defaultExercisesMap()[day.name] else { return false }
        objectWillChange.send()
        workoutDays[index].exercises = defaults
        for ex in defaults { if !allExercises.contains(ex) { allExercises.append(ex) } }
        allExercises.sort()
        saveData()
        return true
    }

    func restoreAllDefaultExercises() {
        objectWillChange.send()
        let map = defaultExercisesMap()
        for i in 0..<workoutDays.count {
            let day = workoutDays[i]
            if day.isDefault, let defaults = map[day.name] {
                workoutDays[i].exercises = defaults
            }
        }
        var set = Set(allExercises)
        for exs in map.values { for ex in exs { set.insert(ex) } }
        allExercises = Array(set).sorted()
        saveData()
    }
    
    // MARK: - Migration
    
    private func migrateDefaultDays() {
        let defaultDaysMap: [String: (id: String, exercises: [String])] = [
            "Leg Day": ("leg", [
                "Bulgarian Split Squat",
                "Leg Press",
                "Single-Leg Extension",
                "Hamstring Curl",
                "Standing Calf Raise",
                "Seated Calf Raise",
                "Box Jumps"
            ]),
            "Push Day": ("push", [
                "Bench Press",
                "Incline Bench",
                "Dips"
            ]),
            "Pull Day": ("pull", [
                "Single-Arm Row",
                "Single-Arm Dumbbell Row",
                "Pull-Ups",
                "Lat Pulldown",
                "Dumbbell Curls"
            ]),
            "Core Day": ("core", [
                "Watkins Core Program",
                "Cable Crunches",
                "Hanging Knee Raises (Pike)"
            ]),
            "Achilles Rehab Heavy": ("achilles-heavy", [
                "Single Leg Heel Raises",
                "Standing Calf Stretch",
                "Band Walks (Ankles)",
                "Single Leg Stance on Foam"
            ]),
            "Achilles Rehab Light": ("achilles-light", [
                "Standing Calf Isometrics",
                "Sitting Calf Isometrics"
            ]),
            "Hoop Day": ("hoop", [
                "Five-on-five games",
                "One-on-one games",
                "10-minute shooting drill score"
            ]),
            "Bike Day": ("bike", [
                "Yankee Hill laps",
                "Yankee Hill lap time",
                "Jog minutes"
            ])
        ]
        
        var needsSave = false
        
        // Add missing default days
        for (name, config) in defaultDaysMap {
            let exists = workoutDays.contains { $0.name == name }
            if !exists {
                let newDay = WorkoutDayConfig(
                    id: config.id,
                    name: name,
                    exercises: config.exercises,
                    isDefault: true
                )
                workoutDays.append(newDay)
                needsSave = true
            }
        }
        
        // Ensure all default exercises are in the master list
        let allDefaultExercises = defaultDaysMap.values.flatMap { $0.exercises }
        for exercise in allDefaultExercises {
            if !allExercises.contains(exercise) {
                allExercises.append(exercise)
                needsSave = true
            }
        }
        
        if needsSave {
            objectWillChange.send()
            allExercises.sort()
            saveData()
        }
    }
    
    // MARK: - Helper Methods
    
    func getExercisesForDay(dayId: String) -> [String] {
        return getWorkoutDay(id: dayId)?.exercises ?? []
    }
    
    func getExercisesForDualFocus(primaryDayId: String, secondaryDayId: String?) -> [String] {
        var exercises = getExercisesForDay(dayId: primaryDayId)
        if let secondaryId = secondaryDayId {
            exercises += getExercisesForDay(dayId: secondaryId)
        }
        return exercises
    }
    
    func getDefaultDayId() -> String {
        return workoutDays.first?.id ?? "leg"
    }
    
}
