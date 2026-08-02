//
//  PracticeDrills.swift
//  Numeriqo
//
//  Boards for practising one technique.
//
//  Most are found by asking the generator for a board whose solve trace uses the
//  technique — it can filter for that directly while grading candidates, so the
//  search happens inside one generation rather than generate-and-discard.
//
//  Some cannot be found that way at all. `Technique.unreachableInGeneratedPuzzles`
//  records which, measured over 720 generated puzzles and pinned in both
//  directions by the engine harness. Those get hand-authored boards.
//

import Foundation

nonisolated enum PracticeDrills {

    /// How many uses of its own technique a searched drill must show.
    ///
    /// The cheap techniques fire constantly, so one appearance proves nothing
    /// about the board being *about* them.
    static func minimumUses(of technique: Technique) -> Int {
        technique <= .lastCellInLine ? 2 : 1
    }

    /// Techniques whose drills cannot be produced by a live search.
    ///
    /// Two different reasons, both measured:
    ///
    /// - **Parity never fires at all** — 0 appearances in 1,200 generated
    ///   boards. `Technique.unreachableInGeneratedPuzzles` records this, pinned
    ///   in both directions by the engine harness.
    /// - **Spill Over fires in 0.5% of boards** (6 in 1,200). That is findable
    ///   in principle but needs ~200 generations, which is far too slow to sit
    ///   behind a drill button — so its board was found by an offline search
    ///   once and frozen below.
    static var handAuthored: [Technique] {
        Technique.unreachableInGeneratedPuzzles + [.outie]
    }

    /// Hand-authored boards, as (cage map, solution, operations).
    ///
    /// Each is verified unique and curriculum-solvable by `BoardTests`.
    static func bakedBoards(for technique: Technique) -> [Puzzle] {
        switch technique {
        case .parity:
            // 5x5. A row totals 15 and holds three odd digits. Once the odd
            // slots in a line are accounted for, everything still open in it
            // has to be even — which is the only way in here.
            //   cages        solution
            //   A A B B C    1 2 3 4 5
            //   D D B E C    2 3 4 5 1
            //   D F F E G    3 4 5 1 2
            //   H H I E G    4 5 1 2 3
            //   H I I J J    5 1 2 3 4
            [PuzzleBuilder.puzzle(
                cageMap: ["AABBC",
                          "DDBEC",
                          "DFFEG",
                          "HHIEG",
                          "HIIJJ"],
                solution: [[1, 2, 3, 4, 5],
                           [2, 3, 4, 5, 1],
                           [3, 4, 5, 1, 2],
                           [4, 5, 1, 2, 3],
                           [5, 1, 2, 3, 4]]
            )]

        case .outie:
            // 5x5. Found by an offline search over 3,000 candidates (0.5% hit
            // rate) and frozen, rather than searched for at run time.
            //   cages          solution
            //   A A B C C      1 2 5 4 3
            //   D A B B C      3 5 4 1 2
            //   D D B E C      5 3 1 2 4
            //   F D E E H      4 1 2 3 5
            //   F F G G G      2 4 3 5 1
            [PuzzleBuilder.puzzle(
                cageMap: ["AABCC",
                          "DABBC",
                          "DDBEC",
                          "FDEEH",
                          "FFGGG"],
                solution: [[1, 2, 5, 4, 3],
                           [3, 5, 4, 1, 2],
                           [5, 3, 1, 2, 4],
                           [4, 1, 2, 3, 5],
                           [2, 4, 3, 5, 1]],
                operations: ["A": .multiply, "B": .add, "C": .add, "D": .add,
                             "E": .multiply, "F": .multiply, "G": .multiply, "H": .none]
            )]

        default:
            []
        }
    }

    /// Whether a baked board actually demonstrates the technique it is filed
    /// under.
    ///
    /// **Parity's does not.** Its board is unique and curriculum-solvable, so it
    /// is a fine puzzle, but the solver cracks it before any parity argument is
    /// needed — which is the very reason parity is unsearchable. Constructing a
    /// board that *forces* a parity deduction is genuine puzzle-design work and
    /// is still outstanding; until then the lesson teaches parity and the drill
    /// only practises solving. Surfaced here rather than hidden behind a test
    /// exemption, so it stays visible.
    static let bakedBoardsThatDemonstrateTheirTechnique: [Technique] = [.outie]

    /// A drill board for `technique`. Deterministic per `(technique, variant)`,
    /// so "another drill" is reproducible.
    static func drill(for technique: Technique, variant: UInt64 = 0) -> Puzzle? {
        let baked = bakedBoards(for: technique)
        if !baked.isEmpty {
            return baked[Int(variant % UInt64(baked.count))]
        }

        let minimum = minimumUses(of: technique)
        let size = technique >= .pointingCage ? 6 : 5
        var options = PuzzleGenerator.Options.forSize(size)
        // Filters as the generator grades, rather than running the whole search
        // repeatedly and discarding boards that miss. Draws no randomness, so a
        // default-accept caller sees the identical seeded stream.
        options.accepts = { profile in (profile[technique] ?? 0) >= minimum }

        let seed = 0x00D5_1000 &+ UInt64(technique.rawValue) &* 977 &+ variant &* 7919
        return PuzzleGenerator.generate(size: size, options: options, seed: seed)?.puzzle
    }
}
