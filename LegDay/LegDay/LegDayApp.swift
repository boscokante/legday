//
//  LegDayApp.swift
//  LegDay
//
//  Created by Bosco "Bosko" Kante on 9/24/25.
//

import SwiftUI
import UserNotifications
import AVFoundation

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
                    } else if newPhase == .background || newPhase == .inactive {
                        // Auto-save completed exercises when app goes to background
                        autoSaveCompletedSets()
                    }
                }
        }
    }
    
    private func autoSaveCompletedSets() {
        let session = DailyWorkoutSession.shared
        let completedCount = session.getCompletedSets()
        
        if completedCount > 0 {
            session.saveCompleteWorkout(resetState: false)
            print("🔄 Auto-saved \(completedCount) completed sets on app background")
        }
    }
    
    init() {
        // Configure audio session for voice agent
        configureAudioSession()
        
        // Request notification permissions for timer alerts
        requestNotificationPermission()
        
        // Request microphone permission
        requestMicrophonePermission()
        
        // Temporarily commented out until Core Data classes are properly generated
        // SeedData.insertIfNeeded(context: persistenceController.container.viewContext)
        // One-time bundled .legday import if no history exists
        oneTimeLegdayImportIfNeeded()
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func requestMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { granted in
            if granted {
                print("✅ Microphone permission granted")
            } else {
                print("⚠️ Microphone permission denied")
            }
        }
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