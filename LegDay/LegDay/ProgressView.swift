import SwiftUI
import Charts

struct ProgressViewGlobal: View {
    @State private var workouts: [[String: Any]] = []
    @State private var selectedExercise: String = "Bulgarian Split Squat"
    
    let exerciseOptions = [
        "Bulgarian Split Squat", "Leg Press", "Bench Press", "Incline Bench",
        "Single-Arm Row", "Pull-Ups", "Lat Pulldown", "Seated Calf Raise", "Dips"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
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

struct ProgressViewGlobal_Previews: PreviewProvider {
    static var previews: some View {
        ProgressViewGlobal()
    }
}