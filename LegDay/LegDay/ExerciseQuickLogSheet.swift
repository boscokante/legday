import SwiftUI

struct SetData: Identifiable, Equatable, Codable {
    let id = UUID()
    var weight: Double
    var reps: Int
    var warmup: Bool
    var completed: Bool = false  // Only save sets marked as completed
}

struct ExerciseSessionSheet: View {
    let exerciseName: String
    @ObservedObject var dailyWorkout: DailyWorkoutSession
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var timerManager = TimerManager.shared
    
    @State private var appearedOnce = false
    @FocusState private var focusedField: Bool
    
    var sets: [SetData] {
        dailyWorkout.getSets(for: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                // Rest Timer Section
                Section("Rest Timers") {
                    HStack(spacing: 12) {
                        // 2 Minute Timer
                        VStack {
                            Button(action: {
                                if timerManager.timer2min.isActive {
                                    timerManager.timer2min.stop()
                                } else {
                                    timerManager.timer2min.start()
                                }
                            }) {
                                VStack {
                                    Text("2 MIN")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(timerManager.timer2min.formattedTime)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(timerManager.timer2min.isActive ? .white : .blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(timerManager.timer2min.isActive ? .blue : .blue.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.blue, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if timerManager.timer2min.isActive {
                                ProgressView(value: timerManager.timer2min.progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                    .frame(height: 4)
                            }
                        }
                        
                        // 45 Second Timer
                        VStack {
                            Button(action: {
                                if timerManager.timer45sec.isActive {
                                    timerManager.timer45sec.stop()
                                } else {
                                    timerManager.timer45sec.start()
                                }
                            }) {
                                VStack {
                                    Text("45 SEC")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(timerManager.timer45sec.formattedTime)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(timerManager.timer45sec.isActive ? .white : .orange)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(timerManager.timer45sec.isActive ? .orange : .orange.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.orange, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if timerManager.timer45sec.isActive {
                                ProgressView(value: timerManager.timer45sec.progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                    .frame(height: 4)
                            }
                        }

                        // 30 Second Timer
                        VStack {
                            Button(action: {
                                if timerManager.timer30sec.isActive {
                                    timerManager.timer30sec.stop()
                                } else {
                                    timerManager.timer30sec.start()
                                }
                            }) {
                                VStack {
                                    Text("30 SEC")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(timerManager.timer30sec.formattedTime)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(timerManager.timer30sec.isActive ? .white : .purple)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(timerManager.timer30sec.isActive ? .purple : .purple.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(.purple, lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            if timerManager.timer30sec.isActive {
                                ProgressView(value: timerManager.timer30sec.progress)
                                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                                    .frame(height: 4)
                            }
                        }
                    }
                }
                
                Section("Sets") {
                    ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                        EditableSetRowView(
                            exerciseName: exerciseName,
                            setIndex: index,
                            dailyWorkout: dailyWorkout,
                            focusedField: $focusedField
                        )
                    }
                    .onDelete(perform: deleteSets)
                    
                    Button("+ Set") {
                        let newSet = SetData(weight: 0, reps: 10, warmup: false)
                        dailyWorkout.addSet(to: exerciseName, set: newSet)
                    }
                    
                    Button("Warmup Preset (10×0)") {
                        let warmupSet = SetData(weight: 0, reps: 10, warmup: true)
                        dailyWorkout.addSet(to: exerciseName, set: warmupSet)
                    }
                }
                
                Section("Today's Progress") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sets for \(exerciseName):")
                                .font(.headline)
                            Spacer()
                            let completedCount = sets.filter { $0.completed }.count
                            Text("\(completedCount)/\(sets.count) completed")
                                .foregroundStyle(completedCount > 0 ? .green : .secondary)
                        }
                        
                        if !sets.isEmpty {
                            ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                                HStack {
                                    Image(systemName: set.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(set.completed ? .green : .gray)
                                        .font(.caption)
                                    
                                    Text("Set \(index + 1):")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    if set.weight > 0 && set.reps > 0 {
                                        Text("\(set.weight, specifier: "%.0f") lbs × \(set.reps) reps")
                                            .font(.subheadline)
                                    } else {
                                        Text("Not set")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                    
                                    if set.warmup {
                                        Text("(W)")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                    
                                    Spacer()
                                    
                                    if set.completed && set.weight > 0 && set.reps > 0 {
                                        let setVolume = set.weight * Double(set.reps)
                                        Text("\(setVolume, specifier: "%.0f") vol")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                            
                            Divider()
                            
                            let completedSets = sets.filter { $0.completed }
                            let totalVolume = completedSets.reduce(0.0) { total, set in
                                total + (set.weight * Double(set.reps))
                            }
                            
                            HStack {
                                Text("Total Volume:")
                                    .font(.headline)
                                Spacer()
                                Text("\(totalVolume, specifier: "%.0f") lbs")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                            .padding(.top, 4)
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("All exercises today:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            let totalCompleted = dailyWorkout.exercises.values.flatMap { $0 }.filter { $0.completed }.count
                            let totalSets = dailyWorkout.getTotalSets()
                            Text("\(totalCompleted)/\(totalSets) completed")
                                .font(.subheadline)
                                .foregroundStyle(totalCompleted > 0 ? .green : .secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(exerciseName)
            .toolbar {
                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Dismiss Keyboard") {
                            focusedField = false
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            // Pre-warm sets on first appear to avoid any lazy load hiccups
            if !appearedOnce {
                _ = dailyWorkout.getSets(for: exerciseName)
                appearedOnce = true
            }
        }
    }
    
    private func deleteSets(offsets: IndexSet) {
        for index in offsets {
            dailyWorkout.removeSet(from: exerciseName, at: index)
        }
    }
}

struct EditableSetRowView: View {
    let exerciseName: String
    let setIndex: Int
    @ObservedObject var dailyWorkout: DailyWorkoutSession
    @FocusState.Binding var focusedField: Bool
    
    @State private var weight: Double = 0
    @State private var reps: Int = 10
    @State private var isWarmup: Bool = false
    @State private var isCompleted: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Completion checkbox
            Button(action: {
                isCompleted.toggle()
                updateSet()
            }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            Text("#\(setIndex + 1)")
                .frame(width: 30, alignment: .leading)
                .font(.body.weight(.medium))
                .opacity(isCompleted ? 1.0 : 0.5)
            
            // Weight field with label
            HStack(spacing: 4) {
                TextField("0", value: $weight, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .foregroundStyle(.blue)
                    .font(.body.weight(.semibold))
                    .keyboardType(.decimalPad)
                    .focused($focusedField)
                    .onChange(of: weight) { _, newValue in
                        updateSet()
                    }
                    .opacity(isCompleted ? 1.0 : 0.5)
                Text("lbs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)
                    .opacity(isCompleted ? 1.0 : 0.5)
            }
            
            Text("×")
                .foregroundStyle(.secondary)
                .font(.title3)
                .opacity(isCompleted ? 1.0 : 0.5)
            
            // Reps field with label
            HStack(spacing: 4) {
                TextField("0", value: $reps, format: .number)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .focused($focusedField)
                    .onChange(of: reps) { _, newValue in
                        updateSet()
                    }
                    .frame(width: 50)
                    .opacity(isCompleted ? 1.0 : 0.5)
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, alignment: .leading)
                    .opacity(isCompleted ? 1.0 : 0.5)
            }
            
            if isWarmup { 
                Text("W")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .fontWeight(.bold)
                    .opacity(isCompleted ? 1.0 : 0.5)
            }
        }
        .onAppear {
            loadCurrentValues()
        }
    }
    
    private func loadCurrentValues() {
        let sets = dailyWorkout.getSets(for: exerciseName)
        if setIndex < sets.count {
            let set = sets[setIndex]
            weight = set.weight
            reps = set.reps
            isWarmup = set.warmup
            isCompleted = set.completed
        }
    }
    
    private func updateSet() {
        dailyWorkout.updateSet(
            exercise: exerciseName,
            index: setIndex,
            weight: weight,
            reps: reps,
            warmup: isWarmup,
            completed: isCompleted
        )
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
            
            Text("×")
                .foregroundStyle(.secondary)
            
            TextField("Reps", value: $set.reps, format: .number)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
            if set.warmup { 
                Text("Warmup")
                    .foregroundStyle(.orange)
                    .font(.caption)
            }
        }
    }
}

struct SavedWorkoutsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var savedWorkouts: [[String: Any]] {
        HistoryCodec.loadSavedWorkouts()
    }
    
    var body: some View {
        NavigationStack {
            List {
                if savedWorkouts.isEmpty {
                    Text("No workouts saved yet!")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(0..<savedWorkouts.count, id: \.self) { index in
                        let workout = savedWorkouts[index]
                        VStack(alignment: .leading, spacing: 4) {
                            if let timestamp = workout["date"] as? TimeInterval {
                                Text(Date(timeIntervalSince1970: timestamp).formatted(date: .abbreviated, time: .shortened))
                                    .font(.headline)
                            }
                            
                            if let exercises = workout["exercises"] as? [String: [[String: Any]]] {
                                ForEach(exercises.keys.sorted(), id: \.self) { exercise in
                                    if let sets = exercises[exercise] {
                                        Text("\(exercise): \(sets.count) sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if let notes = workout["notes"] as? String, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Notes:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Saved Workouts")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear All") {
                        UserDefaults.standard.removeObject(forKey: "savedWorkouts")
                    }
                }
            }
        }
    }
}

struct ExerciseSessionSheet_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseSessionSheet(exerciseName: "Bulgarian Split Squat", dailyWorkout: DailyWorkoutSession())
    }
}