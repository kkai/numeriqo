//
//  DailyPuzzleTests.swift
//  NumeriqoTests
//
//  The daily's two shipping-blocking properties: every player gets the same
//  board, and the board actually sits in the advertised band. Both regressed
//  silently before — the band because the generator settled for "nearest
//  after six", the seed because a failing date would fail identically forever.
//

import Foundation
import Testing
@testable import Numeriqo

@Suite struct DailyPuzzleTests {

    private let size = 6
    private let tier = Difficulty.steady

    /// Same date, same board — twice, so the salting loop is provably
    /// deterministic and not consuming shared state between calls.
    @Test func aDailyIsTheSameBoardEveryTime() throws {
        let seed = DailyPuzzle.seed(day: 20_700, size: size, difficulty: tier)
        let first = try #require(DailyPuzzle.generate(seed: seed, size: size, difficulty: tier))
        let second = try #require(DailyPuzzle.generate(seed: seed, size: size, difficulty: tier))
        #expect(first.puzzle == second.puzzle)
    }

    /// Round 0 must be the unsalted seed: a date that generates first try has
    /// to keep the exact board it had before the retry salting existed, or an
    /// app update silently swaps everyone's daily mid-day.
    @Test func theFirstRoundIsTheUnsaltedSeed() throws {
        let seed = DailyPuzzle.seed(day: 20_701, size: size, difficulty: tier)
        let viaDaily = try #require(DailyPuzzle.generate(seed: seed, size: size, difficulty: tier))
        let direct = try #require(PuzzleGenerator.generate(matching: tier, size: size, seed: seed))
        #expect(viaDaily.puzzle == direct.puzzle)
    }

    /// The advertised band, not "nearest". With the raised attempt budget an
    /// off-band daily should be a once-in-decades event; a sample of
    /// consecutive days is enough to catch the budget being quietly lowered.
    @Test func dailiesGradeInTheAdvertisedBand() throws {
        for day in 20_650..<20_660 {
            let seed = DailyPuzzle.seed(day: day, size: size, difficulty: tier)
            let result = try #require(DailyPuzzle.generate(seed: seed, size: size, difficulty: tier),
                                      "day \(day) failed to generate at all")
            #expect(result.grade?.difficulty == tier,
                    "day \(day) graded \(String(describing: result.grade?.difficulty)), advertised \(tier)")
        }
    }
}
