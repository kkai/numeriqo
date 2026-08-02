//
//  Difficulty.swift
//  Numeriqo
//
//  Technique-based difficulty grading, derived from the logical solve trace.
//
//  This replaces the legacy app's machine-effort rating (backtracking guess
//  count and search depth), which could not express "this puzzle teaches
//  parity" and so could drive neither an Academy nor a hint system.
//

import Foundation

nonisolated enum Difficulty: String, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case gentle
    case steady
    case sharp
    case deep
    case severe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gentle: "Gentle"
        case .steady: "Steady"
        case .sharp: "Sharp"
        case .deep: "Deep"
        case .severe: "Severe"
        }
    }

    var order: Int { Difficulty.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: Difficulty, rhs: Difficulty) -> Bool { lhs.order < rhs.order }
}

nonisolated enum DifficultyRater {

    /// Cost of one application of a technique.
    ///
    /// These are NOT curriculum order. `nakedSingle` is taught late but is the
    /// trivial "one candidate left" step, so ranking by curriculum position
    /// would credit it over the elimination work that actually earned the
    /// placement. Rank by solving cost.
    static func weight(for technique: Technique) -> Int {
        switch technique {
        case .freebieCage: 0      // handed to the player; no work at all
        case .lastCellInLine: 1
        case .nakedSingle: 2
        case .cageCombination: 3
        case .divisibility: 4
        case .pairSets: 4
        case .hiddenSingle: 6
        case .minMaxBounds: 8
        case .nakedSubset: 14
        case .hiddenSubset: 18
        case .pointingCage: 22
        case .claimingLine: 26
        case .ruleOfN: 30
        case .outie: 36
        case .parity: 42
        case .xWing: 50
        }
    }

    /// Penalty for a puzzle the curriculum cannot finish. Such puzzles are
    /// rejected at generation; the penalty exists so a stray one grades as
    /// hardest rather than easiest.
    static let unsolvedPenalty = 1000

    /// Score = Σ weight × count. Volume-sensitive by design — a big grid racks
    /// up many cheap steps — which is why thresholds are per size.
    static func score(profile: [Technique: Int], solved: Bool) -> Int {
        var total = profile.reduce(0) { $0 + weight(for: $1.key) * $1.value }
        if !solved { total += unsolvedPenalty }
        return total
    }

    static func score(_ result: LogicalSolver.SolveResult) -> Int {
        score(profile: result.histogram, solved: result.solved)
    }

    /// Per-size band boundaries, as cumulative upper bounds:
    /// `[gentleMax, steadyMax, sharpMax, deepMax]`; above the last is severe.
    ///
    /// Calibrated as p20/p40/p60/p80 quintiles over 60 generated puzzles per
    /// size. **Regenerate with `NUMERIQO_CALIBRATE=1` in the engine harness
    /// whenever generation, the technique set, or the weights change** — the
    /// numbers are meaningless otherwise. The harness pins the *shape* of the
    /// banding, not these values, so recalibration never breaks tests.
    ///
    /// Calibrated 2026-08-01 against the full 16-technique curriculum.
    ///
    /// `let`, not `var`: a mutable static is global shared mutable state and is
    /// rejected under Swift 6 strict concurrency. Tests that need different
    /// bands pass their own table to `band(forScore:size:using:)` rather than
    /// mutating this one — which is better anyway, since a test that mutated it
    /// could silently de-calibrate a real size for everything that ran after.
    static let thresholds: [Int: [Int]] = [
        3: [48, 57, 62, 68],
        4: [126, 137, 164, 193],
        5: [211, 232, 286, 325],
        6: [397, 442, 490, 541],
        7: [619, 698, 785, 842],
        8: [802, 899, 1002, 1083],
        9: [1148, 1218, 1290, 1438],
    ]

    /// The tier for a score at a given grid size.
    ///
    /// `using` overrides the calibrated table; tests pass their own rather than
    /// mutating global state.
    static func band(
        forScore score: Int,
        size: Int,
        using table: [Int: [Int]]? = nil
    ) -> Difficulty {
        guard let bounds = (table ?? thresholds)[size], bounds.count == 4 else {
            // Uncalibrated: everything lands mid-table rather than pretending
            // to a precision we do not have.
            return .steady
        }
        for (i, bound) in bounds.enumerated() where score <= bound {
            return Difficulty.allCases[i]
        }
        return .severe
    }

    /// Full grading of a solve.
    struct Grade: Sendable, Equatable {
        let score: Int
        let difficulty: Difficulty
        let hardestTechnique: Technique?
        let solved: Bool
        let profile: [Technique: Int]
    }

    static func grade(_ result: LogicalSolver.SolveResult, size: Int) -> Grade {
        let value = score(result)
        return Grade(
            score: value,
            difficulty: band(forScore: value, size: size),
            hardestTechnique: result.hardestTechnique,
            solved: result.solved,
            profile: result.histogram
        )
    }
}
