//
//  NumeriqoGame.swift
//  Numeriqo
//
//  Play state. Model-View: this is a service the views read, not a ViewModel.
//

import Foundation
import Observation

@Observable @MainActor
final class NumeriqoGame {

    enum Phase: String, Codable, Sendable { case playing, won }

    let puzzle: Puzzle
    let difficulty: Difficulty

    private(set) var board = BoardState()
    private(set) var undoStack: [Move] = []
    private(set) var phase: Phase = .playing
    private(set) var elapsed: TimeInterval = 0
    let isDaily: Bool

    /// The board immediately before the last move.
    ///
    /// Mastery replays the solver from here, and it cannot be reconstructed by
    /// deleting the entry: placing a digit also clears that cell's notes and
    /// retires the digit from its row and column mates.
    private(set) var boardBeforeLastMove: BoardState?

    /// Cells that have already earned mastery credit this game.
    ///
    /// Undo deliberately does not clear this. Placing a digit, undoing and
    /// placing it again is indistinguishable from a fresh deduction when you
    /// only look at the board, so without it a player could farm a technique to
    /// Learned by tapping undo in a loop.
    private var creditedCells: Set<Cell> = []

    /// The selected cell, in cell-first input.
    var selected: Cell?
    /// The digit picked from the pad, in number-first input. Highlights every
    /// instance of it on the board, which is itself a scanning lesson.
    var activeDigit: Int?
    var notesMode = false
    /// Tap a cell first, then a digit. Number-first is the default because it
    /// teaches scanning; this exists for players who prefer the other order.
    var cellFirstInput = false

    /// Cells whose entry disagrees with the unique solution.
    ///
    /// Compared against the solution rather than the rules: a Calcudoku digit is
    /// often *locally legal* — it breaks no Latin constraint and satisfies its
    /// cage — yet still is not the answer. Those are exactly the mistakes that
    /// let a player drift for twenty moves. See docs/TEACHING.md §6.
    var incorrectCells: Set<Cell> { Set(board.incorrectCells(for: puzzle)) }

    init(puzzle: Puzzle, difficulty: Difficulty, isDaily: Bool = false) {
        self.puzzle = puzzle
        self.difficulty = difficulty
        self.isDaily = isDaily
    }

    init(snapshot: GameSnapshot) {
        self.puzzle = snapshot.puzzle
        self.difficulty = snapshot.difficulty
        self.isDaily = snapshot.isDaily ?? false
        self.board = snapshot.board
        self.undoStack = snapshot.undoStack
        self.elapsed = snapshot.elapsed
        if board.isSolved(for: puzzle) { phase = .won }
    }

    var snapshot: GameSnapshot {
        GameSnapshot(puzzle: puzzle, board: board, undoStack: undoStack,
                     difficulty: difficulty, elapsed: elapsed, isDaily: isDaily)
    }

    /// Claims the one-off mastery credit for a cell. False if it already paid out.
    func claimMasteryCredit(at cell: Cell) -> Bool {
        creditedCells.insert(cell).inserted
    }

    func addElapsed(_ delta: TimeInterval) {
        guard phase == .playing else { return }
        elapsed += delta
    }

    // MARK: - Input

    /// Selecting a cell.
    ///
    /// Deliberately does NOT toggle off when the same cell is tapped again.
    /// Kakuro's does, and its own engineering notes record that a UI test driver
    /// re-tapping a selected cell looks exactly like the app ignoring input.
    func tap(_ cell: Cell) {
        guard phase == .playing else { return }
        if !cellFirstInput, let digit = activeDigit {
            // Number-first: the pad holds a digit, so a tap places it.
            place(digit, at: cell)
        } else {
            selected = cell
            Haptics.select()
        }
    }

    /// A digit pressed on the pad.
    func press(_ digit: Int) {
        guard phase == .playing else { return }
        if let cell = selected {
            place(digit, at: cell)
        } else if cellFirstInput {
            // Cell-first: a digit with nothing selected has nowhere to go.
            Haptics.wrong()
        } else {
            // Number-first: arm the digit, or disarm it if already armed.
            activeDigit = (activeDigit == digit) ? nil : digit
            Haptics.note()
        }
    }

    func place(_ digit: Int, at cell: Cell) {
        guard phase == .playing else { return }

        if notesMode {
            toggleNote(digit, at: cell)
            return
        }

        // Re-entering the same digit erases it.
        let old = board.entries[cell]
        guard old != digit else { clear(at: cell); return }

        var moves: [Move] = [.setEntry(cell, old: old, new: digit)]

        // Placing a digit retires it from the notes of its row and column
        // mates. Bundled into the same batch so it is one undo, not many.
        for peer in peers(of: cell) {
            let notes = board.notes(at: peer)
            if notes.contains(digit) {
                moves.append(.setNotes(peer, old: notes, new: notes.subtracting([digit])))
            }
        }
        let own = board.notes(at: cell)
        if !own.isEmpty { moves.append(.setNotes(cell, old: own, new: [])) }

        let satisfiedBefore = satisfiedCageCount
        let completeBefore = completeLineCount
        perform(moves)

        // Feedback scales with rarity: a placement, then a satisfied cage, then
        // a completed line. Firing them all at once would flatten the climb, so
        // only the rarest event that just happened speaks.
        if completeLineCount > completeBefore {
            Haptics.lineComplete()
        } else if satisfiedCageCount > satisfiedBefore {
            Haptics.cageSatisfied()
        } else {
            Haptics.place()
        }
        checkWin()
    }

