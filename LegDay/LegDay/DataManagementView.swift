import SwiftUI
import UniformTypeIdentifiers

struct DataManagementView: View {
    @State private var showingExportSuccess = false
    @State private var showingImportPicker = false
    @State private var showingImportSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
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
            }
            .navigationTitle("Data Management")
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = exportURL {
                ShareSheet(items: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType(filenameExtension: "legday") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
        .alert("Export Successful", isPresented: $showingExportSuccess) {
            Button("OK") { }
        } message: {
            Text("Your workout data has been exported successfully!")
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
        
        let exportData: [String: Any] = [
            "version": "1.0",
            "exportDate": Date().timeIntervalSince1970,
            "workouts": workouts,
            "metrics": metricsData
        ]
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted) else {
            errorMessage = "Failed to create export file"
            showingError = true
            return
        }
        
        // Create temporary file
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let fileName = "LegDay_Backup_\(dateString).legday"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try jsonData.write(to: tempURL)
            exportURL = tempURL
            showingShareSheet = true
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
                    
                    // Merge workouts, avoiding duplicates based on date
                    for workout in workouts {
                        if let date = workout["date"] as? TimeInterval {
                            // Check if workout with same date already exists
                            let isDuplicate = existingWorkouts.contains { existing in
                                if let existingDate = existing["date"] as? TimeInterval {
                                    return abs(existingDate - date) < 60 // Within 1 minute
                                }
                                return false
                            }
                            
                            if !isDuplicate {
                                existingWorkouts.append(workout)
                            }
                        }
                    }
                    
                    // Save merged workouts
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
                    
                    // Convert and merge metrics
                    for metricDict in metricsData {
                        if let timestamp = metricDict["date"] as? TimeInterval {
                            let date = Date(timeIntervalSince1970: timestamp)
                            
                            // Check for duplicate
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
                    
                    // Save merged metrics
                    if let encoded = try? JSONEncoder().encode(existingMetrics) {
                        UserDefaults.standard.set(encoded, forKey: "bodyMetrics")
                    }
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

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DataManagementView_Previews: PreviewProvider {
    static var previews: some View {
        DataManagementView()
    }
}

