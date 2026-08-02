//
//  TutorialScript.swift
//  Numeriqo
//
//  The first-run tutorial, as data.
//
//  The previous version stated the rules across five pages and then left a
//  beginner alone with a live 3x3. Four of those five pages asked for nothing,
//  and the one that did accepted any digit in any cell. That is a rules
//  statement, not a lesson — you cannot learn Calcudoku by reading that digits
//  do not repeat, any more than you can learn chess from a list of legal moves.
//
//  So the script places five digits *for reasons the player is given first*,
//  one idea at a time, and only then hands over the last four cells. Every
//  required placement below is genuinely forced by what has already been
//  taught; the board is the 3x3 in `TutorialScript.board` and the chain was
//  checked against LogicalSolver.
//
//  The engine, not the view, decides what input is allowed. That matters: the
//  old tutorial could be *solved* while the player poked around, and a solved
//  game sets `phase == .won`, after which NumeriqoGame silently swallows every
//  tap — including on the later pages that asked the player to touch the board.
//  Here the view cannot reach `game` at all.
//

import Foundation
import Observation

// MARK: - Steps

/// One beat of the tutorial.
///
/// Every case carries its message first, so `message` is one flat switch, and
/// no case carries a closure — a script is pure data, and therefore testable
/// without a view.
enum TutorialStep: Equatable {
    /// Read it, tap Next.
    case say(String)
    /// Read it, with cells lit on the board.
    case sayHighlighting(String, [Cell])
    /// Locked until that digit lands in that cell. The cell is pre-selected,
    /// so the player only has to press the digit.
    case requireEntry(String, Cell, Int)
    /// The exam: the remaining cells, unaided.
    case solveFreely(String)
    /// Done. The board is complete, so nothing here may need input.
    case celebrate(String)

    var message: String {
        switch self {
        case .say(let text): text
        case .sayHighlighting(let text, _): text
        case .requireEntry(let text, _, _): text
        case .solveFreely(let text): text
        case .celebrate(let text): text
        }
    }

    /// Cells the board should light.
    var highlight: [Cell] {
        switch self {
        case .sayHighlighting(_, let cells): cells
        case .requireEntry(_, let cell, _): [cell]
        case .say, .solveFreely, .celebrate: []
        }
    }

    /// Whether the player advances by tapping Next, rather than by playing.
    var advancesOnNext: Bool {
        switch self {
        case .say, .sayHighlighting: true
        case .requireEntry, .solveFreely, .celebrate: false
        }
    }
}

// MARK: - The script

enum TutorialScript {

    /// The teaching board.
    ///
    ///       c0 c1 c2          cages: A 3+  r0c0 r0c1
    ///   r0   1  2  3                 B 2-  r0c2 r1c2
    ///   r1   2  3  1                 C 1-  r1c0 r2c0
    ///   r2   3  1  2                 D 4+  r1c1 r2c1
    ///                                E 2   r2c2  (single cell)
    ///
    /// Chosen so that one freebie, one sum, one difference and the Latin rule
    /// each get a turn, and so that the five taught placements chain: each is
    /// forced by the one before it plus exactly one new idea.
    static let board = PuzzleBuilder.puzzle(
        cageMap: ["AAB",
                  "CDB",
                  "CDE"],
        solution: [[1, 2, 3],
                   [2, 3, 1],
                   [3, 1, 2]],
        operations: ["A": .add, "B": .subtract, "C": .subtract, "D": .add, "E": .none]
    )

    static let rules: [TutorialStep] = [
        .say("""
        Calcudoku is a small grid of numbers with one rule about position and \
        one about arithmetic. This one is 3×3, so every cell holds a 1, a 2 or \
        a 3. We'll fill the first few together.
        """),

        .sayHighlighting("""
        Start with the easiest cell on any grid. The outlined groups are cages, \
        and the small number in a cage's corner is what its digits have to \
        make. This cage is one cell with no operator, so the 2 in the corner is \
        the answer.
        """, [Cell(2, 2)]),

        .requireEntry("""
        Press 2. The cell is already selected for you.
        """, Cell(2, 2), 2),

        .say("""
        Now the position rule: a digit can't repeat in a row or a column. That \
        2 has used up the bottom row and the right-hand column.
        """),

        .say("""
        One thing to unlearn if you play Sudoku: there are no boxes here. Only \
        rows and columns matter, so a digit can sit anywhere its row and column \
        are clear.
        """),

        // No "and they can't repeat because they share a row" here, though an
        // earlier draft said so: nothing else adds to 3 anyway, and offering a
        // reason the player can check and find redundant is worse than offering
        // none. The 4+ cage further down is where that argument does the work.
        .sayHighlighting("""
        Now the arithmetic. This cage says 3+, so its two digits add up to 3. \
        With only 1, 2 and 3 available, that can only be 1 and 2.
        """, [Cell(0, 0), Cell(0, 1)]),

        .sayHighlighting("""
        You don't know which way round yet, and you don't need to. The 1 and \
        the 2 of the top row are both spoken for, so the cell left over can \
        only be the 3.
        """, [Cell(0, 2)]),

        .requireEntry("""
        Press 3 to put it in.
        """, Cell(0, 2), 3),

        .sayHighlighting("""
        That 3 sits in a 2− cage, so its two digits differ by 2. Subtraction \
        cages don't care which way round you read them, and the only pair here \
        is 3 and 1. The 3 is already down.
        """, [Cell(0, 2), Cell(1, 2)]),

        .requireEntry("""
        Press 1 to finish the cage.
        """, Cell(1, 2), 1),

        .sayHighlighting("""
        Last cage to work out: 4+ down the middle column. Two digits adding to \
        4 means 1 and 3, since 2+2 would repeat a digit in one column. The top \
        of the pair is in a row that already has its 1, so it takes the 3.
        """, [Cell(1, 1), Cell(2, 1)]),

        .requireEntry("""
        Press 3.
        """, Cell(1, 1), 3),

        .requireEntry("""
        And the cell below it takes the 1.
        """, Cell(2, 1), 1),

        .solveFreely("""
        Four cells left, and they're yours. Tap a cell, then press a digit. Or \
        press a digit first to light up everywhere it already sits, which is \
        how you scan a bigger grid. Start on the bottom row.
        """),

        .celebrate("""
        Solved. That's the whole game: fill the grid, never repeat a digit in a \
        row or column, and make every cage hit its target. Everything else is a \
        shortcut for finding the next digit faster, and Learn teaches those one \
        at a time.
        """),
    ]
}

