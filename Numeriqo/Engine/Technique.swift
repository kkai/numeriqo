//
//  Technique.swift
//  Numeriqo
//
//  The teaching curriculum. Case order is the source of truth for the solver
//  loop, difficulty grading, hint escalation, tutorial sequence and the
//  practice menu — see docs/TECHNIQUES.md.
//
//  Nothing here carries prose. A `TechniqueApplication` carries structured
//  facts; the copy that renders them lives in the Teaching layer, keyed off
//  `.technique`. That keeps the engine free of UI and of localisation.
//

import Foundation

nonisolated enum Technique: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    // Tier 0 — freebies
    case freebieCage

    // Tier 1 — cage arithmetic.
    //
    // `divisibility` sits ahead of `cageCombination` deliberately. Both reach
    // the same eliminations, but "6 doesn't divide 40, so there's no 6 here" is
    // a far simpler thing to be shown than "enumerate the cage". Measured at
    // 0.4% of steps when it ran second — full enumeration always got there
    // first and the simpler lesson never fired.
    case divisibility
    case minMaxBounds
    case pairSets
    case cageCombination

    // Tier 2 — Latin square basics
    case nakedSingle
    case hiddenSingle
    case lastCellInLine

    // Tier 3 — subsets
    case nakedSubset
    case hiddenSubset

    // Tier 4 — cage/line interaction
    case pointingCage
    case claimingLine

    // Tier 5 — the Rule of N. The signature Calcudoku technique.
    case ruleOfN
    case outie

    // Tier 6 — advanced. Parity has no Sudoku analogue and is the strongest
    // differentiator in the curriculum.
    case parity
    case xWing

    var id: Int { rawValue }

    static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// The last technique of the Stage A core. Everything at or below this is
    /// common enough to appear in most solve traces.
    static let coreCeiling: Technique = .hiddenSubset

    /// Techniques that appear in **no** generated solve trace, because cheaper
    /// detectors always reach the same cells first.
    ///
    /// Measured over 720 generated puzzles across every size: parity fires zero
    /// times. By the point a line's odd/even slots are provably exhausted, the
    /// subset and cage/line techniques have already resolved those cells.
    ///
    /// This is not a defect. Forcing parity to fire would mean withholding a
    /// cheaper, clearer explanation the player deserves first. The consequences
    /// are the same ones Kakuro documents for its three unreachable techniques:
    ///
    /// - Its practice drill cannot be found by search and must be hand-authored.
    /// - It can never be credited through play, so mastery for it has to come
    ///   from the drill.
    /// - It will never appear on a post-solve technique recap.
    ///
    /// Pinned by the harness in both directions, so a change in detector
    /// precedence fails loudly rather than silently stranding a lesson.
    static let unreachableInGeneratedPuzzles: [Technique] = [.parity]

    /// Player-facing name. Deliberately plain — jargon is earned, not assumed.
    var displayName: String {
        switch self {
        case .freebieCage: "Free Cells"
        case .divisibility: "Factors"
        case .minMaxBounds: "High & Low"
        case .pairSets: "Difference & Quotient"
        case .cageCombination: "Cage Combinations"
        case .nakedSingle: "Last Candidate"
        case .hiddenSingle: "Only Place"
        case .lastCellInLine: "Last Cell"
        case .nakedSubset: "Matching Sets"
        case .hiddenSubset: "Hidden Sets"
        case .pointingCage: "Cage Points"
        case .claimingLine: "Line Claims"
        case .ruleOfN: "Rule of N"
        case .outie: "Spill Over"
        case .parity: "Odd & Even"
        case .xWing: "X-Wing"
        }
    }
}

// MARK: - Deduction payload

nonisolated struct Placement: Sendable, Equatable, Codable {
    let cell: Cell
    let digit: Int
}

nonisolated struct Elimination: Sendable, Equatable, Codable {
    let cell: Cell
    /// Digits removed, as a bitmask (bit `d-1` set means digit `d`).
    let digits: UInt16
}

/// Structured facts about one technique application. Rendered to prose by the
/// Teaching layer — never store sentences here.
nonisolated struct ExplanationData: Codable, Sendable, Equatable {
    /// Indices into `Puzzle.cages` for the cages the deduction is about.
    var cageIndices: [Int] = []
    /// The digits the deduction concerns.
    var digits: [Int] = []
    /// Surviving cage combinations, as digit bitmasks.
    var combinations: [UInt16] = []
    /// A row or column the deduction is scoped to, when there is one.
    var line: Line?
}

/// A row or column, for scoping a deduction to a region the UI can spotlight.
nonisolated struct Line: Codable, Sendable, Equatable, Hashable {
    enum Kind: String, Codable, Sendable { case row, column }
    let kind: Kind
    let index: Int

    func contains(_ cell: Cell) -> Bool {
        switch kind {
        case .row: cell.row == index
        case .column: cell.col == index
        }
    }

    func cells(size: Int) -> [Cell] {
        (0..<size).map { kind == .row ? Cell(index, $0) : Cell($0, index) }
    }
}

/// One concrete application of a technique: what it places, what it eliminates,
/// and what to highlight when teaching it.
///
/// `focusCells` is the argument the player must look at — it exists so the UI
/// can *draw the reasoning*, which is the whole product thesis.
nonisolated struct TechniqueApplication: Sendable, Equatable {
    let technique: Technique
    var placements: [Placement] = []
    var eliminations: [Elimination] = []
    var focusCells: [Cell] = []
    var involvedCages: [Int] = []
    var explanation = ExplanationData()

    /// A step must do something. A detector returning a no-op would hang the
    /// hint loop, so every detector is required to guarantee this.
    var isUseful: Bool {
        !placements.isEmpty || eliminations.contains { $0.digits != 0 }
    }
}

// MARK: - Digit sets

/// Candidate sets are `UInt16` bitmasks throughout the engine: bit `d-1` set
/// means digit `d` is possible.
nonisolated enum DigitSet {
    static func mask(_ digit: Int) -> UInt16 { UInt16(1) << (digit - 1) }

    static func all(size: Int) -> UInt16 { UInt16((1 << size) - 1) }

    static func contains(_ set: UInt16, _ digit: Int) -> Bool {
        set & mask(digit) != 0
    }

    static func digits(_ set: UInt16) -> [Int] {
        var out: [Int] = []
        var remaining = set
        while remaining != 0 {
            let bit = remaining.trailingZeroBitCount
            out.append(bit + 1)
            remaining &= remaining - 1
        }
        return out
    }

    static func count(_ set: UInt16) -> Int { set.nonzeroBitCount }

    static func fromDigits<S: Sequence>(_ digits: S) -> UInt16 where S.Element == Int {
        digits.reduce(UInt16(0)) { $0 | mask($1) }
    }
}
