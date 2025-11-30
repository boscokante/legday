import SwiftUI

private struct DateEditContext: Identifiable {
    let id = UUID()
    let listIndex: Int
    let originalTimestamp: TimeInterval?
    let dayName: String?
}

// MARK: - Workout Edit Models
private struct WorkoutEditContext: Identifiable {
    let id = UUID()
    let originalTimestamp: TimeInterval
    let dayName: String
    let exercises: [EditableExercise]
}

private class EditableExercise: ObservableObject, Identifiable {
    let id = UUID()
    let name: String
    @Published var sets: [EditableSet]
    
    init(name: String, sets: [EditableSet]) {
        self.name = name
        self.sets = sets
    }
    
    static func from(name: String, setsData: [[String: Any]]) -> EditableExercise {
        let sets = setsData.enumerated().map { index, setData in
            EditableSet(
                reps: setData["reps"] as? Int ?? 0,
                weight: setData["weight"] as? Double ?? 0,
                isWarmup: setData["warmup"] as? Bool ?? false
            )
        }
        return EditableExercise(name: name, sets: sets)
    }
    
    func toDict() -> [[String: Any]] {
        sets.map { set in
            var dict: [String: Any] = [
                "reps": set.reps,
                "weight": set.weight
            ]
            if set.isWarmup {
                dict["warmup"] = true
            }
            return dict
        }
    }
}

private class EditableSet: ObservableObject, Identifiable {
    let id = UUID()
    @Published var reps: Int
    @Published var weight: Double
    @Published var isWarmup: Bool
    
    init(reps: Int, weight: Double, isWarmup: Bool) {
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
    }
}

struct HistoryView: View {
    @State private var workouts: [[String: Any]] = []
    @State private var importStatus: String = ""
    @State private var editingWorkoutIndex: Int? = nil
    @State private var editingNotes: String = ""
    @State private var editingDateContext: DateEditContext? = nil
    @State private var editingDate: Date = Date()
    @State private var editingWorkoutContext: WorkoutEditContext? = nil
    @State private var rotationStatus: RotationStatus = RotationStatus()
    @State private var workoutToDelete: (date: TimeInterval, day: String)? = nil
    @State private var showDeleteConfirmation: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
                // Rotation Dashboard
                Section {
                    RotationDashboardView(status: rotationStatus)
                }
                
