import SwiftUI

struct ExerciseManagementView: View {
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    @State private var showingAddDay = false
    @State private var showingAddExercise = false
    @State private var showingEditDay: WorkoutDayConfig?
    @State private var showingEditExercise: String?
    
    var body: some View {
        NavigationStack {
            List {
                // Workout Days Section
                Section("Workout Days") {
                    ForEach(configManager.workoutDays) { day in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(day.name)
                                    .font(.headline)
                                Spacer()
                                if day.isDefault {
                                    Text("Default")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text("\(day.exercises.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if !day.exercises.isEmpty {
                                Text(day.exercises.prefix(3).joined(separator: ", ") + (day.exercises.count > 3 ? "..." : ""))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingEditDay = day
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !day.isDefault {
                                Button("Delete", role: .destructive) {
                                    configManager.deleteWorkoutDay(id: day.id)
                                }
                            }
                        }
                    }
                    
                    Button(action: { showingAddDay = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Workout Day")
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Exercises Section
                Section("All Exercises") {
                    ForEach(configManager.allExercises.sorted(), id: \.self) { exercise in
                        HStack {
                            Text(exercise)
                            Spacer()
                            Button("Edit") {
                                showingEditExercise = exercise
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingEditExercise = exercise
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Delete", role: .destructive) {
                                configManager.deleteExercise(name: exercise)
                            }
                        }
                    }
                    
                    Button(action: { showingAddExercise = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Manage Workouts")
            .sheet(isPresented: $showingAddDay) {
                AddWorkoutDaySheet()
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseSheet()
            }
            .sheet(item: $showingEditDay) { day in
                EditWorkoutDaySheet(day: day)
            }
            .sheet(isPresented: Binding<Bool>(
                get: { showingEditExercise != nil },
                set: { if !$0 { showingEditExercise = nil } }
            )) {
                if let exercise = showingEditExercise {
                    EditExerciseSheet(exerciseName: exercise)
                }
            }
        }
    }
}

// MARK: - Add Workout Day Sheet

struct AddWorkoutDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    @State private var dayName = ""
    @State private var selectedExercises: Set<String> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Day Name") {
                    TextField("Enter day name", text: $dayName)
                }
                
                Section("Select Exercises") {
                    ForEach(configManager.allExercises.sorted(), id: \.self) { exercise in
                        HStack {
                            Text(exercise)
                            Spacer()
                            if selectedExercises.contains(exercise) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedExercises.contains(exercise) {
                                selectedExercises.remove(exercise)
                            } else {
                                selectedExercises.insert(exercise)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Workout Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        configManager.addWorkoutDay(
                            name: dayName,
                            exercises: Array(selectedExercises).sorted()
                        )
                        dismiss()
                    }
                    .disabled(dayName.isEmpty || selectedExercises.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Workout Day Sheet

struct EditWorkoutDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    let day: WorkoutDayConfig
    @State private var dayName: String
    @State private var selectedExercises: Set<String>
    
    init(day: WorkoutDayConfig) {
        self.day = day
        self._dayName = State(initialValue: day.name)
        self._selectedExercises = State(initialValue: Set(day.exercises))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Day Name") {
                    TextField("Enter day name", text: $dayName)
                        .disabled(day.isDefault)
                }
                
                Section("Select Exercises") {
                    ForEach(configManager.allExercises.sorted(), id: \.self) { exercise in
                        HStack {
                            Text(exercise)
                            Spacer()
                            if selectedExercises.contains(exercise) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedExercises.contains(exercise) {
                                selectedExercises.remove(exercise)
                            } else {
                                selectedExercises.insert(exercise)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Workout Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        configManager.updateWorkoutDay(
                            id: day.id,
                            name: dayName,
                            exercises: Array(selectedExercises).sorted()
                        )
                        dismiss()
                    }
                    .disabled(dayName.isEmpty || selectedExercises.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Exercise Sheet

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    @State private var exerciseName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("Enter exercise name", text: $exerciseName)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        configManager.addExercise(name: exerciseName)
                        dismiss()
                    }
                    .disabled(exerciseName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Exercise Sheet

struct EditExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    let exerciseName: String
    @State private var newName: String
    
    init(exerciseName: String) {
        self.exerciseName = exerciseName
        self._newName = State(initialValue: exerciseName)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("Enter exercise name", text: $newName)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        configManager.updateExercise(oldName: exerciseName, newName: newName)
                        dismiss()
                    }
                    .disabled(newName.isEmpty || newName == exerciseName)
                }
            }
        }
    }
}

#Preview {
    ExerciseManagementView()
}
