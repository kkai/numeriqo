//
//  Fixtures.swift
//  Numeriqo engine harness
//
//  Hand-checkable boards, built from a cage map plus a solution so every clue
//  is derived rather than typed. Each is verified to have exactly one solution
//  and to be fully solvable by the curriculum — `fixturesAreSoundBoards` in the
//  harness re-proves both, so a bad fixture fails loudly instead of quietly
//  weakening the tests that use it.
//

import Foundation

enum Fixtures {

    /// 3x3. Hand-authored; the smallest board that still exercises a freebie,
    /// pair sets and both single techniques.
    ///
    ///   cages        solution      clues
    ///   A A B        1 2 3         A 2÷   B 3÷
    ///   C D B        2 3 1         C 3÷   D 1−
    ///   C D E        3 1 2         E 2
    static let tiny3x3 = PuzzleBuilder.puzzle(
        cageMap: ["AAB",
                  "CDB",
                  "CDE"],
        solution: [[1, 2, 3],
                   [2, 3, 1],
                   [3, 1, 2]]
    )

    /// 4x4, additive-heavy. No freebie and no subset work — the line techniques
    /// and min/max bounds carry the whole solve.
    ///
    ///   cages          solution        clues
    ///   A B B C        4 2 1 3         A 11+  B 5+
    ///   A A B C        3 4 2 1         C 10+  D 2÷
    ///   D E C C        1 3 4 2         E 36×
    ///   D E E E        2 1 3 4
    static let additive4x4 = PuzzleBuilder.puzzle(
        cageMap: ["ABBC",
                  "AABC",
                  "DECC",
                  "DEEE"],
        solution: [[4, 2, 1, 3],
                   [3, 4, 2, 1],
                   [1, 3, 4, 2],
                   [2, 1, 3, 4]],
        operations: ["A": .add, "B": .add, "C": .add, "D": .divide, "E": .multiply]
    )

    /// 4x4 with a dog-leg `A` cage spanning two rows and two columns, so the
    /// in-cage repeat rule is exercised rather than assumed.
    ///
    ///   cages          solution        clues
    ///   A A B B        3 2 4 1         A 18×  B 10+
    ///   C A A B        4 3 1 2         C 4÷   D 9+
    ///   C D D B        1 4 2 3         E 7+
    ///   D D E E        2 1 3 4
    static let dogLeg4x4 = PuzzleBuilder.puzzle(
        cageMap: ["AABB",
                  "CAAB",
                  "CDDB",
                  "DDEE"],
        solution: [[3, 2, 4, 1],
                   [4, 3, 1, 2],
                   [1, 4, 2, 3],
                   [2, 1, 3, 4]],
        operations: ["A": .multiply, "B": .add, "C": .divide, "D": .add, "E": .add]
    )

    /// 5x5. The soundness board: its solve trace exercises **every** technique
    /// in the curriculum, so the soundness sweep over it covers all ten
    /// detectors without any per-technique setup.
    ///
    ///   cages            solution          clues
    ///   A A B B C        2 3 1 4 5         A 5+   B 4÷
    ///   D D C C C        1 4 3 5 2         C 15+  D 6+
    ///   E D F F F        5 1 2 3 4         E 75×  F 48×
    ///   E E G F H        3 5 4 2 1         G 40×  H 3×
    ///   I G G G H        4 2 5 1 3         I 4
    static let full5x5 = PuzzleBuilder.puzzle(
        cageMap: ["AABBC",
                  "DDCCC",
                  "EDFFF",
                  "EEGFH",
                  "IGGGH"],
        solution: [[2, 3, 1, 4, 5],
                   [1, 4, 3, 5, 2],
                   [5, 1, 2, 3, 4],
                   [3, 5, 4, 2, 1],
                   [4, 2, 5, 1, 3]],
        operations: ["A": .add, "B": .divide, "C": .add, "D": .add, "E": .multiply,
                     "F": .multiply, "G": .multiply, "H": .multiply, "I": .none]
    )

    static let all: [(name: String, puzzle: Puzzle)] = [
        ("tiny3x3", tiny3x3),
        ("additive4x4", additive4x4),
        ("dogLeg4x4", dogLeg4x4),
        ("full5x5", full5x5),
    ]
}
