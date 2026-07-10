//
//  DifficultyCalibrationTests.swift
//  NumeriqoTests
//
//  Dev harness, not a test: prints the score distribution of natural
//  generation per size and a paste-ready thresholds literal for
//  DifficultyRater.thresholds (p33/p66 tertiles, so each band covers about
//  a third of natural generation and the band-targeted retry loop converges
//  in ~3 attempts).
//
//  Run with:
//    TEST_RUNNER_NUMERIQO_CALIBRATE=1 xcodebuild test -project Numeriqo.xcodeproj \
//      -scheme Numeriqo -destination 'platform=macOS' \
//      -only-testing:NumeriqoTests/DifficultyCalibrationTests
//
//  (Output lands in the xcresult log; alternatively compile the game sources
//  with swiftc and run the same loop standalone for direct stdout.)
//
//  RULE: re-run and re-paste into DifficultyRater.thresholds whenever puzzle
//  generation or the score weights change. The band-coverage tests in
//  DifficultyTests are the tripwire that catches stale thresholds.
//

import Foundation
import Testing
@testable import Numeriqo

struct DifficultyCalibrationTests {

    @Test(.enabled(if: ProcessInfo.processInfo.environment["NUMERIQO_CALIBRATE"] == "1"))
    func printScoreDistributions() {
        var literal = "static let thresholds: [Int: (easyMax: Double, mediumMax: Double)] = [\n"
        for size in 3...9 {
            let samples = size <= 6 ? 200 : 100
            var scores: [Double] = []
            for _ in 0..<samples {
                scores.append(MathMazeGame.generatePuzzle(size: size).score)
            }
            scores.sort()
            func p(_ q: Double) -> Double { scores[min(scores.count - 1, Int(q * Double(scores.count)))] }
            print(String(format: "[Calibrate] size %d: p10=%.1f p33=%.1f p50=%.1f p66=%.1f p90=%.1f",
                         size, p(0.10), p(0.33), p(0.50), p(0.66), p(0.90)))
            literal += String(format: "    %d: (%.1f, %.1f),\n", size, p(0.33), p(0.66))
        }
        literal += "]"
        print("[Calibrate] paste into DifficultyRater:\n\(literal)")
    }
}
