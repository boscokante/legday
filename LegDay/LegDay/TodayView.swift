import SwiftUI
import CoreData

struct TodayView: View {
    @Environment(\.managedObjectContext) private var ctx
    @State private var showExerciseSheet: Bool = false
    @State private var activeExerciseName: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Exercises") {
                    Button("Bulgarian Split Squat") {
                        activeExerciseName = "Bulgarian Split Squat"
                        showExerciseSheet = true
                    }
                    Button("Leg Press") {
                        activeExerciseName = "Leg Press"
                        showExerciseSheet = true
                    }
                    Button("Single-Leg Extension") {
                        activeExerciseName = "Single-Leg Extension"
                        showExerciseSheet = true
                    }
                    Button("Decline") {
                        activeExerciseName = "Decline"
                        showExerciseSheet = true
                    }
                    Button("Hamstring Curl") {
                        activeExerciseName = "Hamstring Curl"
                        showExerciseSheet = true
                    }
                    Button("Standing Calf Raise") {
                        activeExerciseName = "Standing Calf Raise"
                        showExerciseSheet = true
                    }
                    Button("Seated Calf Raise") {
                        activeExerciseName = "Seated Calf Raise"
                        showExerciseSheet = true
                    }
                    Button("Box Jumps") {
                        activeExerciseName = "Box Jumps"
                        showExerciseSheet = true
                    }
                }
            }
            .navigationTitle("Today")
        }
        .sheet(isPresented: $showExerciseSheet) {
            if let name = activeExerciseName {
                ExerciseQuickLogSheet(exerciseName: name)
            }
        }
    }
}

struct TodayView_Previews: PreviewProvider {
    static var previews: some View {
        TodayView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}