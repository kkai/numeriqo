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
        #expect(worst < .seconds(5))
        #expect(median < .milliseconds(1500))
    }

    /// Band-targeted generation multiplies natural generation by the retry
    /// count (~3 expected with tertile bands). Same tripwire philosophy as
    /// above: generous bounds, and if they creep, move generation off the
    /// main actor per the roadmap.
    @Test func nineByNineBandTargetedGenerationIsFast() {
        let clock = ContinuousClock()
        var durations: [Duration] = []
        for _ in 0..<5 {
            let duration = clock.measure {
                _ = MathMazeGame.generatePuzzle(size: 9, difficulty: .easy)
            }
            durations.append(duration)
        }
        durations.sort()
        print("[MathMaze] 9x9 easy generation: median \(durations[2]), worst \(durations.last!)")
        #expect(durations.last! < .seconds(15))
        #expect(durations[2] < .seconds(5))
    }
}
