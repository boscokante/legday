import Foundation

/// Stores user's training preferences and protocols
struct TrainingProfile: Codable {
    /// Number of body parts/focus areas per session
    var bodyPartsPerDay: Int = 2
    
    /// Whether Achilles rehab is required daily
    var dailyAchillesRehab: Bool = true
    
    /// Whether to alternate heavy/light Achilles
    var alternateAchillesIntensity: Bool = true
    
    /// Whether core can be added when doing light Achilles
    var coreWithLightAchilles: Bool = true
    
    /// Primary rotation groups (what gets rotated for "days since last")
    var primaryRotationGroups: [String] = ["leg", "push", "pull"]
    
    /// Secondary/supplemental groups (added on top of primary)
    var supplementalGroups: [String] = ["core", "achilles-heavy", "achilles-light"]
    
    /// Custom notes for the coach
    var coachNotes: String = ""
}

class TrainingProfileManager: ObservableObject {
    static let shared = TrainingProfileManager()
    
    @Published var profile: TrainingProfile
    
    private let storageKey = "trainingProfile"
    
    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(TrainingProfile.self, from: data) {
            profile = decoded
        } else {
            // Default profile matching user's current protocol
            profile = TrainingProfile(
                bodyPartsPerDay: 2,
                dailyAchillesRehab: true,
                alternateAchillesIntensity: true,
                coreWithLightAchilles: true,
                primaryRotationGroups: ["leg", "push", "pull"],
                supplementalGroups: ["core", "achilles-heavy", "achilles-light"],
                coachNotes: "User rotates through legs/push/pull. Achilles rehab every day alternating heavy and light. Can add core if doing light Achilles and has time."
            )
            save()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
        objectWillChange.send()
    }
    
    func getProfileSummary() -> String {
        var summary = "Training Protocol:\n"
        summary += "- \(profile.bodyPartsPerDay) body parts per session\n"
        if profile.dailyAchillesRehab {
            summary += "- Achilles rehab daily"
            if profile.alternateAchillesIntensity {
                summary += " (alternate heavy/light)"
            }
            summary += "\n"
        }
        if profile.coreWithLightAchilles {
            summary += "- Can add core with light Achilles\n"
        }
        if !profile.coachNotes.isEmpty {
            summary += "- Notes: \(profile.coachNotes)\n"
        }
        return summary
    }
}



