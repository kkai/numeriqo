//
//  Difficulty.swift
//  Numeriqo
//
//  Solver-derived difficulty rating. A puzzle's difficulty comes from how
//  the solver cracks it (guesses vs. pure propagation) plus how ambiguous
//  its cage structure is — not from grid size alone.
//

import Foundation

enum Difficulty: String, CaseIterable, Identifiable, Codable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }
}

enum DifficultyRater {

    struct CageFeatures {
        /// Fraction of cages that are single-cell givens.
        let singleCellFraction: Double
        /// Mean cage size in cells.
        let averageCageSize: Double
        /// Mean log2 of the number of feasible value tuples per cage —
        /// how ambiguous each cage is before any digits are placed.
        let averageTupleAmbiguity: Double

        init(singleCellFraction: Double, averageCageSize: Double, averageTupleAmbiguity: Double) {
            self.singleCellFraction = singleCellFraction
            self.averageCageSize = averageCageSize
            self.averageTupleAmbiguity = averageTupleAmbiguity
        }

        init?(size: Int, cages: [SolverCage]) {
            guard !cages.isEmpty,
                  let tupleCounts = MathMazeSolver.tupleCounts(size: size, cages: cages) else { return nil }
            let cellCounts = cages.map { $0.positions.count }
            singleCellFraction = Double(cellCounts.filter { $0 == 1 }.count) / Double(cages.count)
            averageCageSize = Double(cellCounts.reduce(0, +)) / Double(cages.count)
            averageTupleAmbiguity = tupleCounts.map { log2(Double(max($0, 1))) }.reduce(0, +) / Double(cages.count)
        }
    }

    /// Pure scoring core. Guess effort dominates; among guess-free puzzles
    /// (all small sizes) the cage-structure terms are the differentiator.
    static func score(size: Int, stats: MathMazeSolver.Stats, features: CageFeatures) -> Double {
        let searchEffort = 10.0 * log2(1.0 + Double(stats.guessCount)) + 2.0 * Double(stats.maxDepth)
        return searchEffort
            + 3.0 * features.averageTupleAmbiguity
            + 1.0 * features.averageCageSize
            - 4.0 * features.singleCellFraction
    }

    /// Scores a puzzle by solving it from the empty grid.
    static func score(size: Int, cages: [SolverCage]) -> Double? {
        guard let features = CageFeatures(size: size, cages: cages) else { return nil }
        let (solution, stats) = MathMazeSolver.solveWithStats(size: size, cages: cages)
        guard solution != nil else { return nil }
        return score(size: size, stats: stats, features: features)
    }

    static func band(forScore score: Double, size: Int) -> Difficulty {
        guard let t = thresholds[size] else { return .medium }
        if score < t.easyMax { return .easy }
        if score < t.mediumMax { return .medium }
        return .hard
    }

    static func rate(size: Int, cages: [SolverCage]) -> Difficulty? {
        guard let score = score(size: size, cages: cages) else { return nil }
        return band(forScore: score, size: size)
    }

    /// Per-size band boundaries (easy < easyMax <= medium < mediumMax <= hard).
    /// Values are the p33/p66 tertiles of natural generation, produced by
    /// DifficultyCalibrationTests (run with TEST_RUNNER_NUMERIQO_CALIBRATE=1)
    /// — re-run and re-paste whenever generation or the score weights change.
    static let thresholds: [Int: (easyMax: Double, mediumMax: Double)] = [
        // PROVISIONAL until the calibration harness output is pasted.
        3: (7.0, 10.0),
        4: (9.0, 13.0),
        5: (11.0, 16.0),
        6: (13.0, 19.0),
        7: (16.0, 24.0),
        8: (18.0, 30.0),
        9: (20.0, 36.0),
    ]
}