                if !importStatus.isEmpty {
                    Section {
                        Text(importStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Timeline") {
                    ForEach(Array(workouts.enumerated()), id: \.offset) { index, w in
                        VStack(alignment: .leading, spacing: 6) {
                            // Date and Day Type
                            HStack {
                                if let ts = w["date"] as? TimeInterval {
                                    Text(Date(timeIntervalSince1970: ts).formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                }
                                if let day = w["day"] as? String {
                                    Text("• \(day)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 12) {
                                    Button(action: {
                                        let timestamp = w["date"] as? TimeInterval
                                        editingDate = timestamp.map { Date(timeIntervalSince1970: $0) } ?? Date()
                                        let dayName = w["day"] as? String
                                        
                                        editingDateContext = DateEditContext(
                                            listIndex: index,
                                            originalTimestamp: timestamp,
                                            dayName: dayName
                                        )
                                    }) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                    Button(action: {
                                        guard let timestamp = w["date"] as? TimeInterval,
                                              let dayName = w["day"] as? String,
                                              let exercisesData = w["exercises"] as? [String: [[String: Any]]] else {
                                            return
                                        }
                                        
                                        let exercises = exercisesData.keys.sorted().map { name in
                                            EditableExercise.from(name: name, setsData: exercisesData[name] ?? [])
                                        }
                                        
                                        editingWorkoutContext = WorkoutEditContext(
                                            originalTimestamp: timestamp,
                                            dayName: dayName,
                                            exercises: exercises
                                        )
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            
                            // Exercise highlights with compact set summaries
                            if let exercises = w["exercises"] as? [String: [[String: Any]]] {
                                ForEach(exercises.keys.sorted(), id: \.self) { exerciseName in
                                    if let sets = exercises[exerciseName] {
                                        let summary = formatSetSummary(exerciseName: exerciseName, sets: sets)
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            
                            if editingWorkoutIndex == index {
                                TextEditor(text: $editingNotes)
                                    .frame(minHeight: 60)
                                    .font(.caption)
                                HStack {
                                    Button("Cancel") {
                                        editingWorkoutIndex = nil
                                        editingNotes = ""
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Save") {
                                        saveNotes(for: index)
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.blue)
                                }
                            } else {
                                if let notes = w["notes"] as? String, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Notes: \(notes)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let date = w["date"] as? TimeInterval,
                                   let day = w["day"] as? String {
                                    workoutToDelete = (date, day)
                                    showDeleteConfirmation = true
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .onAppear {
                load()
                loadRotationStatus()
            }
        .sheet(item: $editingDateContext) { context in
            DateEditSheet(
                date: $editingDate,
                onSave: {
                    saveDate(using: context)
                    editingDateContext = nil
                },
                onCancel: {
                    editingDateContext = nil
                }
            )
        }
        .sheet(item: $editingWorkoutContext) { context in
            WorkoutEditSheet(
                context: context,
                onSave: {
                    saveWorkoutEdits(using: context)
                    editingWorkoutContext = nil
                },
                onCancel: {
                    editingWorkoutContext = nil
                }
            )
        }
            .alert("Delete Workout?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    workoutToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let toDelete = workoutToDelete {
                        deleteWorkout(date: toDelete.date, day: toDelete.day)
                    }
                    workoutToDelete = nil
                }
            } message: {
                if let toDelete = workoutToDelete {
                    Text("This will permanently delete the \(toDelete.day) workout from \(Date(timeIntervalSince1970: toDelete.date).formatted(date: .abbreviated, time: .omitted)).")
                }
            }
        }
    }
    
    private func saveDate(using context: DateEditContext) {
        var originalDate = context.originalTimestamp
        var dayName = context.dayName
        
        if (originalDate == nil || dayName == nil),
           context.listIndex < workouts.count {
            if originalDate == nil {
                originalDate = workouts[context.listIndex]["date"] as? TimeInterval
            }
            if dayName == nil {
                dayName = workouts[context.listIndex]["day"] as? String
            }
        }
        
        guard let resolvedDate = originalDate else {
            print("❌ Missing original date for context at index \(context.listIndex)")
            return
        }
        
        // Normalize new date to start of day
        let newDate = Calendar.current.startOfDay(for: editingDate).timeIntervalSince1970
        
        print("📅 Saving date change:")
        print("   Day: \(dayName ?? "unknown")")
        print("   Old date: \(Date(timeIntervalSince1970: resolvedDate))")
        print("   New date: \(editingDate)")
        
        // Load fresh data from UserDefaults to avoid stale state issues
        var freshWorkouts = HistoryCodec.loadSavedWorkouts()
        
        // Find the workout by original date + day name (unique identifier)
        guard let targetIndex = freshWorkouts.firstIndex(where: { workout in
            let workoutDate = workout["date"] as? TimeInterval
            let workoutDay = workout["day"] as? String
            if let dayName = dayName {
                return workoutDate == resolvedDate && workoutDay == dayName
            }
            return workoutDate == resolvedDate
        }) else {
            print("❌ Could not find workout to update")
            return
        }
        
        // Update the date in place
        freshWorkouts[targetIndex]["date"] = newDate
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: freshWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize()
            print("✅ Saved to UserDefaults")
            
            // Re-sort and update local state
            workouts = freshWorkouts.sorted { lhs, rhs in
                let lhsDate = lhs["date"] as? TimeInterval ?? 0
                let rhsDate = rhs["date"] as? TimeInterval ?? 0
                return lhsDate > rhsDate
            }
            
            // Refresh rotation status after date change
            loadRotationStatus()
            
            print("✅ Updated local state with \(workouts.count) workouts")
        } catch {
            print("❌ Error saving date: \(error)")
        }
    }
    
    private func saveNotes(for index: Int) {
        guard index < workouts.count else { return }
        
        // Get unique identifier from local state
        let originalDate = workouts[index]["date"] as? TimeInterval
        let dayName = workouts[index]["day"] as? String
        
        // Load fresh data from UserDefaults
        var freshWorkouts = HistoryCodec.loadSavedWorkouts()
        
        // Find the workout by original date + day name
        guard let targetIndex = freshWorkouts.firstIndex(where: { workout in
            let workoutDate = workout["date"] as? TimeInterval
            let workoutDay = workout["day"] as? String
            return workoutDate == originalDate && workoutDay == dayName
        }) else {
            print("❌ Could not find workout to update notes")
            return
        }
        
        // Update the notes
        freshWorkouts[targetIndex]["notes"] = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: freshWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize()
            
            // Clear editing state
            editingWorkoutIndex = nil
            editingNotes = ""
            
            // Update local state with fresh sorted data
            workouts = freshWorkouts.sorted { lhs, rhs in
                let lhsDate = lhs["date"] as? TimeInterval ?? 0
                let rhsDate = rhs["date"] as? TimeInterval ?? 0
                return lhsDate > rhsDate
            }
        } catch {
            print("Error saving notes: \(error)")
        }
    }
    
    private func saveWorkoutEdits(using context: WorkoutEditContext) {
        // Load fresh data from UserDefaults
        var freshWorkouts = HistoryCodec.loadSavedWorkouts()
        
        // Find the workout by original date + day name
        guard let targetIndex = freshWorkouts.firstIndex(where: { workout in
            let workoutDate = workout["date"] as? TimeInterval
            let workoutDay = workout["day"] as? String
            return workoutDate == context.originalTimestamp && workoutDay == context.dayName
        }) else {
            print("❌ Could not find workout to update")
            return
        }
        
        // Build updated exercises dictionary
        var updatedExercises: [String: [[String: Any]]] = [:]
        for exercise in context.exercises {
            // Only include exercises that have sets
            if !exercise.sets.isEmpty {
                updatedExercises[exercise.name] = exercise.toDict()
            }
        }
        
        // Update the exercises
        freshWorkouts[targetIndex]["exercises"] = updatedExercises
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: freshWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize()
            
            // Update local state
            workouts = freshWorkouts.sorted { lhs, rhs in
                let lhsDate = lhs["date"] as? TimeInterval ?? 0
                let rhsDate = rhs["date"] as? TimeInterval ?? 0
                return lhsDate > rhsDate
            }
            
            print("✅ Saved workout edits for \(context.dayName) on \(Date(timeIntervalSince1970: context.originalTimestamp).formatted(date: .abbreviated, time: .omitted))")
        } catch {
            print("❌ Error saving workout edits: \(error)")
        }
    }
    
    private func deleteWorkout(date: TimeInterval, day: String) {
        // Load fresh data from UserDefaults
        var freshWorkouts = HistoryCodec.loadSavedWorkouts()
        
        let targetDate = Date(timeIntervalSince1970: date)
        let countBefore = freshWorkouts.count
        
        // Find and remove the workout by same calendar day + day name
        freshWorkouts.removeAll { workout in
            guard let workoutDate = workout["date"] as? TimeInterval,
                  let workoutDay = workout["day"] as? String else { return false }
            let workoutDateObj = Date(timeIntervalSince1970: workoutDate)
            let sameDay = Calendar.current.isDate(workoutDateObj, inSameDayAs: targetDate)
            return sameDay && workoutDay == day
        }
        
        print("🗑️ Delete: removing \(day) on \(targetDate.formatted(date: .abbreviated, time: .omitted))")
        print("   Workouts before: \(countBefore), after: \(freshWorkouts.count)")
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: freshWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize()
            
            // Update local state
            workouts = freshWorkouts.sorted { lhs, rhs in
                let lhsDate = lhs["date"] as? TimeInterval ?? 0
                let rhsDate = rhs["date"] as? TimeInterval ?? 0
                return lhsDate > rhsDate
            }
            
            // Refresh rotation status
            loadRotationStatus()
            
            print("✅ Deleted workout: \(day) on \(Date(timeIntervalSince1970: date).formatted(date: .abbreviated, time: .omitted))")
        } catch {
            print("❌ Error deleting workout: \(error)")
        }
    }
}

// MARK: - Date Edit Sheet
struct DateEditSheet: View {
    @Binding var date: Date
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker("Select Date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Change Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Workout Edit Sheet
private struct WorkoutEditSheet: View {
    let context: WorkoutEditContext
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(context.exercises) { exercise in
                    ExerciseEditSection(exercise: exercise)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct ExerciseEditSection: View {
    @ObservedObject var exercise: EditableExercise
    
    var body: some View {
        Section(exercise.name) {
            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                SetEditRow(setNumber: index + 1, set: set)
            }
            .onDelete { indexSet in
                exercise.sets.remove(atOffsets: indexSet)
            }
            
            Button(action: {
                // Add a new set with same values as last set, or defaults
                let lastSet = exercise.sets.last
                let newSet = EditableSet(
                    reps: lastSet?.reps ?? 10,
                    weight: lastSet?.weight ?? 0,
                    isWarmup: false
                )
                exercise.sets.append(newSet)
            }) {
                Label("Add Set", systemImage: "plus.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}

private struct SetEditRow: View {
    let setNumber: Int
    @ObservedObject var set: EditableSet
    
    var body: some View {
        HStack(spacing: 12) {
            // Set number and warmup indicator
            HStack(spacing: 4) {
                Text("Set \(setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(set.isWarmup ? .orange : .primary)
                if set.isWarmup {
                    Text("W")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }
            }
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // Reps field
            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 50)
                    .multilineTextAlignment(.center)
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Weight field
            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.center)
                Text("lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Warmup toggle
            Button(action: {
                set.isWarmup.toggle()
            }) {
                Image(systemName: set.isWarmup ? "flame.fill" : "flame")
                    .foregroundStyle(set.isWarmup ? .orange : .gray)
            }
            .buttonStyle(.borderless)
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
    }
}

// MARK: - Data Loading
extension HistoryView {
    private func load() {
        let loaded = HistoryCodec.loadSavedWorkouts()
        // Sort in reverse chronological order (most recent first)
        workouts = loaded.sorted { lhs, rhs in
            let lhsDate = lhs["date"] as? TimeInterval ?? 0
            let rhsDate = rhs["date"] as? TimeInterval ?? 0
            return lhsDate > rhsDate
        }
    }
    
    private func formatSetSummary(exerciseName: String, sets: [[String: Any]]) -> String {
        // Filter out warmup sets for the summary
        let workingSets = sets.filter { set in
            guard let warmup = set["warmup"] as? Bool else { return true }
            return !warmup
        }
        
        guard !workingSets.isEmpty else {
            return "\(exerciseName): \(sets.count) warmup"
        }
        
        // Format: "Exercise, N sets: 5x50,5x70,5x75,5x75"
        let setStrings = workingSets.compactMap { set -> String? in
            guard let reps = set["reps"] as? Int,
                  let weight = set["weight"] as? Double else { return nil }
            // Format weight without decimal if it's a whole number
            let weightStr = weight.truncatingRemainder(dividingBy: 1) == 0 
                ? String(Int(weight)) 
                : String(format: "%.1f", weight)
            return "\(reps)×\(weightStr)"
        }.joined(separator: ",")
        
        let totalSets = sets.count
        let warmupCount = sets.count - workingSets.count
        let warmupLabel = warmupCount > 0 ? " (\(warmupCount)W)" : ""
        
        return "\(exerciseName), \(totalSets) sets\(warmupLabel): \(setStrings)"
    }
}

// MARK: - Export/Import helpers (not exposed in UI yet)
extension HistoryView {
    func exportHistory(to url: URL) throws {
        let data = try HistoryCodec.exportToData()
        try data.write(to: url)
    }
    
    func importHistory(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try HistoryCodec.importFromData(data)
        load()
    }
}

// MARK: - Rotation Status
extension HistoryView {
    private func loadRotationStatus() {
        Task {
            let provider = HistorySummaryProvider()
            let summary = await provider.getSummary(windowDays: 90)
            
            await MainActor.run {
                rotationStatus = RotationStatus(
                    daysSinceByType: summary.daysSinceByWorkoutType,
                    lastAchillesIntensity: summary.lastAchillesIntensity
                )
            }
        }
    }
}

struct RotationStatus {
    var daysSinceByType: [String: Int] = [:]
    var lastAchillesIntensity: String? = nil
    
    /// Next Achilles intensity recommendation.
    /// If no Achilles was done yesterday (days since > 1), always recommend Heavy.
    /// Only alternate to Light if Heavy was done yesterday.
    var nextAchilles: String {
        // Check if we did any Achilles yesterday
        let daysSinceAchilles = daysSinceByType["achilles"] ?? 999
        
        // If no Achilles yesterday (or ever), always do Heavy
        if daysSinceAchilles != 1 {
            return "Heavy"
        }
        
        // We did Achilles yesterday, so alternate based on last intensity
        return lastAchillesIntensity == "heavy" ? "Light" : "Heavy"
    }
    
    var recommendedPrimary: (type: String, days: Int)? {
        let primaries = ["leg", "push", "pull"]
        return primaries
            .compactMap { type -> (String, Int)? in
                guard let days = daysSinceByType[type] else { return nil }
                return (type, days)
            }
            .max { $0.1 < $1.1 }
    }
    
    /// Full recommendation including Core when appropriate
    /// Core is added when: Achilles is Light AND days since core >= 2
    var fullRecommendation: String {
        guard let rec = recommendedPrimary else { return "" }
        
        var result = "\(rec.type.capitalized) + Achilles \(nextAchilles)"
        
        // Add Core if it's a Light Achilles day and core hasn't been done in 2+ days
        let daysSinceCore = daysSinceByType["core"] ?? 999
        if nextAchilles == "Light" && daysSinceCore >= 2 {
            result += " + Core"
        }
        
        return result
    }
}

struct RotationDashboardView: View {
    let status: RotationStatus
    
    private let primaryTypes = ["leg", "push", "pull", "core", "achilles"]
    private let activityTypes = ["hoop", "bike"]
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary 5 workout types - all across top
            HStack(spacing: 8) {
                ForEach(primaryTypes, id: \.self) { type in
                    DaysTile(
                        type: type,
                        days: status.daysSinceByType[type],
                        isRecommended: status.recommendedPrimary?.type == type
                    )
                }
            }
            
            // Activity row (Hoop, Bike)
            HStack(spacing: 8) {
                ForEach(activityTypes, id: \.self) { type in
                    DaysTile(
                        type: type,
                        days: status.daysSinceByType[type],
                        isRecommended: false
                    )
                }
                Spacer()
            }
            
            Divider()
            
            // Today's recommendation
            if status.recommendedPrimary != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next Achilles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: status.nextAchilles == "Heavy" ? "flame.fill" : "leaf.fill")
                                .font(.caption)
                                .foregroundStyle(status.nextAchilles == "Heavy" ? .orange : .green)
                            Text(status.nextAchilles)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(status.nextAchilles == "Heavy" ? .orange : .green)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Suggested")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(status.fullRecommendation)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct DaysTile: View {
    let type: String
    let days: Int?
    let isRecommended: Bool
    
    private var urgencyColor: Color {
        guard let days = days else { return .gray }
        switch days {
        case 0: return .green
        case 1: return .mint
        case 2: return .yellow
        case 3: return .orange
        default: return .red
        }
    }
    
    private var displayName: String {
        switch type {
        case "achilles": return "Achilles"
        default: return type.capitalized
        }
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            
            if let days = days {
                Text("\(days)d")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(isRecommended ? .blue : urgencyColor)
            } else {
                Text("--")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isRecommended ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isRecommended ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
        )
    }
}
