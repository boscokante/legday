//
//  LegDayApp.swift
//  LegDay
//
//  Created by Bosco "Bosko" Kante on 9/24/25.
//

import SwiftUI
import UserNotifications

@main
struct LegDayApp: App {
    let persistenceController = PersistenceController.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        // App came to foreground - check timer states
                        TimerManager.shared.checkAllTimers()
                    }
                }
        }
    }
    
    init() {
        // Request notification permissions for timer alerts
        requestNotificationPermission()
        
        // Temporarily commented out until Core Data classes are properly generated
        // SeedData.insertIfNeeded(context: persistenceController.container.viewContext)
        // One-time bundled .legday import if no history exists
        oneTimeLegdayImportIfNeeded()
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permission denied")
            }
        }
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