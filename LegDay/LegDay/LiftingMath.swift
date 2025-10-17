import Foundation

struct LiftingMath {
    static func epley1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1.0 + (Double(reps) / 30.0))
    }

    static func volume(sets: [(weight: Double, reps: Int)]) -> Double {
        sets.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}