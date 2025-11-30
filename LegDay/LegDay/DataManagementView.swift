import SwiftUI
import UniformTypeIdentifiers

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct DataManagementView: View {
    @State private var showingImportPicker = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSplitSuccess = false
    @State private var exportFileURL: URL?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Backup and restore your workout history, metrics, and app data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Export Data") {
                    Button(action: exportData) {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                    }
                    
                    Text("Creates a .legday file with all your workouts, metrics, and settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Import Data") {
                    Button(action: { showingImportPicker = true }) {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                    }
                    
                    Text("Restores data from a .legday backup file. This will merge with existing data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("Current Data") {
                    let workoutCount = HistoryCodec.loadSavedWorkouts().count
                    HStack {
                        Text("Workouts")
                        Spacer()
                        Text("\(workoutCount)")
                            .foregroundStyle(.secondary)
                    }
                    
                    let metricsCount = loadMetricsCount()
                    HStack {
                        Text("Body Metrics")
                        Spacer()
                        Text("\(metricsCount)")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Utilities") {
                    Button(action: splitCombinedWorkouts) {
                        Label("Split Combined Workouts", systemImage: "scissors")
                    }
                    
                    Text("Fixes old history where multiple workout days were combined into one entry. Creates separate entries for each day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Data Management")
        }
        .sheet(item: $exportFileURL) { url in
            ShareSheet(activityItems: [url])
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json, .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Import Successful", isPresented: $showingImportSuccess) {
            Button("OK") { }
        } message: {
            Text("Your workout data has been imported successfully!")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Workouts Split", isPresented: $showingSplitSuccess) {
            Button("OK") { }
        } message: {
            Text("Combined workouts have been split into separate entries for each workout day.")
        }
    }
    
    private func splitCombinedWorkouts() {
        HistoryCodec.splitCombinedWorkouts()
        showingSplitSuccess = true
    }
    
    private func loadMetricsCount() -> Int {
        if let data = UserDefaults.standard.data(forKey: "bodyMetrics"),
           let metrics = try? JSONDecoder().decode([BodyMetric].self, from: data) {
            return metrics.count
        }
        return 0
    }
    
    private func exportData() {
        // Collect all data
        let workouts = HistoryCodec.loadSavedWorkouts()
        
        var metricsData: [[String: Any]] = []
        if let data = UserDefaults.standard.data(forKey: "bodyMetrics"),
           let metrics = try? JSONDecoder().decode([BodyMetric].self, from: data) {
            metricsData = metrics.map { metric in
                var dict: [String: Any] = [
                    "date": metric.date.timeIntervalSince1970
                ]
                if let weight = metric.weight {
                    dict["weight"] = weight
                }
                if let bodyFat = metric.bodyFatPercentage {
                    dict["bodyFatPercentage"] = bodyFat
                }
                if let maxVert = metric.maxVerticalJump {
                    dict["maxVerticalJump"] = maxVert
                }
                return dict
            }
        }
        
        // Get workout configurations
        let configManager = WorkoutConfigManager.shared
        let workoutDaysData = configManager.workoutDays.map { day in
            [
                "id": day.id,
                "name": day.name,
                "exercises": day.exercises,
                "isDefault": day.isDefault
            ]
        }
        
        let exportDict: [String: Any] = [
            "version": "1.0",
            "exportDate": Date().timeIntervalSince1970,
            "workouts": workouts,
            "metrics": metricsData,
            "workoutDays": workoutDaysData,
            "allExercises": configManager.allExercises
        ]
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted) else {
            errorMessage = "Failed to create export file"
            showingError = true
            return
        }
        
        // Write to temp file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "LegDay_Backup_\(dateString).legday"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            exportFileURL = tempURL
        } catch {
            errorMessage = "Failed to save export file: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            do {
                guard url.startAccessingSecurityScopedResource() else {
                    errorMessage = "Could not access the file"
                    showingError = true
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                guard let importData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    errorMessage = "Invalid backup file format"
                    showingError = true
                    return
                }
                
                // Import workouts
                if let workouts = importData["workouts"] as? [[String: Any]] {
                    var existingWorkouts = HistoryCodec.loadSavedWorkouts()
                    
                    for workout in workouts {
                        if let date = workout["date"] as? TimeInterval {
                            // Remove existing workout with same date (within same day)
                            existingWorkouts.removeAll { existing in
                                if let existingDate = existing["date"] as? TimeInterval {
                                    return Calendar.current.isDate(
                                        Date(timeIntervalSince1970: existingDate),
                                        inSameDayAs: Date(timeIntervalSince1970: date)
                                    )
                                }
                                return false
                            }
                            
                            // Clean up the workout data
                            var cleanWorkout = workout
                            cleanWorkout.removeValue(forKey: "_instructions")
                            cleanWorkout.removeValue(forKey: "date_readable")
                            
                            existingWorkouts.append(cleanWorkout)
                        }
                    }
                    
                    // Sort by date
                    existingWorkouts.sort { ($0["date"] as? TimeInterval ?? 0) < ($1["date"] as? TimeInterval ?? 0) }
                    
                    // Save updated workouts
                    if let jsonData = try? JSONSerialization.data(withJSONObject: existingWorkouts) {
                        UserDefaults.standard.set(jsonData, forKey: "savedWorkouts")
                    }
                }
                
                // Import metrics
                if let metricsData = importData["metrics"] as? [[String: Any]] {
                    var existingMetrics: [BodyMetric] = []
                    if let data = UserDefaults.standard.data(forKey: "bodyMetrics"),
                       let decoded = try? JSONDecoder().decode([BodyMetric].self, from: data) {
                        existingMetrics = decoded
                    }
                    
                    for metricDict in metricsData {
                        if let timestamp = metricDict["date"] as? TimeInterval {
                            let date = Date(timeIntervalSince1970: timestamp)
                            
                            let isDuplicate = existingMetrics.contains { existing in
                                Calendar.current.isDate(existing.date, inSameDayAs: date)
                            }
                            
                            if !isDuplicate {
                                let metric = BodyMetric(
                                    date: date,
                                    weight: metricDict["weight"] as? Double,
                                    bodyFatPercentage: metricDict["bodyFatPercentage"] as? Double,
                                    maxVerticalJump: metricDict["maxVerticalJump"] as? Double
                                )
                                existingMetrics.append(metric)
                            }
                        }
                    }
                    
                    if let encoded = try? JSONEncoder().encode(existingMetrics) {
                        UserDefaults.standard.set(encoded, forKey: "bodyMetrics")
                    }
                }
                
                // Import workout configurations
                if let workoutDaysData = importData["workoutDays"] as? [[String: Any]] {
                    let configManager = WorkoutConfigManager.shared
                    
                    for dayDict in workoutDaysData {
                        if let id = dayDict["id"] as? String,
                           let name = dayDict["name"] as? String,
                           let exercises = dayDict["exercises"] as? [String],
                           let isDefault = dayDict["isDefault"] as? Bool {
                            
                            if configManager.getWorkoutDay(id: id) == nil {
                                let dayConfig = WorkoutDayConfig(
                                    id: id,
                                    name: name,
                                    exercises: exercises,
                                    isDefault: isDefault
                                )
                                configManager.workoutDays.append(dayConfig)
                            }
                        }
                    }
                    
                    if let allExercises = importData["allExercises"] as? [String] {
                        for exercise in allExercises {
                            configManager.addExercise(name: exercise)
                        }
                    }
                    
                    configManager.saveData()
                }
                
                showingImportSuccess = true
                
            } catch {
                errorMessage = "Failed to import data: \(error.localizedDescription)"
                showingError = true
            }
            
        case .failure(let error):
            errorMessage = "Failed to open file: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DataManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DataManagementView()
    }
}
