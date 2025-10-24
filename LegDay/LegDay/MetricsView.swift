import SwiftUI
import Charts

struct BodyMetric: Identifiable, Codable {
    var id = UUID()
    var date: Date
    var weight: Double?
    var bodyFatPercentage: Double?
    var maxVerticalJump: Double?
}

class MetricsManager: ObservableObject {
    @Published var metrics: [BodyMetric] = []
    
    private let metricsKey = "bodyMetrics"
    
    init() {
        loadMetrics()
    }
    
    func loadMetrics() {
        if let data = UserDefaults.standard.data(forKey: metricsKey),
           let decoded = try? JSONDecoder().decode([BodyMetric].self, from: data) {
            metrics = decoded.sorted { $0.date > $1.date }
        }
    }
    
    func saveMetrics() {
        if let encoded = try? JSONEncoder().encode(metrics) {
            UserDefaults.standard.set(encoded, forKey: metricsKey)
        }
    }
    
    func addMetric(_ metric: BodyMetric) {
        metrics.append(metric)
        metrics.sort { $0.date > $1.date }
        saveMetrics()
    }
    
    func deleteMetric(_ metric: BodyMetric) {
        metrics.removeAll { $0.id == metric.id }
        saveMetrics()
    }
    
    func updateMetric(_ metric: BodyMetric) {
        if let index = metrics.firstIndex(where: { $0.id == metric.id }) {
            metrics[index] = metric
            metrics.sort { $0.date > $1.date }
            saveMetrics()
        }
    }
}

struct MetricsView: View {
    @StateObject private var manager = MetricsManager()
    @State private var showingAddSheet = false
    @State private var selectedMetric: BodyMetric?
    
