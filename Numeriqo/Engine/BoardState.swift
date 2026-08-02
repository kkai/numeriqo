//
//  BoardState.swift
//  Numeriqo
//
//  Player-visible board state: entries and pencil notes. A pure value type so
//  it snapshots cleanly for undo and persistence.
//
//  The player's notes are what the hint engine reads to decide what they
//  already know — see LogicalSolver.State.
//

import Foundation

nonisolated struct BoardState: Codable, Sendable, Equatable {
    var entries: [Cell: Int] = [:]
    var notes: [Cell: Set<Int>] = [:]
    /// Candidates the player has marked as promising.
    var accented: [Cell: Set<Int>] = [:]
    /// Candidates the player has ruled out by hand.
    var struckOut: [Cell: Set<Int>] = [:]

    init() {}

    func entry(at cell: Cell) -> Int? { entries[cell] }
    func notes(at cell: Cell) -> Set<Int> { notes[cell] ?? [] }
    func accented(at cell: Cell) -> Set<Int> { accented[cell] ?? [] }
    func struckOut(at cell: Cell) -> Set<Int> { struckOut[cell] ?? [] }

    func isComplete(for puzzle: Puzzle) -> Bool {
        puzzle.allCells.allSatisfy { entries[$0] != nil }
    }

    func isSolved(for puzzle: Puzzle) -> Bool {
        puzzle.allCells.allSatisfy { entries[$0] == puzzle.solutionValue(at: $0) }
    }

    /// Cells whose entry disagrees with the unique solution.
    ///
    /// A wrong digit in Calcudoku is often *locally legal* — it breaks no Latin
    /// constraint and satisfies its cage — yet is still not the solution. Those
    /// are exactly the errors that let a player drift for many moves before
    /// anything visibly breaks, so error feedback compares against the solution
    /// rather than merely against the rules. See docs/TEACHING.md §6.
    func incorrectCells(for puzzle: Puzzle) -> [Cell] {
        puzzle.allCells
            .filter { cell in
                guard let entry = entries[cell] else { return false }
                return entry != puzzle.solutionValue(at: cell)
            }
            .sorted()
    }
}

// MARK: - Undo

nonisolated enum Move: Codable, Sendable, Equatable {
    case setEntry(Cell, old: Int?, new: Int?)
    case setNotes(Cell, old: Set<Int>, new: Set<Int>)
    case batch([Move])

    /// Applies the move, returning the inverse for undo.
    ///
    /// A hint-apply is wrapped in a single `.batch` so that undoing it takes
    /// one tap rather than unwinding each elimination separately.
    @discardableResult
    func apply(to board: inout BoardState) -> Move {
        switch self {
        case .setEntry(let cell, let old, let new):
            board.entries[cell] = new
            return .setEntry(cell, old: new, new: old)
        case .setNotes(let cell, let old, let new):
            board.notes[cell] = new.isEmpty ? nil : new
            return .setNotes(cell, old: new, new: old)
        case .batch(let moves):
            let inverses = moves.map { $0.apply(to: &board) }
            return .batch(inverses.reversed())
        }
    }

    var inverse: Move {
        switch self {
        case .setEntry(let cell, let old, let new):
            .setEntry(cell, old: new, new: old)
        case .setNotes(let cell, let old, let new):
            .setNotes(cell, old: new, new: old)
        case .batch(let moves):
            .batch(moves.reversed().map(\.inverse))
        }
    }
}

// MARK: - Puzzle convenience

/// `nonisolated` is required, not stylistic. The app target builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so an unannotated extension is
/// MainActor-isolated — and the solver, which is nonisolated so it can run off
/// the main actor, then cannot call any of it.
nonisolated extension Puzzle {
    var allCells: [Cell] {
        (0..<size).flatMap { r in (0..<size).map { Cell(r, $0) } }
    }

    /// Index into `cages` of the cage containing a cell, or nil if the
    /// partition is malformed.
    func cageIndex(containing cell: Cell) -> Int? {
        cages.firstIndex { $0.cells.contains(cell) }
    }
}
