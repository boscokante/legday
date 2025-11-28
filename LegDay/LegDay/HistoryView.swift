import SwiftUI

struct HistoryView: View {
    @State private var workouts: [[String: Any]] = []
    @State private var importStatus: String = ""
    @State private var editingWorkoutIndex: Int? = nil
    @State private var editingNotes: String = ""
    @State private var editingDateIndex: Int? = nil
    @State private var editingDate: Date = Date()
    @State private var showDatePicker: Bool = false
    
    var body: some View {
        NavigationStack {
            List {
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
                                        if let ts = w["date"] as? TimeInterval {
                                            editingDate = Date(timeIntervalSince1970: ts)
                                        } else {
                                            editingDate = Date()
                                        }
                                        editingDateIndex = index
                                        showDatePicker = true
                                    }) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                    }
                                    Button(action: {
                                        editingWorkoutIndex = index
                                        editingNotes = w["notes"] as? String ?? ""
                                    }) {
                                        Image(systemName: "pencil")
                                            .font(.caption)
                                    }
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
                                    .foregroundStyle(.secondary)
                                    Spacer()
                                    Button("Save") {
                                        saveNotes(for: index)
                                    }
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
                    }
                }
            }
            .navigationTitle("History")
            .onAppear(perform: load)
            .sheet(isPresented: $showDatePicker) {
                DateEditSheet(
                    date: $editingDate,
                    onSave: {
                        if let index = editingDateIndex {
                            saveDate(for: index)
                        }
                        showDatePicker = false
                    },
                    onCancel: {
                        showDatePicker = false
                        editingDateIndex = nil
                    }
                )
            }
        }
    }
    
    private func saveDate(for index: Int) {
        guard index < workouts.count else { 
            print("❌ Index \(index) out of range (count: \(workouts.count))")
            return 
        }
        
        // Use editingDate directly - normalize to start of day
        let normalized = Calendar.current.startOfDay(for: editingDate).timeIntervalSince1970
        
        // Get the workout we're modifying
        let oldDate = workouts[index]["date"] as? TimeInterval
        let dayName = workouts[index]["day"] as? String
        
        print("📅 Saving date change:")
        print("   Index: \(index)")
        print("   Day: \(dayName ?? "unknown")")
        print("   Old date: \(oldDate ?? 0) -> \(oldDate.map { Date(timeIntervalSince1970: $0) } ?? Date())")
        print("   New date: \(normalized) -> \(editingDate)")
        
        // Create a mutable copy and update the date
        var updatedWorkouts = workouts
        var updatedWorkout = updatedWorkouts[index]
        updatedWorkout["date"] = normalized
        updatedWorkouts[index] = updatedWorkout
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updatedWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize()
            print("✅ Saved to UserDefaults")
            
            // Clear editing state
            editingDateIndex = nil
            
            // Re-sort the workouts after the date change (since sort order may have changed)
            workouts = updatedWorkouts.sorted { lhs, rhs in
                let lhsDate = lhs["date"] as? TimeInterval ?? 0
                let rhsDate = rhs["date"] as? TimeInterval ?? 0
                return lhsDate > rhsDate
            }
            
            print("✅ Updated local state with \(workouts.count) workouts")
        } catch {
            print("❌ Error saving date: \(error)")
        }
    }
    
    private func saveNotes(for index: Int) {
        guard index < workouts.count else { return }
        
        var updatedWorkouts = workouts
        // Directly modify the dictionary at the index
        updatedWorkouts[index]["notes"] = editingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Save back to UserDefaults
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updatedWorkouts)
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
            UserDefaults.standard.synchronize() // Force immediate save
            
            // Clear editing state
            editingWorkoutIndex = nil
            editingNotes = ""
            
            // Update local state directly - DON'T call load() as it can cause race conditions
            workouts = updatedWorkouts
        } catch {
            print("Error saving notes: \(error)")
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