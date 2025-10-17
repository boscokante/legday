import XCTest
@testable import LegDay

class LiftingMathTests: XCTestCase {
    
    func testEpley1RM() {
        // Test with 100 lbs for 5 reps
        let oneRM = LiftingMath.epley1RM(weight: 100, reps: 5)
        XCTAssertEqual(oneRM, 116.66666666666667, accuracy: 0.001)
        
        // Test with 0 reps
        let zeroRM = LiftingMath.epley1RM(weight: 100, reps: 0)
        XCTAssertEqual(zeroRM, 0)
    }
    
    func testVolume() {
        let sets = [
            (weight: 100.0, reps: 5),
            (weight: 100.0, reps: 5),
            (weight: 100.0, reps: 5)
        ]
        
        let volume = LiftingMath.volume(sets: sets)
        XCTAssertEqual(volume, 1500)
    }
}