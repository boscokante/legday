import SwiftUI

struct SetData: Identifiable, Equatable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var warmup: Bool
}

struct ExerciseQuickLogSheet: View {
    let exerciseName: String
    @State private var sets: [SetData] = []
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<sets.count, id: \.self) { index in
                    SetRowView(set: $sets[index], index: index)
                }
                .onDelete(perform: deleteSets)
                
                Button("+ Set") {
                    sets.append(SetData(weight: 0, reps: 10, warmup: false))
                }
                Button("Warmup Preset (10×0)") {
                    sets.append(SetData(weight: 0, reps: 10, warmup: true))
                }
            }
            .navigationTitle(exerciseName)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { 
                        saveWorkout()
                    }
                    .disabled(sets.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Workout Saved!", isPresented: $showingSaveConfirmation) {
                Button("OK") { 
                    dismiss() 
                }
            } message: {
                Text("Your \(exerciseName) workout has been saved with \(sets.count) sets.")
            }
        }
    }
    
    private func saveWorkout() {
        // For now, we'll save to UserDefaults and print to console
        // Later we can integrate with Core Data when the entities are working
        
        let workoutData: [String: Any] = [
            "exerciseName": exerciseName,
            "date": Date().timeIntervalSince1970,
            "sets": sets.map { set in
                [
                    "weight": set.weight,
                    "reps": set.reps,
                    "warmup": set.warmup
                ]
            }
        ]
        
        // Save to UserDefaults for persistence
        var savedWorkouts = UserDefaults.standard.array(forKey: "savedWorkouts") as? [[String: Any]] ?? []
        savedWorkouts.append(workoutData)
        UserDefaults.standard.set(savedWorkouts, forKey: "savedWorkouts")
        
        // Print workout summary
        print("=== WORKOUT SAVED ===")
        print("Exercise: \(exerciseName)")
        print("Date: \(Date())")
        print("Sets:")
        for (index, set) in sets.enumerated() {
            let warmupText = set.warmup ? " (Warmup)" : ""
            print("  Set \(index + 1): \(set.weight) lbs × \(set.reps) reps\(warmupText)")
        }
        print("Total Volume: \(totalVolume()) lbs")
        print("=====================")
        
        showingSaveConfirmation = true
    }
    
    private func totalVolume() -> Double {
        sets.reduce(0) { total, set in
            total + (set.weight * Double(set.reps))
        }
    }
    
    private func deleteSets(offsets: IndexSet) {
        sets.remove(atOffsets: offsets)
    }
}

struct SetRowView: View {
    @Binding var set: SetData
    let index: Int
    
    var body: some View {
        HStack {
            Text("#\(index + 1)")
                .frame(width: 30, alignment: .leading)
            
            TextField("Weight", value: $set.weight, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.decimalPad)
            
            Text("×")
                .foregroundStyle(.secondary)
            
            TextField("Reps", value: $set.reps, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .keyboardType(.numberPad)
            
            if set.warmup { 
                Text("Warmup")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }
}

struct ExerciseQuickLogSheet_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseQuickLogSheet(exerciseName: "Bulgarian Split Squat")
    }
}