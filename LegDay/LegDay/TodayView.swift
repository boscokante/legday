import SwiftUI
import CoreData
import Combine
import AudioToolbox
import UserNotifications

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
    private let timerKey: String
    
    // Store start time for background persistence
    private var startDate: Date? {
        get {
            guard let timeInterval = UserDefaults.standard.object(forKey: timerKey) as? TimeInterval else {
                return nil
            }
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            if let date = newValue {
                UserDefaults.standard.set(date.timeIntervalSince1970, forKey: timerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: timerKey)
            }
        }
    }
    
    init(seconds: Int, name: String, soundID: SystemSoundID = 1005, soundRepeatCount: Int = 1) {
        self.totalTime = seconds
        self.remainingTime = seconds
        self.timerName = name
        self.soundID = soundID
        self.soundRepeatCount = soundRepeatCount
        self.timerKey = "timer_start_\(name)"
        
        // Restore timer state on init
        restoreTimerState()
    }
    
    func start() {
        guard !isActive else { return }
        
        print("🚀 Starting timer: \(timerName)")
        isActive = true
        isFinished = false
        remainingTime = totalTime
        
        // Store start time
        startDate = Date()
        
        // Schedule local notification
        scheduleNotification()
        
        // Start UI timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateRemainingTime()
            }
        }
    }
    
    func stop() {
        print("⏹️ Stopping timer: \(timerName)")
        timer?.invalidate()
        timer = nil
        isActive = false
        remainingTime = totalTime
        
        // Clear stored start time
        startDate = nil
        
        // Cancel notification
        cancelNotification()
    }
    
    private func finish() {
        timer?.invalidate()
        timer = nil
        isActive = false
        isFinished = true
        
        // Clear stored start time
        startDate = nil
        
        // Cancel notification (already fired)
        cancelNotification()
        
        // Play sound multiple times if needed
        playSound(repeatCount: soundRepeatCount)
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    private func updateRemainingTime() {
        guard let start = startDate else {
            finish()
            return
        }
        
        let elapsed = Int(Date().timeIntervalSince(start))
        let newRemaining = totalTime - elapsed
        
        if newRemaining <= 0 {
            remainingTime = 0
            finish()
        } else {
            remainingTime = newRemaining
        }
    }
    
    private func restoreTimerState() {
        guard let start = startDate else {
            return
        }
        
        let elapsed = Int(Date().timeIntervalSince(start))
        let newRemaining = totalTime - elapsed
        
        if newRemaining <= 0 {
            // Timer already finished while app was backgrounded
            isActive = false
            isFinished = true
            remainingTime = 0
            startDate = nil
            cancelNotification()
        } else {
            // Timer still running
            isActive = true
            isFinished = false
            remainingTime = newRemaining
            
            // Restart UI timer
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.updateRemainingTime()
                }
            }
        }
    }
    
    func checkTimerState() {
        guard isActive else { return }
        updateRemainingTime()
    }
    
    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Timer Complete"
        content.body = "\(timerName) timer finished"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(totalTime), repeats: false)
        let request = UNNotificationRequest(identifier: timerKey, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timerKey])
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
    
    func checkAllTimers() {
        timer2min.checkTimerState()
        timer45sec.checkTimerState()
        timer30sec.checkTimerState()
    }
}

// WorkoutDay enum removed - now using WorkoutConfigManager

// Daily workout session model
class DailyWorkoutSession: ObservableObject {
    @Published var exercises: [String: [SetData]] = [:]
    @Published var dayId: String = ""
    @Published var dayName: String = ""
    @Published var secondaryDayId: String? = nil
    @Published var secondaryDayName: String? = nil
    @Published var notes: String = ""
    private let dateKey: String
    
