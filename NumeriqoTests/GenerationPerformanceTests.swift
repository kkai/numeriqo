//
//  GenerationPerformanceTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

struct GenerationPerformanceTests {

    /// Generation (including the uniqueness proof) runs synchronously in
    /// MathMazeGame.init, so it must stay fast even at 9×9. This is a
    /// regression tripwire, not a benchmark: bounds are generous because the
    /// suite runs in parallel under -Onone. (Unoptimized median is ~150ms;
    /// if it creeps toward these bounds, move generation off the main actor
    /// per the roadmap.)
    @Test func nineByNineGenerationIsFast() {
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0..<10 {
            let duration = clock.measure {
                _ = MathMazeGame.generatePuzzle(size: 9)
            }
            durations.append(duration)
        }
        durations.sort()
        let median = durations[durations.count / 2]
        let worst = durations.last!
        print("[MathMaze] 9x9 generation: median \(median), worst \(worst)")
        #expect(worst < .seconds(3))
        #expect(median < .milliseconds(750))
    }
}