// MARK: - Engine

/// Runs a script over a live board, and is the only thing allowed to touch it.
///
/// The lock is architectural rather than a flag the view is trusted to check:
/// `game` is private, and the view calls `handleTap`/`handleDigit`. There is no
/// path by which a stray tap reaches the board during a reading step.
@Observable @MainActor
final class TutorialEngine {

    private let script: [TutorialStep]
    private let game: NumeriqoGame

    private(set) var index = 0
    /// Why the last input was refused. Never nil-and-silent: a locked board
    /// that says nothing is indistinguishable from a broken one.
    private(set) var feedback: String?
    /// Bumped on every refusal. The view animates a shake off the change.
    private(set) var rejections = 0

    init(script: [TutorialStep] = TutorialScript.rules) {
        self.script = script
        self.game = NumeriqoGame(puzzle: TutorialScript.board, difficulty: .gentle)
        prepare()
    }

    /// The board, for display only. Views read it; they do not call it.
    var displayGame: NumeriqoGame { game }

    var step: TutorialStep { script[min(index, script.count - 1)] }
    var stepNumber: Int { index + 1 }
    var stepCount: Int { script.count }
    var isFirstStep: Bool { index == 0 }
    var isFinished: Bool { index >= script.count - 1 }

    /// Whether the Next button should be offered. Interactive steps advance
    /// themselves, so offering Next there would let the player skip the work.
    var canAdvance: Bool { step.advancesOnNext }

    var highlight: [Cell] { step.highlight }

    /// The pad is hidden once the board is finished. Leaving live-looking keys
    /// under a solved grid invites taps that can only be refused.
    var showsPad: Bool {
        if case .celebrate = step { false } else { true }
    }

    // MARK: Navigation

    func advance() {
        guard index < script.count - 1 else { return }
        index += 1
        prepare()
    }

    func goBack() {
        guard index > 0 else { return }
        // Placements already made are left alone. Winding the board back would
        // punish curiosity, and `prepare` re-primes whatever the step needs.
        index -= 1
        prepare()
    }

    /// Sets the board up for the step we just landed on.
    ///
    /// The auto-priming is most of the hand-holding: on a `requireEntry` step
    /// the target is already selected, so the player's whole job is one digit.
    private func prepare() {
        feedback = nil
        game.activeDigit = nil
        // Notes mode must never survive into `solveFreely` — a board in notes
        // mode cannot be completed, and the player has no idea why. Nothing in
        // the tutorial turns it on, and clearing it here keeps it that way.
        game.notesMode = false

        switch step {
        case .requireEntry(_, let cell, _):
            game.selected = cell
        case .solveFreely:
            game.selected = nil
        case .say, .sayHighlighting, .celebrate:
            game.selected = nil
        }

        // A step whose digit is already on the board — reached by going back,
        // or by a lucky guess during solveFreely — is already satisfied.
        if case .requireEntry(_, let cell, let digit) = step,
           game.board.entries[cell] == digit {
            advance()
        }
    }

    // MARK: Input

    func handleTap(_ cell: Cell) {
        switch step {
        case .requireEntry(_, let target, _):
            if cell == target {
                game.selected = cell
                feedback = nil
                Haptics.select()
            } else {
                reject("Not that one. The lit cell is the one we're filling.")
            }
        case .solveFreely:
            feedback = nil
            game.tap(cell)
            finishIfSolved()
        case .say, .sayHighlighting, .celebrate:
            reject("Have a read of this one first, then tap Next.")
        }
    }

    func handleDigit(_ digit: Int) {
        switch step {
        case .requireEntry(_, let cell, let expected):
            guard digit == expected else {
                reject("Not \(digit). Read the box above once more, then try again.")
                return
            }
            game.place(digit, at: cell)
            advance()
        case .solveFreely:
            feedback = nil
            game.press(digit)
            finishIfSolved()
        case .say, .sayHighlighting, .celebrate:
            reject("Have a read of this one first, then tap Next.")
        }
    }

    func handleErase() {
        guard case .solveFreely = step, let cell = game.selected else {
            reject("Nothing to erase yet.")
            return
        }
        game.clear(at: cell)
    }

    func handleUndo() {
        guard case .solveFreely = step else {
            reject("Undo comes back once the grid is yours.")
            return
        }
        game.undo()
    }

    private func finishIfSolved() {
        guard game.phase == .won else { return }
        Haptics.win()
        advance()
    }

    private func reject(_ message: String) {
        feedback = message
        rejections += 1
        Haptics.wrong()
    }
}
