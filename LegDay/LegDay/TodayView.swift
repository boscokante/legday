import SwiftUI
import CoreData
import Combine
import AudioToolbox

// Rest Timer Class
class RestTimer: ObservableObject {
    @Published var remainingTime: Int
    @Published var isActive: Bool = false
    @Published var isFinished: Bool = false
    
    private var timer: Timer?
    private let totalTime: Int
    let timerName: String
    let soundID: SystemSoundID
    let soundRepeatCount: Int
    
    init(seconds: Int, name: String, soundID: SystemSoundID = 1005, soundRepeatCount: Int = 1) {
        self.totalTime = seconds
        self.remainingTime = seconds
        self.timerName = name
        self.soundID = soundID
        self.soundRepeatCount = soundRepeatCount
    }
    
    func start() {
        guard !isActive else { return }
        
        print("🚀 Starting timer: \(timerName)")
        isActive = true
        isFinished = false
        remainingTime = totalTime
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if self.remainingTime > 0 {
                    self.remainingTime -= 1
                } else {
                    self.finish()
                }
            }
        }
    }
    
    func stop() {
        print("⏹️ Stopping timer: \(timerName)")
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingTime = totalTime
    }
    
    private func finish() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isFinished = true
        
        // Play sound multiple times if needed
        playSound(repeatCount: soundRepeatCount)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func playSound(repeatCount: Int) {
        guard repeatCount > 0 else { return }
        
        if repeatCount == 1 {
            AudioServicesPlaySystemSound(soundID)
        } else {
            var remaining = repeatCount
            func playNext() {
                guard remaining > 0 else { return }
                remaining -= 1
                AudioServicesPlaySystemSoundWithCompletion(soundID) {
                    if remaining > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            playNext()
                        }
                    }
                }
            }
            playNext()
        }
    }
    
    var formattedTime: String {
        let minutes = remainingTime / 60
        let seconds = remainingTime % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var progress: Double {
        return Double(totalTime - remainingTime) / Double(totalTime)
    }
}

// Shared timer manager - TRUE SINGLETON
class TimerManager: ObservableObject {
    @Published var timer2min = RestTimer(seconds: 120, name: "2 Min", soundID: 1005)  // Tri-tone (once)
    @Published var timer45sec = RestTimer(seconds: 45, name: "45 Sec", soundID: 1016, soundRepeatCount: 3)  // Alert tone (3x)
    @Published var timer30sec = RestTimer(seconds: 30, name: "30 Sec", soundID: 1022, soundRepeatCount: 2)  // Beep (2x)
    
    static let shared = TimerManager()
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Subscribe to timer updates to trigger UI refresh
        timer2min.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
        
        timer45sec.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)

        timer30sec.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }.store(in: &cancellables)
    }
}

// WorkoutDay enum removed - now using WorkoutConfigManager

// Daily workout session model
class DailyWorkoutSession: ObservableObject {
    @Published var exercises: [String: [SetData]] = [:]
    @Published var dayId: String = ""
    @Published var dayName: String = ""
    @Published var notes: String = ""
    private let dateKey: String
    
    // Store in-progress workouts for each day separately
    private var dayWorkouts: [String: (exercises: [String: [SetData]], notes: String)] = [:]
    
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateKey = formatter.string(from: Date())
        
        // Initialize with default day
        self.dayId = configManager.getDefaultDayId()
        if let dayConfig = configManager.getWorkoutDay(id: dayId) {
            self.dayName = dayConfig.name
        }
        
