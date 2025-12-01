import SwiftUI

struct SupersetDashboardView: View {
    @EnvironmentObject var voiceAgent: VoiceAgentStore
    @ObservedObject var dailyWorkout: DailyWorkoutSession
    
    var body: some View {
        if let exerciseA = voiceAgent.supersetExerciseA {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Exercise A card
                    ExerciseCard(
                        exerciseName: exerciseA,
                        sets: dailyWorkout.getSets(for: exerciseA),
                        onComplete: { markSetComplete(exercise: exerciseA) }
                    )
                    
                    // Exercise B card (if set)
                    if let exerciseB = voiceAgent.supersetExerciseB {
                        ExerciseCard(
                            exerciseName: exerciseB,
                            sets: dailyWorkout.getSets(for: exerciseB),
                            onComplete: { markSetComplete(exercise: exerciseB) }
                        )
                    }
                }
                
                // Clear button
                Button(action: { voiceAgent.clearSuperset() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                        Text("Clear")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground).opacity(0.95))
        }
    }
    
    private func markSetComplete(exercise: String) {
        let sets = dailyWorkout.getSets(for: exercise)
        
        // Find first incomplete set
        if let index = sets.firstIndex(where: { !$0.completed }) {
            let set = sets[index]
            let dataType = ExerciseDataType.type(for: exercise)
            
            dailyWorkout.updateSet(
                exercise: exercise,
                index: index,
                weight: set.weight,
                reps: set.reps,
                warmup: set.warmup,
                completed: true,
                minutes: dataType == .time ? (set.minutes ?? 0) : 0,
                seconds: dataType == .time ? (set.seconds ?? 0) : 0,
                shotsMade: dataType == .shots ? (set.shotsMade ?? 0) : 0
            )
        }
    }
}

struct ExerciseCard: View {
    let exerciseName: String
    let sets: [SetData]
    let onComplete: () -> Void
    
    private var completedCount: Int {
        sets.filter { $0.completed }.count
    }
    
    private var totalCount: Int {
        sets.count
    }
    
    private var currentSet: SetData? {
        sets.first { !$0.completed }
    }
    
    private var currentSetNumber: Int {
        completedCount + 1
    }
    
    private var isComplete: Bool {
        currentSet == nil && totalCount > 0
    }
    
    private var shortName: String {
        // Shorten common exercise names for compact display
        let name = exerciseName
        if name.count > 15 {
            // Try to find a good abbreviation
            let words = name.split(separator: " ")
            if words.count > 2 {
                return words.prefix(2).joined(separator: " ")
            }
        }
        return name
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Exercise name
            Text(shortName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            
            if totalCount == 0 {
                Text("No sets")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if isComplete {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Done!")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.green)
                }
            } else if let set = currentSet {
                // Set progress
                Text("Set \(currentSetNumber) of \(totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Weight × Reps
                HStack(spacing: 2) {
                    Text("\(Int(set.weight))")
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("lbs")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("×")
                        .foregroundColor(.secondary)
                    Text("\(set.reps)")
                        .font(.title3.weight(.bold).monospacedDigit())
                }
                
                // Done button
                Button(action: onComplete) {
                    Text("Done")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isComplete ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }
}

#Preview {
    SupersetDashboardView(dailyWorkout: DailyWorkoutSession.shared)
        .environmentObject(VoiceAgentStore())
}


