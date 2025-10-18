import Foundation
import CoreData

struct SeedData {
    static func insertIfNeeded(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<DayTemplate> = DayTemplate.fetchRequest()
        
        do {
            let templateCount = try context.count(for: fetchRequest)
            // If templates already exist, do nothing.
            guard templateCount == 0 else {
                print("Templates already exist. Skipping seed.")
                return
            }
        } catch {
            print("Failed to fetch template count: \(error)")
            return
        }

        print("No templates found. Seeding initial data...")
        createDefaultLegDayTemplate(context: context)
    }

    private static func createDefaultLegDayTemplate(context: NSManagedObjectContext) {
        let legDayTemplate = DayTemplate(context: context)
        legDayTemplate.id = UUID()
        legDayTemplate.name = "Leg Day"
        legDayTemplate.isDefault = true

        let exercises = [
            ("Bulgarian Split Squat", true),
            ("Leg Press", true),
            ("Single-Leg Extension", false),
            // Removed Decline from Leg Day per requirements
            ("Hamstring Curl", false),
            ("Standing Calf Raise", false),
            ("Seated Calf Raise", false),
            ("Box Jumps", false)
        ]

        for (index, exerciseInfo) in exercises.enumerated() {
            let templateExercise = TemplateExercise(context: context)
            templateExercise.id = UUID()
            templateExercise.name = exerciseInfo.0
            
            // As per spec, add default warmups for the first two exercises
            if exerciseInfo.1 {
                // Storing as simple JSON string for now
                templateExercise.defaultWarmupJSON = "[{\"reps\": 10, \"weight\": 0, \"isWarmup\": true}, {\"reps\": 10, \"weight\": 0, \"isWarmup\": true}]"
            }
            
            // This is how we add to an ordered relationship
            legDayTemplate.addToExercises(templateExercise)
        }
        
        do {
            try context.save()
            print("Successfully seeded and saved default Leg Day template.")
        } catch {
            print("Failed to save seeded data: \(error)")
        }
    }
}