        loadTodaysWorkout()
    }
    
    func addSet(to exercise: String, set: SetData) {
        if exercises[exercise] == nil {
            exercises[exercise] = []
        }
        exercises[exercise]?.append(set)
        saveTodaysWorkout()
    }
    
    func updateSet(exercise: String, index: Int, weight: Double, reps: Int, warmup: Bool, completed: Bool) {
        guard exercises[exercise] != nil && index < exercises[exercise]!.count else { return }
        
        exercises[exercise]![index].weight = weight
        exercises[exercise]![index].reps = reps
        exercises[exercise]![index].warmup = warmup
        exercises[exercise]![index].completed = completed
        
        saveTodaysWorkout()
        objectWillChange.send()
    }
    
    func removeSet(from exercise: String, at index: Int) {
        exercises[exercise]?.remove(at: index)
        saveTodaysWorkout()
    }
    
    func getSets(for exercise: String) -> [SetData] {
        return exercises[exercise] ?? []
    }
    
    func getTotalSets() -> Int {
        exercises.values.reduce(0) { total, sets in total + sets.count }
    }
    
    func getCompletedSets() -> Int {
        exercises.values.reduce(0) { total, sets in 
            total + sets.filter { $0.completed }.count 
        }
    }
    
    func saveCompleteWorkout() {
        // Save current day to memory first
        saveCurrentDayToMemory()
        
        // Collect all workouts from all days worked on today
        var allExercises: [String: [[String: Any]]] = [:]
        var allNotes: [String] = []
        var daysWorked: Set<String> = []
        
        // Add current day if it has exercises
        if !exercises.isEmpty {
            daysWorked.insert(dayName)
            for (exerciseName, sets) in exercises {
                // Only save completed sets
                let completedSets = sets.filter { $0.completed }
                if !completedSets.isEmpty {
                    allExercises[exerciseName] = completedSets.map { set in
                        ["weight": set.weight, "reps": set.reps, "warmup": set.warmup]
                    }
                }
            }
            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                allNotes.append("\(dayName): \(notes)")
            }
        }
        
        // Add other days from memory cache
        for (workoutDayId, data) in dayWorkouts where workoutDayId != dayId {
            if !data.exercises.isEmpty {
                if let dayConfig = configManager.getWorkoutDay(id: workoutDayId) {
                    daysWorked.insert(dayConfig.name)
                }
                for (exerciseName, sets) in data.exercises {
                    // Only save completed sets
                    let completedSets = sets.filter { $0.completed }
                    if !completedSets.isEmpty {
                        allExercises[exerciseName] = completedSets.map { set in
                            ["weight": set.weight, "reps": set.reps, "warmup": set.warmup]
                        }
                    }
                }
                if !data.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if let dayConfig = configManager.getWorkoutDay(id: workoutDayId) {
                        allNotes.append("\(dayConfig.name): \(data.notes)")
                    }
                }
            }
        }
        
        guard !allExercises.isEmpty else {
            print("⚠️ No completed exercises to save")
            return
        }
        
        let combinedNotes = allNotes.joined(separator: "\n")
        let combinedDay = daysWorked.sorted().joined(separator: ", ")
        
        let workoutData: [String: Any] = [
            "date": Date().timeIntervalSince1970,
            "exercises": allExercises,
            "notes": combinedNotes,
            "day": combinedDay
        ]
        
        var savedWorkouts = HistoryCodec.loadSavedWorkouts()
        savedWorkouts.removeAll { workout in
            if let date = workout["date"] as? TimeInterval {
                return Calendar.current.isDate(Date(timeIntervalSince1970: date), inSameDayAs: Date())
            }
            return false
        }
        savedWorkouts.append(workoutData)
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: savedWorkouts) {
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
        }
        
        // Clear temp storage after successful save
        clearTempStorage()
        dayWorkouts.removeAll()
        
        print("=== WORKOUT SAVED: \(combinedDay) ===")
        for (exercise, sets) in allExercises {
            if let setArray = sets as? [[String: Any]] {
                print("\(exercise): \(setArray.count) sets")
            }
        }
        print("=============================")
    }
    
    private func clearTempStorage() {
        for workoutDay in configManager.workoutDays {
            let dayKey = "tempWorkout_\(dateKey)_\(workoutDay.id)"
            UserDefaults.standard.removeObject(forKey: dayKey)
            UserDefaults.standard.removeObject(forKey: "tempNotes_\(dateKey)_\(workoutDay.id)")
        }
    }
    
    private func saveTodaysWorkout() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: "workout_\(dateKey)")
        }
        UserDefaults.standard.set(notes, forKey: "workoutNotes_\(dateKey)")
        UserDefaults.standard.set(dayId, forKey: "workoutDay_\(dateKey)")
    }
    
    private func loadTodaysWorkout() {
        // First try to load today's workout
        if let data = UserDefaults.standard.data(forKey: "workout_\(dateKey)"),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            print("📅 Loaded existing workout for \(dateKey)")
        } else {
            // If no workout for today, prefill with previous workout
            loadPreviousWorkout()
        }
        if let savedNotes = UserDefaults.standard.string(forKey: "workoutNotes_\(dateKey)") {
            notes = savedNotes
        }
        if let savedDayId = UserDefaults.standard.string(forKey: "workoutDay_\(dateKey)") {
            dayId = savedDayId
            if let dayConfig = configManager.getWorkoutDay(id: dayId) {
                dayName = dayConfig.name
            }
        }
    }
    
    private func loadPreviousWorkout() {
        let savedWorkouts = HistoryCodec.loadSavedWorkouts()
        guard !savedWorkouts.isEmpty else {
            print("📭 No previous workouts found")
            return
        }
        
        // Filter by current day, sort by date (most recent first) and exclude today
        let sortedWorkouts = savedWorkouts
            .compactMap { workout -> (date: Date, data: [String: Any])? in
                guard let timestamp = workout["date"] as? TimeInterval else { return nil }
                let date = Date(timeIntervalSince1970: timestamp)
                // Skip if it's today
                guard !Calendar.current.isDateInToday(date) else { return nil }
                // Only include workouts matching the current selected day
                if let workoutDay = workout["day"] as? String {
                    guard workoutDay == dayName || workoutDay.contains(dayName) else { return nil }
                }
                return (date, workout)
            }
            .sorted { $0.date > $1.date }
        
        guard let mostRecent = sortedWorkouts.first,
              let exercisesData = mostRecent.data["exercises"] as? [String: [[String: Any]]] else {
            print("📭 No previous \(dayName) workout found")
            return
        }
        
        // Convert the workout data to SetData objects
        var loadedExercises: [String: [SetData]] = [:]
        for (exerciseName, setsArray) in exercisesData {
            let sets = setsArray.compactMap { setDict -> SetData? in
                guard let weight = setDict["weight"] as? Double,
                      let reps = setDict["reps"] as? Int,
                      let warmup = setDict["warmup"] as? Bool else {
                    return nil
                }
                // Load sets as UNCOMMITTED - user must check them off as they complete them
                return SetData(weight: weight, reps: reps, warmup: warmup, completed: false)
            }
            if !sets.isEmpty {
                loadedExercises[exerciseName] = sets
            }
        }
        
        if !loadedExercises.isEmpty {
            exercises = loadedExercises
            if let prevNotes = mostRecent.data["notes"] as? String {
                notes = prevNotes
            }
            if let prevDay = mostRecent.data["day"] as? String {
                // Try to find matching day by name
                if let dayConfig = configManager.workoutDays.first(where: { $0.name == prevDay }) {
                    dayId = dayConfig.id
                    dayName = dayConfig.name
                }
            }
            // Save as today's starting point
            saveTodaysWorkout()
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            print("✅ Prefilled workout from \(dateFormatter.string(from: mostRecent.date)) - \(getTotalSets()) sets loaded")
        } else {
            print("📭 Previous workout was empty")
        }
    }
    
    func clearTodaysWorkout() {
        exercises.removeAll()
        notes = ""
        UserDefaults.standard.removeObject(forKey: "workout_\(dateKey)")
        UserDefaults.standard.removeObject(forKey: "workoutNotes_\(dateKey)")
        UserDefaults.standard.removeObject(forKey: "workoutDay_\(dateKey)")
    }
    
    func loadPreviousWorkoutManually() {
        // Clear current workout first
        exercises.removeAll()
        // Load previous workout
        loadPreviousWorkout()
    }
    
    func updateNotes(_ newNotes: String) {
        notes = newNotes
        saveTodaysWorkout()
        objectWillChange.send()
    }
    
    func updateDay(_ newDayId: String) {
        // Save current day's work before switching
        saveCurrentDayToMemory()
        
        // Switch to new day
        dayId = newDayId
        if let dayConfig = configManager.getWorkoutDay(id: dayId) {
            dayName = dayConfig.name
        }
        
        // Load the new day's work from memory or storage
        loadDayFromMemory()
        
        objectWillChange.send()
    }
    
    private func saveCurrentDayToMemory() {
        // Store current state for this day in memory
        dayWorkouts[dayId] = (exercises: exercises, notes: notes)
        
        // Also persist to UserDefaults with day-specific key
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: dayKey)
        }
        UserDefaults.standard.set(notes, forKey: "tempNotes_\(dateKey)_\(dayId)")
    }
    
    private func loadDayFromMemory() {
        // First check in-memory cache
        if let cached = dayWorkouts[dayId] {
            exercises = cached.exercises
            notes = cached.notes
            print("📦 Loaded \(dayName) from memory cache")
            return
        }
        
        // Then check UserDefaults temp storage
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        if let data = UserDefaults.standard.data(forKey: dayKey),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            if let savedNotes = UserDefaults.standard.string(forKey: "tempNotes_\(dateKey)_\(dayId)") {
                notes = savedNotes
            }
            // Cache it
            dayWorkouts[dayId] = (exercises: exercises, notes: notes)
            print("📦 Loaded \(dayName) from temp storage")
            return
        }
        
        // Finally, try to load from previous workout for this day
        exercises.removeAll()
        notes = ""
        loadPreviousWorkout()
    }
}