    // Store in-progress workouts for each day separately
    private var dayWorkouts: [String: (exercises: [String: [SetData]], notes: String)] = [:]
    
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    
    // Singleton for auto-save access
    static let shared = DailyWorkoutSession()
    
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
        loadDualFocusState()
    }
    
    // MARK: - Dual Focus Support
    
    var combinedDayName: String {
        if let secondary = secondaryDayName {
            return "\(dayName) + \(secondary)"
        }
        return dayName
    }
    
    var allExercises: [String] {
        return configManager.getExercisesForDualFocus(primaryDayId: dayId, secondaryDayId: secondaryDayId)
    }
    
    func updateDualFocus(primaryId: String, secondaryId: String?) {
        // Save current day's work before switching
        saveCurrentDayToMemory()
        
        // Switch to new primary day
        dayId = primaryId
        if let dayConfig = configManager.getWorkoutDay(id: dayId) {
            dayName = dayConfig.name
        }
        
        // Set secondary day
        secondaryDayId = secondaryId
        if let secId = secondaryId, let secConfig = configManager.getWorkoutDay(id: secId) {
            secondaryDayName = secConfig.name
        } else {
            secondaryDayName = nil
        }
        
        // Load exercises from both focuses
        loadDayFromMemory()
        if let secId = secondaryDayId {
            loadSecondaryDayExercises(secId)
        }
        
        // Save the dual focus state
        saveDualFocusState()
        
        objectWillChange.send()
    }
    
    private func loadSecondaryDayExercises(_ secId: String) {
        // Load previous workout data for secondary day exercises
        let savedWorkouts = HistoryCodec.loadSavedWorkouts()
        let secondaryExercises = configManager.getExercisesForDay(dayId: secId)
        
        let sortedWorkouts = savedWorkouts
            .compactMap { workout -> (date: Date, data: [String: Any])? in
                guard let timestamp = workout["date"] as? TimeInterval else { return nil }
                let date = Date(timeIntervalSince1970: timestamp)
                guard !Calendar.current.isDateInToday(date) else { return nil }
                return (date, workout)
            }
            .sorted { $0.date > $1.date }
        
        for exerciseName in secondaryExercises {
            // Skip if already loaded
            guard exercises[exerciseName] == nil else { continue }
            
            for (date, workout) in sortedWorkouts {
                if let exercisesData = workout["exercises"] as? [String: [[String: Any]]],
                   let setsArray = exercisesData[exerciseName],
                   !setsArray.isEmpty {
                    let sets = setsArray.compactMap { setDict -> SetData? in
                        guard let weight = setDict["weight"] as? Double,
                              let reps = setDict["reps"] as? Int,
                              let warmup = setDict["warmup"] as? Bool else { return nil }
                        let minutes = setDict["minutes"] as? Int
                        let seconds = setDict["seconds"] as? Int
                        let shotsMade = setDict["shotsMade"] as? Int
                        return SetData(weight: weight, reps: reps, warmup: warmup, completed: false, minutes: minutes, seconds: seconds, shotsMade: shotsMade)
                    }
                    if !sets.isEmpty {
                        exercises[exerciseName] = sets
                        print("📦 Loaded secondary exercise \(exerciseName) from \(date.formatted(date: .abbreviated, time: .omitted))")
                        break
                    }
                }
            }
        }
    }
    
    private func saveDualFocusState() {
        UserDefaults.standard.set(dayId, forKey: "dualFocus_primary_\(dateKey)")
        if let secId = secondaryDayId {
            UserDefaults.standard.set(secId, forKey: "dualFocus_secondary_\(dateKey)")
        } else {
            UserDefaults.standard.removeObject(forKey: "dualFocus_secondary_\(dateKey)")
        }
    }
    
    private func loadDualFocusState() {
        if let savedSecondary = UserDefaults.standard.string(forKey: "dualFocus_secondary_\(dateKey)") {
            secondaryDayId = savedSecondary
            if let secConfig = configManager.getWorkoutDay(id: savedSecondary) {
                secondaryDayName = secConfig.name
            }
        }
    }
    
    func addSet(to exercise: String, set: SetData) {
        if exercises[exercise] == nil {
            exercises[exercise] = []
        }
        exercises[exercise]?.append(set)
        saveTodaysWorkout()
    }
    
    func updateSet(exercise: String, index: Int, weight: Double, reps: Int, warmup: Bool, completed: Bool, minutes: Int = 0, seconds: Int = 0, shotsMade: Int = 0) {
        guard exercises[exercise] != nil && index < exercises[exercise]!.count else { return }
        
        exercises[exercise]![index].weight = weight
        exercises[exercise]![index].reps = reps
        exercises[exercise]![index].warmup = warmup
        
        // Preserve time values if either is set (including 0)
        let dataType = ExerciseDataType.type(for: exercise)
        if dataType == .time {
            exercises[exercise]![index].minutes = minutes
            exercises[exercise]![index].seconds = seconds
        } else {
            exercises[exercise]![index].minutes = nil
            exercises[exercise]![index].seconds = nil
        }
        
        // Preserve shots if it's a shots exercise
        if dataType == .shots {
            exercises[exercise]![index].shotsMade = shotsMade
        } else {
            exercises[exercise]![index].shotsMade = nil
        }
        let wasCompleted = exercises[exercise]![index].completed
        exercises[exercise]![index].completed = completed
        
        // Set completion date when marking as completed (or clear it if unchecking)
        if completed && !wasCompleted {
            exercises[exercise]![index].completionDate = Date()
        } else if !completed {
            exercises[exercise]![index].completionDate = nil
        }
        
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
        
        // Collect all completion dates to determine workout date
        var allCompletionDates: [Date] = []
        
        // First pass: collect all completion dates from all days
        if !exercises.isEmpty {
            for (_, sets) in exercises {
                for set in sets where set.completed {
                    if let completionDate = set.completionDate {
                        allCompletionDates.append(completionDate)
                    }
                }
            }
        }
        
        for (_, data) in dayWorkouts {
            for (_, sets) in data.exercises {
                for set in sets where set.completed {
                    if let completionDate = set.completionDate {
                        allCompletionDates.append(completionDate)
                    }
                }
            }
        }
        
        // Use earliest completion date if available, otherwise use current date
        let workoutDate: Date
        if let earliestDate = allCompletionDates.min() {
            workoutDate = earliestDate
            print("📅 Using earliest completion date: \(earliestDate)")
        } else {
            workoutDate = Date()
            print("⚠️ No completion dates found, using current date")
        }
        
        // Now create separate entries for each workout day
        var workoutsToSave: [[String: Any]] = []
        var daysWorked: Set<String> = []
        
        // Process current day
        if !exercises.isEmpty {
            var dayExercises: [String: [[String: Any]]] = [:]
            for (exerciseName, sets) in exercises {
                let completedSets = sets.filter { $0.completed }
                if !completedSets.isEmpty {
                    dayExercises[exerciseName] = completedSets.map { set in
                        var setDict: [String: Any] = ["weight": set.weight, "reps": set.reps, "warmup": set.warmup]
                        if let minutes = set.minutes {
                            setDict["minutes"] = minutes
                        }
                        if let seconds = set.seconds {
                            setDict["seconds"] = seconds
                        }
                        if let shotsMade = set.shotsMade {
                            setDict["shotsMade"] = shotsMade
                        }
                        return setDict
                    }
                }
            }
            
            if !dayExercises.isEmpty {
                daysWorked.insert(dayName)
                let workoutData: [String: Any] = [
                    "date": workoutDate.timeIntervalSince1970,
                    "exercises": dayExercises,
                    "notes": notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    "day": dayName
                ]
                workoutsToSave.append(workoutData)
            }
        }
        
        // Process other days from memory cache
        for (workoutDayId, data) in dayWorkouts where workoutDayId != dayId {
            if !data.exercises.isEmpty {
                var dayExercises: [String: [[String: Any]]] = [:]
                for (exerciseName, sets) in data.exercises {
                    let completedSets = sets.filter { $0.completed }
                    if !completedSets.isEmpty {
                        dayExercises[exerciseName] = completedSets.map { set in
                            var setDict: [String: Any] = ["weight": set.weight, "reps": set.reps, "warmup": set.warmup]
                            if let minutes = set.minutes {
                                setDict["minutes"] = minutes
                            }
                            if let seconds = set.seconds {
                                setDict["seconds"] = seconds
                            }
                            if let shotsMade = set.shotsMade {
                                setDict["shotsMade"] = shotsMade
                            }
                            return setDict
                        }
                    }
                }
                
                if !dayExercises.isEmpty {
                    if let dayConfig = configManager.getWorkoutDay(id: workoutDayId) {
                        daysWorked.insert(dayConfig.name)
                        let workoutData: [String: Any] = [
                            "date": workoutDate.timeIntervalSince1970,
                            "exercises": dayExercises,
                            "notes": data.notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            "day": dayConfig.name
                        ]
                        workoutsToSave.append(workoutData)
                    }
                }
            }
        }
        
        guard !workoutsToSave.isEmpty else {
            print("⚠️ No completed exercises to save")
            return
        }
        
        var savedWorkouts = HistoryCodec.loadSavedWorkouts()
        
        // Remove existing workouts from the same date that match the days we're saving
        // This prevents duplicates when re-saving
        savedWorkouts.removeAll { workout in
            if let date = workout["date"] as? TimeInterval,
               Calendar.current.isDate(Date(timeIntervalSince1970: date), inSameDayAs: workoutDate),
               let existingDay = workout["day"] as? String {
                return daysWorked.contains(existingDay)
            }
            return false
        }
        
        // Append all new workout entries
        savedWorkouts.append(contentsOf: workoutsToSave)
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: savedWorkouts) {
            UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
        }
        
        // Clear temp storage after successful save
        clearTempStorage()
        dayWorkouts.removeAll()
        
        // Clear notes after saving
        notes = ""
        saveTodaysWorkout()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        let daysList = daysWorked.sorted().joined(separator: ", ")
        print("=== WORKOUT SAVED: \(daysList) on \(dateFormatter.string(from: workoutDate)) ===")
        for workout in workoutsToSave {
            if let day = workout["day"] as? String, let exercises = workout["exercises"] as? [String: [[String: Any]]] {
                print("  - \(day): \(exercises.count) exercises")
                for (exercise, sets) in exercises {
                    if let setArray = sets as? [[String: Any]] {
                        print("    \(exercise): \(setArray.count) sets")
                    }
                }
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
        // Save to day-specific temp storage (for switching days)
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: dayKey)
        }
        UserDefaults.standard.set(notes, forKey: "tempNotes_\(dateKey)_\(dayId)")
        
        // Also save to shared storage for backward compatibility
        if let encoded = try? encoder.encode(exercises) {
            UserDefaults.standard.set(encoded, forKey: "workout_\(dateKey)")
        }
        UserDefaults.standard.set(dayId, forKey: "workoutDay_\(dateKey)")
        
        // Update memory cache
        dayWorkouts[dayId] = (exercises: exercises, notes: notes)
    }
    
    private func loadTodaysWorkout() {
        // Load dayId first to know which day we're loading
        if let savedDayId = UserDefaults.standard.string(forKey: "workoutDay_\(dateKey)") {
            dayId = savedDayId
            if let dayConfig = configManager.getWorkoutDay(id: dayId) {
                dayName = dayConfig.name
            }
        }
        
        // First try to load today's workout for this day from temp storage
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        if let data = UserDefaults.standard.data(forKey: dayKey),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            // Load notes from temp storage if they exist (user typed them today for this day)
            if let savedNotes = UserDefaults.standard.string(forKey: "tempNotes_\(dateKey)_\(dayId)") {
                notes = savedNotes
            } else {
                notes = ""
            }
            // Cache it
            dayWorkouts[dayId] = (exercises: exercises, notes: notes)
            print("📅 Loaded existing workout for \(dayName) on \(dateKey)")
            return
        }
        
        // Fallback: try to load from old shared storage (for backward compatibility)
        if let data = UserDefaults.standard.data(forKey: "workout_\(dateKey)"),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            print("📅 Loaded existing workout for \(dateKey)")
            // Notes start empty - old storage didn't have day-specific notes
            notes = ""
        } else {
            // If no workout for today, prefill with previous workout
            loadPreviousWorkout()
            // Notes start empty for new day
            notes = ""
        }
    }
    
    private func loadPreviousWorkout() {
        let savedWorkouts = HistoryCodec.loadSavedWorkouts()
        guard !savedWorkouts.isEmpty else {
            print("📭 No previous workouts found")
            return
        }
        
        // Get all exercises configured for the current day
        let dayExercises = configManager.getExercisesForDay(dayId: dayId)
        guard !dayExercises.isEmpty else {
            print("📭 No exercises configured for \(dayName)")
            return
        }
        
        // Sort all workouts by date (most recent first) and exclude today
        let sortedWorkouts = savedWorkouts
            .compactMap { workout -> (date: Date, data: [String: Any])? in
                guard let timestamp = workout["date"] as? TimeInterval else { return nil }
                let date = Date(timeIntervalSince1970: timestamp)
                // Skip if it's today
                guard !Calendar.current.isDateInToday(date) else { return nil }
                return (date, workout)
            }
            .sorted { $0.date > $1.date }
        
        // For each exercise in the current day, find its most recent completion across all workouts
        var loadedExercises: [String: [SetData]] = [:]
        var loadedExercisesDates: [String: Date] = [:]  // Track when each exercise was loaded from
        
        for exerciseName in dayExercises {
            // Search through all workouts (most recent first) to find this exercise
            for (date, workout) in sortedWorkouts {
                if let exercisesData = workout["exercises"] as? [String: [[String: Any]]],
                   let setsArray = exercisesData[exerciseName],
                   !setsArray.isEmpty {
                    // Found this exercise - load its sets
                    let sets = setsArray.compactMap { setDict -> SetData? in
                        guard let weight = setDict["weight"] as? Double,
                              let reps = setDict["reps"] as? Int,
                              let warmup = setDict["warmup"] as? Bool else {
                            return nil
                        }
                        // Load sets as UNCOMMITTED - user must check them off as they complete them
                        let minutes = setDict["minutes"] as? Int
                        let seconds = setDict["seconds"] as? Int
                        let shotsMade = setDict["shotsMade"] as? Int
                        return SetData(weight: weight, reps: reps, warmup: warmup, completed: false, minutes: minutes, seconds: seconds, shotsMade: shotsMade)
                    }
                    if !sets.isEmpty {
                        loadedExercises[exerciseName] = sets
                        loadedExercisesDates[exerciseName] = date
                        print("📦 Loaded \(exerciseName) from \(date.formatted(date: .abbreviated, time: .omitted))")
                        break  // Found most recent completion, move to next exercise
                    }
                }
            }
        }
        
        if !loadedExercises.isEmpty {
            exercises = loadedExercises
            // Notes start empty - don't load from previous workouts
            
            // Save as today's starting point
            saveTodaysWorkout()
            
            let loadedCount = loadedExercises.count
            let totalSets = getTotalSets()
            print("✅ Loaded \(loadedCount)/\(dayExercises.count) exercises with \(totalSets) total sets")
        } else {
            print("📭 No previous completions found for exercises in \(dayName)")
        }
    }
    
    func clearTodaysWorkout() {
        exercises.removeAll()
        notes = ""
        // Clear day-specific temp storage
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        UserDefaults.standard.removeObject(forKey: dayKey)
        UserDefaults.standard.removeObject(forKey: "tempNotes_\(dateKey)_\(dayId)")
        // Clear shared storage
        UserDefaults.standard.removeObject(forKey: "workout_\(dateKey)")
        UserDefaults.standard.removeObject(forKey: "workoutNotes_\(dateKey)")
        UserDefaults.standard.removeObject(forKey: "workoutDay_\(dateKey)")
        // Clear memory cache
        dayWorkouts.removeValue(forKey: dayId)
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
            notes = cached.notes  // Restore notes from cache (persist during same day)
            print("📦 Loaded \(dayName) from memory cache")
            return
        }
        
        // Then check UserDefaults temp storage
        let dayKey = "tempWorkout_\(dateKey)_\(dayId)"
        if let data = UserDefaults.standard.data(forKey: dayKey),
           let decoded = try? JSONDecoder().decode([String: [SetData]].self, from: data) {
            exercises = decoded
            // Load notes from temp storage if they exist (persist during same day)
            if let savedNotes = UserDefaults.standard.string(forKey: "tempNotes_\(dateKey)_\(dayId)") {
                notes = savedNotes
            } else {
                notes = ""
            }
            // Cache it
            dayWorkouts[dayId] = (exercises: exercises, notes: notes)
            print("📦 Loaded \(dayName) from temp storage")
            return
        }
        
        // Finally, try to load from previous workout for this day
        exercises.removeAll()
        notes = ""  // Start empty for first time opening this day
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
    @EnvironmentObject var voiceAgent: VoiceAgentStore
    @StateObject private var dailyWorkout = DailyWorkoutSession.shared
    @ObservedObject private var timerManager = TimerManager.shared
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    @State private var selectedExercise: ExerciseSelection?
    @State private var showingSavedWorkouts: Bool = false
    @State private var showingWorkoutSaved: Bool = false
    @State private var showingAddExercise = false
    @State private var addingToSecondaryLane = false  // Track which lane we're adding to
    @State private var newExerciseName = ""
    @State private var confirmRestoreDefaults = false
    @State private var isEditingPrimaryOrder = false
    @State private var isEditingSecondaryOrder = false

    var primaryExercises: [String] {
        return configManager.getExercisesForDay(dayId: dailyWorkout.dayId)
    }
    
    var secondaryExercises: [String] {
        guard let secId = dailyWorkout.secondaryDayId else { return [] }
        return configManager.getExercisesForDay(dayId: secId)
    }
    
    private func addExerciseToLane(_ exerciseName: String, isSecondary: Bool) {
        let configManager = WorkoutConfigManager.shared
        
        // Add to master exercise list if not already there
        configManager.addExercise(name: exerciseName)
        
        // Determine target day
        let targetDayId = isSecondary ? (dailyWorkout.secondaryDayId ?? dailyWorkout.dayId) : dailyWorkout.dayId
        
        // Add to target day's exercise list
        if let targetDay = configManager.getWorkoutDay(id: targetDayId) {
            var updatedExercises = targetDay.exercises
            if !updatedExercises.contains(exerciseName) {
                updatedExercises.append(exerciseName)
                configManager.updateWorkoutDay(
                    id: targetDayId,
                    name: targetDay.name,
                    exercises: updatedExercises
                )
            }
        }
        
        // Clear the input field
        newExerciseName = ""
    }
    
    private func removeExerciseFromLane(_ exerciseName: String, isSecondary: Bool) {
        let configManager = WorkoutConfigManager.shared
        
        let targetDayId = isSecondary ? (dailyWorkout.secondaryDayId ?? dailyWorkout.dayId) : dailyWorkout.dayId
        
        // Remove from the appropriate day's exercise list
        if let targetDay = configManager.getWorkoutDay(id: targetDayId) {
            var updatedExercises = targetDay.exercises
            updatedExercises.removeAll { $0 == exerciseName }
            configManager.updateWorkoutDay(
                id: targetDayId,
                name: targetDay.name,
                exercises: updatedExercises
            )
        }
        
        // Also remove any sets for this exercise from the current workout
        dailyWorkout.exercises.removeValue(forKey: exerciseName)
    }
    
    private func movePrimaryExercise(from source: IndexSet, to destination: Int) {
        let configManager = WorkoutConfigManager.shared
        var exercises = primaryExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        
        if let currentDay = configManager.getWorkoutDay(id: dailyWorkout.dayId) {
            configManager.updateWorkoutDay(
                id: dailyWorkout.dayId,
                name: currentDay.name,
                exercises: exercises
            )
        }
    }
    
    private func moveSecondaryExercise(from source: IndexSet, to destination: Int) {
        guard let secId = dailyWorkout.secondaryDayId else { return }
        let configManager = WorkoutConfigManager.shared
        var exercises = secondaryExercises
        exercises.move(fromOffsets: source, toOffset: destination)
        
        if let secondaryDay = configManager.getWorkoutDay(id: secId) {
            configManager.updateWorkoutDay(
                id: secId,
                name: secondaryDay.name,
                exercises: exercises
            )
        }
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
                
                // MARK: - Primary Lane
                Section(header: HStack {
                    Menu {
                        ForEach(configManager.workoutDays, id: \.id) { dayConfig in
                            Button(dayConfig.name) {
                                dailyWorkout.updateDay(dayConfig.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(dailyWorkout.dayName)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button(isEditingPrimaryOrder ? "Done" : "Reorder") {
                        withAnimation { isEditingPrimaryOrder.toggle() }
                    }
                    .font(.caption2)
                    .foregroundStyle(.blue)
                }) {
                    ForEach(primaryExercises, id: \.self) { exercise in
                        HStack {
                            if isEditingPrimaryOrder {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 4)
                            }
                            
                            Button(exercise) {
                                if !isEditingPrimaryOrder {
                                    selectedExercise = ExerciseSelection(name: exercise)
                                }
                            }
                            .foregroundStyle(.primary)
                            .disabled(isEditingPrimaryOrder)
                            
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
                                removeExerciseFromLane(exercise, isSecondary: false)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: movePrimaryExercise)
                    
                    Button(action: {
                        addingToSecondaryLane = false
                        showingAddExercise = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercise")
                        }
                        .foregroundColor(.blue)
                    }
                }
                .environment(\.editMode, .constant(isEditingPrimaryOrder ? .active : .inactive))
                
                // MARK: - Secondary Lane
                Section(header: HStack {
                    Menu {
                        Button("None") {
                            dailyWorkout.updateDualFocus(primaryId: dailyWorkout.dayId, secondaryId: nil)
                        }
                        Divider()
                        ForEach(configManager.workoutDays.filter { $0.id != dailyWorkout.dayId }, id: \.id) { dayConfig in
                            Button(dayConfig.name) {
                                dailyWorkout.updateDualFocus(primaryId: dailyWorkout.dayId, secondaryId: dayConfig.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(dailyWorkout.secondaryDayName ?? "Add Secondary")
                                .font(.headline)
                                .foregroundStyle(dailyWorkout.secondaryDayId != nil ? .primary : .secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if dailyWorkout.secondaryDayId != nil {
                        Button(isEditingSecondaryOrder ? "Done" : "Reorder") {
                            withAnimation { isEditingSecondaryOrder.toggle() }
                        }
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    }
                }) {
                    if dailyWorkout.secondaryDayId != nil {
                        ForEach(secondaryExercises, id: \.self) { exercise in
                            HStack {
                                if isEditingSecondaryOrder {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 4)
                                }
                                
                                Button(exercise) {
                                    if !isEditingSecondaryOrder {
                                        selectedExercise = ExerciseSelection(name: exercise)
                                    }
                                }
                                .foregroundStyle(.primary)
                                .disabled(isEditingSecondaryOrder)
                                
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
                                    removeExerciseFromLane(exercise, isSecondary: true)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveSecondaryExercise)
                        
                        Button(action: {
                            addingToSecondaryLane = true
                            showingAddExercise = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .foregroundColor(.blue)
                        }
                    } else {
                        Text("Select a secondary workout type above")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .environment(\.editMode, .constant(isEditingSecondaryOrder ? .active : .inactive))
                
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
                        Text("Today's Workout")
                            .font(.system(size: 24, weight: .heavy))
                            .foregroundStyle(.primary)
                        Text(Date().formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: ChatView().environmentObject(voiceAgent)) {
                        Image(systemName: "message.fill")
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Restore default exercises") {
                            confirmRestoreDefaults = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
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
                    addExerciseToLane(exerciseName, isSecondary: addingToSecondaryLane)
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
        .onAppear {
            setupVoiceAgentHooks()
        }
    }
    
    private func setupVoiceAgentHooks() {
        // Set up navigation handler
        voiceAgent.intentRouter.setNavigationHandler { [weak dailyWorkout] destination, argument in
            Task { @MainActor in
                switch destination {
                case "today":
                    // Already on today view
                    break
                case "templates":
                    // Would navigate to templates - for now just log
                    print("Navigate to templates: \(argument ?? "")")
                default:
                    print("Navigate to \(destination): \(argument ?? "")")
                }
            }
        }
        
        // Set up exercise selection handler
        voiceAgent.intentRouter.setExerciseSelectionHandler { exerciseName in
            Task { @MainActor in
                self.selectedExercise = ExerciseSelection(name: exerciseName)
            }
        }
        
        // Set up log set handler
        voiceAgent.intentRouter.setLogSetHandler { [weak dailyWorkout] exercise, reps, weight, rpe, notes in
            Task { @MainActor in
                guard let dailyWorkout = dailyWorkout else { return }
                
                // Find or create sets for this exercise
                var sets = dailyWorkout.getSets(for: exercise)
                
                // Check if there's an incomplete set to update
                if let lastSetIndex = sets.lastIndex(where: { !$0.completed }) {
                    // Update existing incomplete set
                    let dataType = ExerciseDataType.type(for: exercise)
                    dailyWorkout.updateSet(
                        exercise: exercise,
                        index: lastSetIndex,
                        weight: weight,
                        reps: reps,
                        warmup: false,
                        completed: true,
                        minutes: dataType == .time ? sets[lastSetIndex].minutes ?? 0 : 0,
                        seconds: dataType == .time ? sets[lastSetIndex].seconds ?? 0 : 0,
                        shotsMade: dataType == .shots ? sets[lastSetIndex].shotsMade ?? 0 : 0
                    )
                } else {
                    // Create new set
                    let dataType = ExerciseDataType.type(for: exercise)
                    let newSet: SetData
                    switch dataType {
                    case .time:
                        newSet = SetData(weight: 0, reps: 0, warmup: false, completed: true, minutes: 0, seconds: 0)
                    case .shots:
                        newSet = SetData(weight: 0, reps: 0, warmup: false, completed: true, shotsMade: 0)
                    case .count:
                        newSet = SetData(weight: 0, reps: reps, warmup: false, completed: true)
                    case .weightReps:
                        newSet = SetData(weight: weight, reps: reps, warmup: false, completed: true)
                    }
                    dailyWorkout.addSet(to: exercise, set: newSet)
                }
            }
        }
        
        // Set up undo handler
        voiceAgent.intentRouter.setUndoSetHandler { [weak dailyWorkout] exerciseName in
            Task { @MainActor in
                guard let dailyWorkout = dailyWorkout else { return }
                
                if let exerciseName = exerciseName {
                    // Undo last set for specific exercise
                    var sets = dailyWorkout.getSets(for: exerciseName)
                    if let lastIndex = sets.lastIndex(where: { $0.completed }) {
                        dailyWorkout.removeSet(from: exerciseName, at: lastIndex)
                    }
                } else {
                    // Undo last set from any exercise
                    var lastExercise: String?
                    var lastIndex: Int?
                    var lastDate: Date?
                    
                    for (exName, sets) in dailyWorkout.exercises {
                        for (index, set) in sets.enumerated() {
                            if set.completed, let completionDate = set.completionDate {
                                if lastDate == nil || completionDate > lastDate! {
                                    lastExercise = exName
                                    lastIndex = index
                                    lastDate = completionDate
                                }
                            }
                        }
                    }
                    
                    if let exercise = lastExercise, let index = lastIndex {
                        dailyWorkout.removeSet(from: exercise, at: index)
                    }
                }
            }
        }
        
        // Wire up services
        voiceAgent.intentRouter.setDailyWorkout(dailyWorkout)
        voiceAgent.intentRouter.setWeightService(voiceAgent.weightRecommendationService)
        voiceAgent.intentRouter.setHistoryProvider(voiceAgent.historySummaryProvider)
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