//
//  DifficultyTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

struct DifficultyTests {

    private let baseStats: MathMazeSolver.Stats = {
        var stats = MathMazeSolver.Stats()
        stats.propagationSolvedCells = 10
        stats.guessCount = 4
        stats.maxDepth = 2
        return stats
    }()

    private let baseFeatures = DifficultyRater.CageFeatures(
        singleCellFraction: 0.2,
        averageCageSize: 2.5,
        averageTupleAmbiguity: 3.0
    )

    @Test func moreGuessesScoreHigher() {
        var harder = baseStats
        harder.guessCount = 40
        let base = DifficultyRater.score(size: 6, stats: baseStats, features: baseFeatures)
        let more = DifficultyRater.score(size: 6, stats: harder, features: baseFeatures)
        #expect(more > base)
    }

    @Test func moreSingleCellCagesScoreLower() {
        let pinned = DifficultyRater.CageFeatures(
            singleCellFraction: 0.6,
            averageCageSize: baseFeatures.averageCageSize,
            averageTupleAmbiguity: baseFeatures.averageTupleAmbiguity
        )
        let base = DifficultyRater.score(size: 6, stats: baseStats, features: baseFeatures)
        let easier = DifficultyRater.score(size: 6, stats: baseStats, features: pinned)
        #expect(easier < base)
    }

    @Test func moreAmbiguousCagesScoreHigher() {
        let ambiguous = DifficultyRater.CageFeatures(
            singleCellFraction: baseFeatures.singleCellFraction,
            averageCageSize: baseFeatures.averageCageSize,
            averageTupleAmbiguity: 6.0
        )
        let base = DifficultyRater.score(size: 6, stats: baseStats, features: baseFeatures)
        let more = DifficultyRater.score(size: 6, stats: baseStats, features: ambiguous)
        #expect(more > base)
    }

    @Test func allSingleCellPuzzleRatesEasy() {
        // A grid of givens is the easiest possible puzzle.
        var cages: [SolverCage] = []
        let solution = [[1, 2, 3], [2, 3, 1], [3, 1, 2]]
        for row in 0..<3 {
            for col in 0..<3 {
                cages.append(SolverCage(
                    positions: [Position(row: row, col: col)],
                    operation: .none,
                    target: solution[row][col]
                ))
            }
        }
        #expect(DifficultyRater.rate(size: 3, cages: cages) == .easy)
    }

    @Test(arguments: [3, 4, 5, 6])
    func generatedPuzzlesLandInTheRequestedBand(size: Int) {
        // Tertile thresholds make a natural puzzle hit any band ~1/3 of the
        // time, so 20 retries virtually never fall back — the returned
        // puzzle's rated band should match the request. A drift here means
        // DifficultyRater.thresholds are stale (re-run calibration).
        for difficulty in Difficulty.allCases {
            var matches = 0
            let runs = 20
            for _ in 0..<runs {
                let puzzle = MathMazeGame.generatePuzzle(size: size, difficulty: difficulty)
                if DifficultyRater.band(forScore: puzzle.score, size: size) == difficulty {
                    matches += 1
                }
            }
            #expect(Double(matches) >= 0.9 * Double(runs),
                    "size \(size) \(difficulty.rawValue): only \(matches)/\(runs) in band — thresholds stale?")
        }
    }

    @Test func nineByNineSpotCheckLandsInBand() {
        for difficulty in Difficulty.allCases {
            var matches = 0
            for _ in 0..<5 {
                let puzzle = MathMazeGame.generatePuzzle(size: 9, difficulty: difficulty)
                if DifficultyRater.band(forScore: puzzle.score, size: 9) == difficulty {
                    matches += 1
                }
            }
            #expect(matches >= 3, "9x9 \(difficulty.rawValue): \(matches)/5 in band")
        }
    }

    @Test(arguments: 3...9)
    func generationWithDifficultyAlwaysReturnsAValidPuzzle(size: Int) {
        for difficulty in Difficulty.allCases {
            let puzzle = MathMazeGame.generatePuzzle(size: size, difficulty: difficulty)
            #expect(puzzle.difficulty == difficulty)
            #expect(puzzle.cages.reduce(0) { $0 + $1.positions.count } == size * size)
            let solutions = MathMazeSolver.solutions(
                size: size,
                cages: puzzle.cages.map(\.solverCage),
                limit: 2
            )
            #expect(solutions.count == 1)
            #expect(solutions.first == puzzle.solution)
        }
    }
}