// Identifiable wrapper for presenting exercise sheet safely
private struct ExerciseSelection: Identifiable, Equatable {
    let name: String
    var id: String { name }
}

struct TodayView: View {
    @Environment(\.managedObjectContext) private var ctx
    @StateObject private var dailyWorkout = DailyWorkoutSession()
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    @State private var selectedExercise: ExerciseSelection?
    @State private var showingSavedWorkouts: Bool = false
    @State private var showingWorkoutSaved: Bool = false
    @State private var showingAddExercise = false
    @State private var newExerciseName = ""
    @State private var confirmRestoreDefaults = false

    var exercises: [String] {
        return configManager.getExercisesForDay(dayId: dailyWorkout.dayId)
    }
    
    private func addExerciseToCurrentDay(_ exerciseName: String) {
        let configManager = WorkoutConfigManager.shared
        
        // Add to master exercise list if not already there
        configManager.addExercise(name: exerciseName)
        
        // Add to current day's exercise list
        if let currentDay = configManager.getWorkoutDay(id: dailyWorkout.dayId) {
            var updatedExercises = currentDay.exercises
            if !updatedExercises.contains(exerciseName) {
                updatedExercises.append(exerciseName)
                configManager.updateWorkoutDay(
                    id: dailyWorkout.dayId,
                    name: currentDay.name,
                    exercises: updatedExercises
                )
            }
        }
        
        // Clear the input field
        newExerciseName = ""
    }
    
