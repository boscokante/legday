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
    }
}

enum WorkoutDay: String, CaseIterable, Codable {
    case leg = "Leg Day"
    case push = "Push Day"
    case pull = "Pull Day"
    case core = "Core Day"
    
    var displayName: String { rawValue }
}

// Daily workout session model
class DailyWorkoutSession: ObservableObject {
    @Published var exercises: [String: [SetData]] = [:]
    @Published var day: WorkoutDay = .leg
    @Published var notes: String = ""
    private let dateKey: String
    
    // Store in-progress workouts for each day separately
    private var dayWorkouts: [WorkoutDay: (exercises: [String: [SetData]], notes: String)] = [:]
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateKey = formatter.string(from: Date())
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
            daysWorked.insert(day.rawValue)
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
                allNotes.append("\(day.displayName): \(notes)")
            }
        }
        
        // Add other days from memory cache
        for (workoutDay, data) in dayWorkouts where workoutDay != day {
            if !data.exercises.isEmpty {
                daysWorked.insert(workoutDay.rawValue)
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
                    allNotes.append("\(workoutDay.displayName): \(data.notes)")
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
        for workoutDay in WorkoutDay.allCases {
            let dayKey = "tempWorkout_\(dateKey)_\(workoutDay.rawValue)"
            UserDefaults.standard.removeObject(forKey: dayKey)
            UserDefaults.standard.removeObject(forKey: "tempNotes_\(dateKey)_\(workoutDay.rawValue)")
        }
    }
    
    private func saveTodaysWorkout() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: "workout_\(dateKey)")
        }
        UserDefaults.standard.set(notes, forKey: "workoutNotes_\(dateKey)")
        UserDefaults.standard.set(day.rawValue, forKey: "workoutDay_\(dateKey)")
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
        if let savedDay = UserDefaults.standard.string(forKey: "workoutDay_\(dateKey)"),
           let parsed = WorkoutDay(rawValue: savedDay) {
            day = parsed
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
                    guard workoutDay == day.rawValue || workoutDay.contains(day.rawValue) else { return nil }
                }
                return (date, workout)
            }
            .sorted { $0.date > $1.date }
        
        guard let mostRecent = sortedWorkouts.first,
              let exercisesData = mostRecent.data["exercises"] as? [String: [[String: Any]]] else {
            print("📭 No previous \(day.displayName) workout found")
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
            if let prevDay = mostRecent.data["day"] as? String, let parsed = WorkoutDay(rawValue: prevDay) {
                day = parsed
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
    
    func updateDay(_ newDay: WorkoutDay) {
        // Save current day's work before switching
        saveCurrentDayToMemory()
        
        // Switch to new day
        day = newDay
        
        // Load the new day's work from memory or storage
        loadDayFromMemory()
        
        objectWillChange.send()
    }
    
    private func saveCurrentDayToMemory() {
        // Store current state for this day in memory
        dayWorkouts[day] = (exercises: exercises, notes: notes)
        
        // Also persist to UserDefaults with day-specific key
        let dayKey = "tempWorkout_\(dateKey)_\(day.rawValue)"
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: dayKey)
        }
        UserDefaults.standard.set(notes, forKey: "tempNotes_\(dateKey)_\(day.rawValue)")
    }
    
    private func loadDayFromMemory() {
        // First check in-memory cache
        if let cached = dayWorkouts[day] {
            exercises = cached.exercises
            notes = cached.notes
            print("📦 Loaded \(day.displayName) from memory cache")
            return
        }
        
        // Then check UserDefaults temp storage
        let dayKey = "tempWorkout_\(dateKey)_\(day.rawValue)"
        if let data = UserDefaults.standard.data(forKey: dayKey),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            if let savedNotes = UserDefaults.standard.string(forKey: "tempNotes_\(dateKey)_\(day.rawValue)") {
                notes = savedNotes
            }
            // Cache it
            dayWorkouts[day] = (exercises: exercises, notes: notes)
            print("📦 Loaded \(day.displayName) from temp storage")
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
    @State private var selectedExercise: ExerciseSelection?
    @State private var showingSavedWorkouts: Bool = false
    @State private var showingWorkoutSaved: Bool = false

    var exercises: [String] {
        switch dailyWorkout.day {
        case .leg:
            return [
                "Bulgarian Split Squat",
                "Leg Press",
                "Single-Leg Extension",
                "Hamstring Curl",
                "Standing Calf Raise",
                "Seated Calf Raise",
                "Box Jumps"
            ]
        case .push:
            return [
                "Bench Press",
                "Incline Bench",
                "Dips"
            ]
        case .pull:
            return [
                "Single-Arm Row",
                "Single-Arm Dumbbell Row",
                "Pull-Ups",
                "Lat Pulldown",
                "Dumbbell Curls"
            ]
        case .core:
            return [
                "Watkins Core Program",
                "Cable Crunches",
                "Hanging Knee Raises (Pike)"
            ]
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Global Rest Timers Section
                if timerManager.timer2min.isActive || timerManager.timer45sec.isActive {
                    Section("Active Timers") {
                        HStack(spacing: 16) {
                            if timerManager.timer2min.isActive {
                                VStack {
                                    Button(action: {
                                        timerManager.timer2min.stop()
                                    }) {
                                        VStack {
                                            Text("2 MIN")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            Text(timerManager.timer2min.formattedTime)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.blue)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    ProgressView(value: timerManager.timer2min.progress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                        .frame(height: 4)
                                }
                            }
                            
                            if timerManager.timer45sec.isActive {
                                VStack {
                                    Button(action: {
                                        timerManager.timer45sec.stop()
                                    }) {
                                        VStack {
                                            Text("45 SEC")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                            Text(timerManager.timer45sec.formattedTime)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(.orange)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    
                                    ProgressView(value: timerManager.timer45sec.progress)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .orange))
                                        .frame(height: 4)
                                }
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
                        Text(dailyWorkout.day.displayName)
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
                    Menu(dailyWorkout.day.displayName) {
                        ForEach(WorkoutDay.allCases, id: \.self) { option in
                            Button(option.displayName) {
                                dailyWorkout.updateDay(option)
                            }
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
        // Timer alerts on Today screen
        .alert("2-Minute Timer Finished!", isPresented: $timerManager.timer2min.isFinished) {
            Button("OK") {
                timerManager.timer2min.isFinished = false
            }
        } message: {
            Text("Your 2-minute rest period is complete!")
        }
        .alert("45-Second Timer Finished!", isPresented: $timerManager.timer45sec.isFinished) {
            Button("OK") {
                timerManager.timer45sec.isFinished = false
            }
        } message: {
            Text("Your 45-second rest period is complete!")
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}