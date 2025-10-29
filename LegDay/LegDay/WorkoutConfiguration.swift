import SwiftUI
import Foundation

struct WorkoutDayConfig: Identifiable, Codable {
    var id: String
    var name: String
    var exercises: [String]  // Exercise names
    var isDefault: Bool  // Can't delete default days
}

class WorkoutConfigManager: ObservableObject {
    @Published var workoutDays: [WorkoutDayConfig] = []
    @Published var allExercises: [String] = []  // Master exercise list
    
    private let workoutDaysKey = "workoutDays"
    private let allExercisesKey = "allExercises"
    
    static let shared = WorkoutConfigManager()
    
    private init() {
        loadData()
        if workoutDays.isEmpty {
            initializeDefaultData()
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
            "Sitting Calf Isometrics"
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
    
    // MARK: - Helper Methods
    
    func getExercisesForDay(dayId: String) -> [String] {
        return getWorkoutDay(id: dayId)?.exercises ?? []
    }
    
    func getDefaultDayId() -> String {
        return workoutDays.first?.id ?? "leg"
    }
    
}