    private func removeExerciseFromCurrentDay(_ exerciseName: String) {
        let configManager = WorkoutConfigManager.shared
        
        // Remove from current day's exercise list
        if let currentDay = configManager.getWorkoutDay(id: dailyWorkout.dayId) {
            var updatedExercises = currentDay.exercises
            updatedExercises.removeAll { $0 == exerciseName }
            configManager.updateWorkoutDay(
                id: dailyWorkout.dayId,
                name: currentDay.name,
                exercises: updatedExercises
            )
        }
        
        // Also remove any sets for this exercise from the current workout
        dailyWorkout.exercises.removeValue(forKey: exerciseName)
    }

    var body: some View {
        NavigationStack {
            List {
                // Rest Timers Section - Always visible
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
                
                Section(header: HStack {
                    Text("Today's Workout")
                    Spacer()
                    let completed = dailyWorkout.getCompletedSets()
                    let total = dailyWorkout.getTotalSets()
                    Text("\(completed)/\(total) completed")
                        .foregroundStyle(completed > 0 ? .green : .secondary)
                        .font(.caption)
                }) {
                    ForEach(exercises, id: \.self) { exercise in
                        HStack {
                            Button(exercise) {
                                selectedExercise = ExerciseSelection(name: exercise)
                            }
                            .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            let sets = dailyWorkout.getSets(for: exercise)
                            if !sets.isEmpty {
                                let completedCount = sets.filter { $0.completed }.count
                                Text("\(completedCount)/\(sets.count)")
                                    .foregroundStyle(completedCount > 0 ? .green : .secondary)
                                    .font(.caption)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                removeExerciseFromCurrentDay(exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    
                    // Add Exercise Button
                    Button(action: { showingAddExercise = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: Binding(
                        get: { dailyWorkout.notes },
                        set: { dailyWorkout.updateNotes($0) }
                    ))
                    .frame(minHeight: 60)
                }
                
                Section {
                    Button("Save Today's Workout") {
                        dailyWorkout.saveCompleteWorkout()
                        showingWorkoutSaved = true
                    }
                    .disabled(dailyWorkout.getCompletedSets() == 0)
                    .foregroundStyle(dailyWorkout.getCompletedSets() > 0 ? .blue : .secondary)
                    
                    Button("Load Previous Workout") {
                        dailyWorkout.loadPreviousWorkoutManually()
                    }
                    .foregroundStyle(.green)
                    
                    Button("Clear Today's Workout") {
                        dailyWorkout.clearTodaysWorkout()
                    }
                    .foregroundStyle(.red)
                    .disabled(dailyWorkout.getTotalSets() == 0)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(dailyWorkout.dayName)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu(dailyWorkout.dayName) {
                        ForEach(WorkoutConfigManager.shared.workoutDays, id: \.id) { dayConfig in
                            Button(dayConfig.name) {
                                dailyWorkout.updateDay(dayConfig.id)
                            }
                        }
                        Divider()
                        Button("Restore default exercises") {
                            confirmRestoreDefaults = true
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedExercise) { selection in
            ExerciseSessionSheet(
                exerciseName: selection.name,
                dailyWorkout: dailyWorkout
            )
        }
        .sheet(isPresented: $showingSavedWorkouts) {
            SavedWorkoutsView()
        }
        .alert("Workout Saved!", isPresented: $showingWorkoutSaved) {
            Button("OK") { }
        } message: {
            Text("Your workout with \(dailyWorkout.getCompletedSets()) completed sets has been saved!")
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseQuickSheet(
                exerciseName: $newExerciseName,
                onSave: { exerciseName in
                    addExerciseToCurrentDay(exerciseName)
                }
            )
        }
        .alert("Restore defaults?", isPresented: $confirmRestoreDefaults) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) {
                _ = WorkoutConfigManager.shared.restoreDefaultExercises(forDayId: dailyWorkout.dayId)
            }
        } message: {
            Text("This will replace today's exercise list with the default set for \(dailyWorkout.dayName).")
        }
        // Removed timer-finished alerts so finishing a timer only plays a sound and keeps context
    }
}

// MARK: - Add Exercise Quick Sheet

struct AddExerciseQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var exerciseName: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("Enter exercise name", text: $exerciseName)
                        .textFieldStyle(.roundedBorder)
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
                    Button("Add") {
                        onSave(exerciseName)
                        dismiss()
                    }
                    .disabled(exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}