    var body: some View {
        NavigationStack {
            List {
                // Current Stats Section
                if let latest = manager.metrics.first {
                    Section("Current Stats") {
                        if let weight = latest.weight {
                            HStack {
                                Text("Weight")
                                Spacer()
                                Text("\(weight, specifier: "%.1f") lbs")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        if let bodyFat = latest.bodyFatPercentage {
                            HStack {
                                Text("Body Fat")
                                Spacer()
                                Text("\(bodyFat, specifier: "%.1f")%")
                                    .foregroundStyle(.orange)
                                    .fontWeight(.semibold)
                            }
                        }
                        if let maxVert = latest.maxVerticalJump {
                            HStack {
                                Text("Max Vert")
                                Spacer()
                                Text("\(maxVert, specifier: "%.1f") in")
                                    .foregroundStyle(.green)
                                    .fontWeight(.semibold)
                            }
                        }
                        Text("Updated: \(latest.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Charts Section
                if !manager.metrics.isEmpty {
                    if manager.metrics.contains(where: { $0.weight != nil }) {
                        Section("Weight Trend") {
                            weightChart
                                .frame(height: 200)
                        }
                    }
                    
                    if manager.metrics.contains(where: { $0.bodyFatPercentage != nil }) {
                        Section("Body Fat % Trend") {
                            bodyFatChart
                                .frame(height: 200)
                        }
                    }
                    
                    if manager.metrics.contains(where: { $0.maxVerticalJump != nil }) {
                        Section("Max Vertical Jump Trend") {
                            verticalJumpChart
                                .frame(height: 200)
                        }
                    }
                }
                
                // History Section
                Section("History") {
                    if manager.metrics.isEmpty {
                        Text("No metrics recorded yet")
                            .foregroundStyle(.secondary)
                            .italic()
                    } else {
                        ForEach(manager.metrics) { metric in
                            Button(action: {
                                selectedMetric = metric
                            }) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(metric.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    HStack(spacing: 12) {
                                        if let weight = metric.weight {
                                            Text("💪 \(weight, specifier: "%.1f") lbs")
                                                .font(.caption)
                                        }
                                        if let bodyFat = metric.bodyFatPercentage {
                                            Text("📊 \(bodyFat, specifier: "%.1f")%")
                                                .font(.caption)
                                        }
                                        if let maxVert = metric.maxVerticalJump {
                                            Text("🏀 \(maxVert, specifier: "%.1f") in")
                                                .font(.caption)
                                        }
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteMetrics)
                    }
                }
            }
            .navigationTitle("Body Metrics")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMetricSheet(manager: manager)
            }
            .sheet(item: $selectedMetric) { metric in
                EditMetricSheet(manager: manager, metric: metric)
            }
        }
    }
    
    private var weightChart: some View {
        let data = manager.metrics
            .filter { $0.weight != nil }
            .sorted { $0.date < $1.date }
        
        return Chart(data) { metric in
            LineMark(
                x: .value("Date", metric.date),
                y: .value("Weight", metric.weight ?? 0)
            )
            .foregroundStyle(.blue)
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", metric.date),
                y: .value("Weight", metric.weight ?? 0)
            )
            .foregroundStyle(.blue)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
    
    private var bodyFatChart: some View {
        let data = manager.metrics
            .filter { $0.bodyFatPercentage != nil }
            .sorted { $0.date < $1.date }
        
        return Chart(data) { metric in
            LineMark(
                x: .value("Date", metric.date),
                y: .value("Body Fat %", metric.bodyFatPercentage ?? 0)
            )
            .foregroundStyle(.orange)
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", metric.date),
                y: .value("Body Fat %", metric.bodyFatPercentage ?? 0)
            )
            .foregroundStyle(.orange)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
    
    private var verticalJumpChart: some View {
        let data = manager.metrics
            .filter { $0.maxVerticalJump != nil }
            .sorted { $0.date < $1.date }
        
        return Chart(data) { metric in
            LineMark(
                x: .value("Date", metric.date),
                y: .value("Max Vert", metric.maxVerticalJump ?? 0)
            )
            .foregroundStyle(.green)
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", metric.date),
                y: .value("Max Vert", metric.maxVerticalJump ?? 0)
            )
            .foregroundStyle(.green)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5))
        }
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
    
    private func deleteMetrics(at offsets: IndexSet) {
        for index in offsets {
            let metric = manager.metrics[index]
            manager.deleteMetric(metric)
        }
    }
}

struct AddMetricSheet: View {
    @ObservedObject var manager: MetricsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var date = Date()
    @State private var weight: String = ""
    @State private var bodyFat: String = ""
    @State private var maxVert: String = ""
    @State private var trackWeight = true
    @State private var trackBodyFat = true
    @State private var trackMaxVert = true
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Measurements") {
                    Toggle("Weight", isOn: $trackWeight)
                    if trackWeight {
                        HStack {
                            TextField("Weight", text: $weight)
                                .keyboardType(.decimalPad)
                            Text("lbs")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Body Fat %", isOn: $trackBodyFat)
                    if trackBodyFat {
                        HStack {
                            TextField("Body Fat", text: $bodyFat)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Max Vertical Jump", isOn: $trackMaxVert)
                    if trackMaxVert {
                        HStack {
                            TextField("Max Vert", text: $maxVert)
                                .keyboardType(.decimalPad)
                            Text("inches")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMetric()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        if trackWeight && !weight.isEmpty { return true }
        if trackBodyFat && !bodyFat.isEmpty { return true }
        if trackMaxVert && !maxVert.isEmpty { return true }
        return false
    }
    
    private func saveMetric() {
        let metric = BodyMetric(
            date: date,
            weight: trackWeight && !weight.isEmpty ? Double(weight) : nil,
            bodyFatPercentage: trackBodyFat && !bodyFat.isEmpty ? Double(bodyFat) : nil,
            maxVerticalJump: trackMaxVert && !maxVert.isEmpty ? Double(maxVert) : nil
        )
        manager.addMetric(metric)
        dismiss()
    }
}

struct EditMetricSheet: View {
    @ObservedObject var manager: MetricsManager
    let metric: BodyMetric
    @Environment(\.dismiss) private var dismiss
    
    @State private var date: Date
    @State private var weight: String
    @State private var bodyFat: String
    @State private var maxVert: String
    @State private var trackWeight: Bool
    @State private var trackBodyFat: Bool
    @State private var trackMaxVert: Bool
    
    init(manager: MetricsManager, metric: BodyMetric) {
        self.manager = manager
        self.metric = metric
        _date = State(initialValue: metric.date)
        _weight = State(initialValue: metric.weight.map { String(format: "%.1f", $0) } ?? "")
        _bodyFat = State(initialValue: metric.bodyFatPercentage.map { String(format: "%.1f", $0) } ?? "")
        _maxVert = State(initialValue: metric.maxVerticalJump.map { String(format: "%.1f", $0) } ?? "")
        _trackWeight = State(initialValue: metric.weight != nil)
        _trackBodyFat = State(initialValue: metric.bodyFatPercentage != nil)
        _trackMaxVert = State(initialValue: metric.maxVerticalJump != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Measurements") {
                    Toggle("Weight", isOn: $trackWeight)
                    if trackWeight {
                        HStack {
                            TextField("Weight", text: $weight)
                                .keyboardType(.decimalPad)
                            Text("lbs")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Body Fat %", isOn: $trackBodyFat)
                    if trackBodyFat {
                        HStack {
                            TextField("Body Fat", text: $bodyFat)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Toggle("Max Vertical Jump", isOn: $trackMaxVert)
                    if trackMaxVert {
                        HStack {
                            TextField("Max Vert", text: $maxVert)
                                .keyboardType(.decimalPad)
                            Text("inches")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button("Delete Metric", role: .destructive) {
                        manager.deleteMetric(metric)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Edit Metrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateMetric()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
    
    private var isValid: Bool {
        if trackWeight && !weight.isEmpty { return true }
        if trackBodyFat && !bodyFat.isEmpty { return true }
        if trackMaxVert && !maxVert.isEmpty { return true }
        return false
    }
    
    private func updateMetric() {
        let updated = BodyMetric(
            id: metric.id,
            date: date,
            weight: trackWeight && !weight.isEmpty ? Double(weight) : nil,
            bodyFatPercentage: trackBodyFat && !bodyFat.isEmpty ? Double(bodyFat) : nil,
            maxVerticalJump: trackMaxVert && !maxVert.isEmpty ? Double(maxVert) : nil
        )
        manager.updateMetric(updated)
        dismiss()
    }
}

struct MetricsView_Previews: PreviewProvider {
    static var previews: some View {
        MetricsView()
    }
}

