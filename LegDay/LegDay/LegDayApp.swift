//
//  LegDayApp.swift
//  LegDay
//
//  Created by Bosco "Bosko" Kante on 9/24/25.
//

import SwiftUI

@main
struct LegDayApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
    
    init() {
        // Temporarily commented out until Core Data classes are properly generated
        // SeedData.insertIfNeeded(context: persistenceController.container.viewContext)
        // One-time bundled .legday import if no history exists
        oneTimeLegdayImportIfNeeded()
    }
    
    private func oneTimeLegdayImportIfNeeded() {
        let hasAnySaved = !HistoryCodec.loadSavedWorkouts().isEmpty
        let already = UserDefaults.standard.bool(forKey: "legday_import_done")
        guard !hasAnySaved && !already else { return }
        if let url = Bundle.main.url(forResource: "boskoworkoutlog", withExtension: "legday"),
           let data = try? Data(contentsOf: url) {
            do {
                try HistoryCodec.importFromData(data)
                UserDefaults.standard.set(true, forKey: "legday_import_done")
                print("✅ Imported initial workout history from boskoworkoutlog.legday")
            } catch {
                print("❌ legday import failed: \(error.localizedDescription)")
            }
        } else {
            print("ℹ️ boskoworkoutlog.legday not found in bundle; skipping initial import")
        }
    }
    
}