    private var satisfiedCageCount: Int {
        puzzle.cages.reduce(0) { $0 + (isCageSatisfied($1) ? 1 : 0) }
    }

    private var completeLineCount: Int {
        var count = 0
        for i in 0..<puzzle.size {
            if isLineComplete(Line(kind: .row, index: i)) { count += 1 }
            if isLineComplete(Line(kind: .column, index: i)) { count += 1 }
        }
        return count
    }

    func clear(at cell: Cell) {
        guard phase == .playing, let old = board.entries[cell] else { return }
        perform([.setEntry(cell, old: old, new: nil)])
        _ = old
        Haptics.note()
    }

    func toggleNote(_ digit: Int, at cell: Cell) {
        guard phase == .playing, board.entries[cell] == nil else { return }
        let old = board.notes(at: cell)
        let new = old.contains(digit) ? old.subtracting([digit]) : old.union([digit])
        perform([.setNotes(cell, old: old, new: new)])
        Haptics.note()
    }

    // MARK: - Undo

    var canUndo: Bool { !undoStack.isEmpty }

    func undo() {
        guard phase == .playing, let inverse = undoStack.popLast() else { return }
        inverse.apply(to: &board)
        Haptics.note()
    }

    private func perform(_ moves: [Move]) {
        guard !moves.isEmpty else { return }
        boardBeforeLastMove = board
        let move: Move = moves.count == 1 ? moves[0] : .batch(moves)
        let inverse = move.apply(to: &board)
        undoStack.append(inverse)
    }

    /// Fills notes with what the *cheapest* techniques establish — never the
    /// full solver.
    ///
    /// Auto-notes must remove counting, not thinking. Running the whole
    /// curriculum here would quietly hand the player deductions they have not
    /// earned, which is the failure docs/TEACHING.md §4 warns about.
    func fillAutoNotes() {
        guard phase == .playing else { return }
        var next = board
        var rounds = 0
        while rounds < puzzle.size * puzzle.size * 4 {
            rounds += 1
            guard let step = LogicalSolver.nextStep(puzzle: puzzle, board: next),
                  step.technique <= .minMaxBounds,
                  step.placements.isEmpty
            else { break }
            let before = next
            LogicalSolver.applyEliminations(step, to: &next, size: puzzle.size)
            if next == before { break }
        }

        var moves: [Move] = []
        for cell in puzzle.allCells where board.entries[cell] == nil {
            let old = board.notes(at: cell)
            let new = next.notes(at: cell)
            if new != old, !new.isEmpty { moves.append(.setNotes(cell, old: old, new: new)) }
        }
        perform(moves)
    }

    // MARK: - Hints

    /// The next deduction available from the player's *own* board and notes.
    func nextStep() -> TechniqueApplication? {
        LogicalSolver.nextStep(puzzle: puzzle, board: board)
    }

    /// Applies a hint as one undoable batch.
    func apply(_ step: TechniqueApplication) {
        guard phase == .playing else { return }

        // Eliminations must be applied to a materialised candidate set. Against
        // a cell with no notes there is nothing to subtract from, so Apply would
        // look like it did nothing at all.
        var next = board
        LogicalSolver.applyEliminations(step, to: &next, size: puzzle.size)

        var moves: [Move] = []
        for elimination in step.eliminations {
            let old = board.notes(at: elimination.cell)
            let new = next.notes(at: elimination.cell)
            if new != old { moves.append(.setNotes(elimination.cell, old: old, new: new)) }
        }
        for placement in step.placements {
            moves.append(.setEntry(
                placement.cell, old: board.entries[placement.cell], new: placement.digit
            ))
        }

        perform(moves)
        if !step.placements.isEmpty { Haptics.place() }
        checkWin()
    }

    // MARK: - Derived board facts

    /// Row and column mates.
    func peers(of cell: Cell) -> [Cell] {
        var out: [Cell] = []
        for i in 0..<puzzle.size {
            if i != cell.col { out.append(Cell(cell.row, i)) }
            if i != cell.row { out.append(Cell(i, cell.col)) }
        }
        return out
    }

    /// Whether a digit is already used in the cell's row or column.
    ///
    /// Only the Latin constraint — never full constraint propagation. The legacy
    /// app dimmed pad digits using its solver, and its own notes flag that as a
    /// route to leaking the unique solution.
    func isBlocked(digit: Int, at cell: Cell) -> Bool {
        peers(of: cell).contains { board.entries[$0] == digit }
    }

    func isCageSatisfied(_ cage: Cage) -> Bool {
        let digits = cage.cells.compactMap { board.entries[$0] }
        guard digits.count == cage.cells.count else { return false }
        return cage.operation.satisfies(digits, target: cage.target)
    }

    func isLineComplete(_ line: Line) -> Bool {
        let values = line.cells(size: puzzle.size).compactMap { board.entries[$0] }
        return values.count == puzzle.size && Set(values).count == puzzle.size
    }

    private func checkWin() {
        guard board.isSolved(for: puzzle) else { return }
        phase = .won
        selected = nil
        activeDigit = nil
        Haptics.win()
    }
}
