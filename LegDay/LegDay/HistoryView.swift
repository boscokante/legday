import SwiftUI

struct HistoryView: View {
    @State private var workouts: [[String: Any]] = []
    @State private var importStatus: String = ""
    
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
                    ForEach(Array(workouts.enumerated()), id: \.offset) { _, w in
                        VStack(alignment: .leading, spacing: 6) {
                            if let ts = w["date"] as? TimeInterval {
                                Text(Date(timeIntervalSince1970: ts).formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                            }
                            if let day = w["day"] as? String {
                                Text(day)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            if let exercises = w["exercises"] as? [String: [[String: Any]]] {
                                ForEach(exercises.keys.sorted(), id: \.self) { key in
                                    if let sets = exercises[key] {
                                        Text("\(key): \(sets.count) sets")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if let notes = w["notes"] as? String, !notes.isEmpty {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("History")
            .onAppear(perform: load)
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
        workouts = UserDefaults.standard.array(forKey: "savedWorkouts") as? [[String: Any]] ?? []
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