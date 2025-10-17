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
    }
}