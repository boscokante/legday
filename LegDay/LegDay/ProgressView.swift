import SwiftUI
import Charts

enum ViewMode: String, CaseIterable {
    case exercise = "Exercise"
    case day = "Workout Day"
}

struct ProgressViewGlobal: View {
    @State private var workouts: [[String: Any]] = []
    @State private var selectedExercise: String = "Bulgarian Split Squat"
    @State private var selectedDay: String = "Leg Day"
    @State private var viewMode: ViewMode = .exercise
    @ObservedObject private var configManager = WorkoutConfigManager.shared
    
    let exerciseOptions = [
        "Bulgarian Split Squat", "Leg Press", "Bench Press", "Incline Bench",
        "Single-Arm Row", "Pull-Ups", "Lat Pulldown", "Seated Calf Raise", "Dips"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // View Mode Picker
                    Picker("View By", selection: $viewMode) {
                        ForEach(ViewMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewMode == .exercise {
                        // Exercise Picker
                        Picker("Exercise", selection: $selectedExercise) {
                            ForEach(exerciseOptions, id: \.self) { exercise in
                                Text(exercise).tag(exercise)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        
                        // Stats Cards
                        statsCardsView
                        
                        // Volume Progression Chart
                        volumeChartView
                        
                        // Consistency Heatmap
                        consistencyHeatmapView
                    } else {
                        // Day Picker
                        Picker("Workout Day", selection: $selectedDay) {
                            ForEach(configManager.workoutDays, id: \.id) { day in
                                Text(day.name).tag(day.name)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                        
                        // Day Stats Cards
                        dayStatsCardsView
                        
                        // Day Consistency Heatmap
                        dayConsistencyHeatmapView
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Progress")
            .onAppear(perform: loadData)
        }
    }
    
    private var statsCardsView: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Max Weight",
                value: "\(Int(maxWeight)) lbs",
                subtitle: maxWeightDate,
                color: .blue
            )
            
            StatCard(
                title: "Total Volume",
                value: formatVolume(totalVolume),
                subtitle: "Last 30 days",
                color: .green
            )
            
            StatCard(
                title: "Workouts",
                value: "\(workoutCount)",
                subtitle: "Last 30 days",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var volumeChartView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Volume Progression")
                .font(.headline)
                .padding(.horizontal)
            
            if volumeData.isEmpty {
                Text("No data for \(selectedExercise)")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(volumeData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", item.date),
                        y: .value("Volume", item.volume)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 200)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var consistencyHeatmapView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consistency (Last 90 Days)")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 13), spacing: 4) {
                ForEach(heatmapData, id: \.date) { day in
                    Rectangle()
                        .fill(day.hasWorkout ? Color.blue.opacity(0.2 + (day.intensity * 0.8)) : Color(.systemGray5))
                        .frame(height: 20)
                        .cornerRadius(3)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Data Processing
    
    private func loadData() {
        workouts = HistoryCodec.loadSavedWorkouts()
    }
    
    private var maxWeight: Double {
        var max: Double = 0
        for workout in workouts {
            if let exercises = workout["exercises"] as? [String: [[String: Any]]],
               let sets = exercises[selectedExercise] {
                for set in sets {
                    if let weight = set["weight"] as? Double,
                       let warmup = set["warmup"] as? Bool,
                       !warmup {
                        max = Swift.max(max, weight)
                    }
                }
            }
        }
        return max
    }
    
    private var maxWeightDate: String {
        var maxWeight: Double = 0
        var maxDate: Date?
        
        for workout in workouts {
            if let timestamp = workout["date"] as? TimeInterval,
               let exercises = workout["exercises"] as? [String: [[String: Any]]],
               let sets = exercises[selectedExercise] {
                for set in sets {
                    if let weight = set["weight"] as? Double,
                       let warmup = set["warmup"] as? Bool,
                       !warmup, weight > maxWeight {
                        maxWeight = weight
                        maxDate = Date(timeIntervalSince1970: timestamp)
                    }
                }
            }
        }
        
        if let date = maxDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
        return "—"
    }
    
    private var totalVolume: Double {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        var volume: Double = 0
        
        for workout in workouts {
            if let timestamp = workout["date"] as? TimeInterval,
               Date(timeIntervalSince1970: timestamp) >= thirtyDaysAgo,
               let exercises = workout["exercises"] as? [String: [[String: Any]]],
               let sets = exercises[selectedExercise] {
                for set in sets {
                    if let weight = set["weight"] as? Double,
                       let reps = set["reps"] as? Int,
                       let warmup = set["warmup"] as? Bool,
                       !warmup {
                        volume += weight * Double(reps)
                    }
                }
            }
        }
        return volume
    }
    
    private var workoutCount: Int {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return workouts.filter { workout in
            if let timestamp = workout["date"] as? TimeInterval,
               Date(timeIntervalSince1970: timestamp) >= thirtyDaysAgo,
               let exercises = workout["exercises"] as? [String: [[String: Any]]],
               exercises[selectedExercise] != nil {
                return true
            }
            return false
        }.count
    }
    
    private var volumeData: [VolumeDataPoint] {
        var dataPoints: [VolumeDataPoint] = []
        
        for workout in workouts {
            if let timestamp = workout["date"] as? TimeInterval,
               let exercises = workout["exercises"] as? [String: [[String: Any]]],
               let sets = exercises[selectedExercise] {
                var workoutVolume: Double = 0
                for set in sets {
                    if let weight = set["weight"] as? Double,
                       let reps = set["reps"] as? Int,
                       let warmup = set["warmup"] as? Bool,
                       !warmup {
                        workoutVolume += weight * Double(reps)
                    }
                }
                if workoutVolume > 0 {
                    dataPoints.append(VolumeDataPoint(
                        date: Date(timeIntervalSince1970: timestamp),
                        volume: workoutVolume
                    ))
                }
            }
        }
        
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    private var heatmapData: [HeatmapDay] {
        let ninetyDaysAgo = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        var days: [HeatmapDay] = []
        
        // Create all days in range
        var currentDate = ninetyDaysAgo
        while currentDate <= Date() {
            let hasWorkout = workouts.contains { workout in
                if let timestamp = workout["date"] as? TimeInterval {
                    return Calendar.current.isDate(Date(timeIntervalSince1970: timestamp), inSameDayAs: currentDate)
                }
                return false
            }
            
            // Calculate intensity based on total sets that day
            var intensity: Double = 0
            if hasWorkout {
                for workout in workouts {
                    if let timestamp = workout["date"] as? TimeInterval,
                       Calendar.current.isDate(Date(timeIntervalSince1970: timestamp), inSameDayAs: currentDate),
                       let exercises = workout["exercises"] as? [String: [[String: Any]]] {
                        let totalSets = exercises.values.reduce(0) { $0 + $1.count }
                        intensity = min(1.0, Double(totalSets) / 30.0) // Normalize to 0-1
                    }
                }
            }
            
            days.append(HeatmapDay(date: currentDate, hasWorkout: hasWorkout, intensity: intensity))
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk", volume / 1000)
        }
        return String(format: "%.0f", volume)
    }
}

struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

struct HeatmapDay {
    let date: Date
    let hasWorkout: Bool
    let intensity: Double
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Day Level Statistics

extension ProgressViewGlobal {
    private var dayStatsCardsView: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Times Completed",
                value: "\(dayWorkoutCount)",
                subtitle: "Last 30 days",
                color: .green
            )
            
            StatCard(
                title: "Total Volume",
                value: formatVolume(dayTotalVolume),
                subtitle: "Last 30 days",
                color: .blue
            )
            
            StatCard(
                title: "Consistency",
                value: "\(Int(dayConsistency * 100))%",
                subtitle: "Last 30 days",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var dayConsistencyHeatmapView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Consistency - \(selectedDay)")
                .font(.headline)
                .padding(.horizontal)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(dayHeatmapData, id: \.date) { day in
                    Rectangle()
                        .fill(day.hasWorkout ? (day.intensity > 0.7 ? Color.green : Color.blue) : Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
            
            HStack {
                Text("Less")
                Spacer()
                Text("More")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var dayWorkoutCount: Int {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { workout in
            guard let timestamp = workout["date"] as? TimeInterval,
                  let day = workout["day"] as? String else { return false }
            let workoutDate = Date(timeIntervalSince1970: timestamp)
            return workoutDate >= thirtyDaysAgo && day == selectedDay
        }.count
    }
    
    private var dayTotalVolume: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return workouts.filter { workout in
            guard let timestamp = workout["date"] as? TimeInterval,
                  let day = workout["day"] as? String else { return false }
            let workoutDate = Date(timeIntervalSince1970: timestamp)
            return workoutDate >= thirtyDaysAgo && day == selectedDay
        }.compactMap { workout in
            guard let exercises = workout["exercises"] as? [String: [[String: Any]]] else { return 0.0 }
            return exercises.values.flatMap { $0 }.compactMap { set in
                guard let weight = set["weight"] as? Double,
                      let reps = set["reps"] as? Int else { return 0.0 }
                return weight * Double(reps)
            }.reduce(0, +)
        }.reduce(0, +)
    }
    
    private var dayConsistency: Double {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let totalDays = 30
        let workoutDays = Set<Date>(workouts.filter { workout in
            guard let timestamp = workout["date"] as? TimeInterval,
                  let day = workout["day"] as? String else { return false }
            let workoutDate = Date(timeIntervalSince1970: timestamp)
            return workoutDate >= thirtyDaysAgo && day == selectedDay
        }.compactMap { workout in
            guard let timestamp = workout["date"] as? TimeInterval else { return nil }
            return Calendar.current.startOfDay(for: Date(timeIntervalSince1970: timestamp))
        })
        
        return Double(workoutDays.count) / Double(totalDays)
    }
    
    private var dayHeatmapData: [HeatmapDay] {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        
        var days: [HeatmapDay] = []
        for i in 0..<30 {
            guard let date = calendar.date(byAdding: .day, value: i, to: thirtyDaysAgo) else { continue }
            
            let dayWorkouts = workouts.filter { workout in
                guard let timestamp = workout["date"] as? TimeInterval,
                      let day = workout["day"] as? String else { return false }
                let workoutDate = Date(timeIntervalSince1970: timestamp)
                return calendar.isDate(workoutDate, inSameDayAs: date) && day == selectedDay
            }
            
            let hasWorkout = !dayWorkouts.isEmpty
            let intensity = dayWorkouts.isEmpty ? 0.0 : min(1.0, Double(dayWorkouts.count) / 3.0) // Normalize to 0-1
            
            days.append(HeatmapDay(date: date, hasWorkout: hasWorkout, intensity: intensity))
        }
        
        return days
    }
}

struct ProgressViewGlobal_Previews: PreviewProvider {
    static var previews: some View {
        ProgressViewGlobal()
    }
}