//
//  TutorialTests.swift
//  NumeriqoTests
//
//  The tutorial is the first thing a new player sees, and a scripted tutorial
//  that cannot be completed traps them on step one with no way out. So the
//  headline test here walks the entire script by following its own written
//  instructions — if the script and the board ever disagree, that test wedges.
//

import Testing
@testable import Numeriqo

@MainActor
struct TutorialTests {

    // MARK: - The script itself

    @Test("Every required entry matches the board's solution")
    func requiredEntriesAreCorrect() {
        let puzzle = TutorialScript.board
        for step in TutorialScript.rules {
            guard case .requireEntry(_, let cell, let digit) = step else { continue }
            #expect(puzzle.solutionValue(at: cell) == digit,
                    "step asks for \(digit) at r\(cell.row)c\(cell.col), solution has \(puzzle.solutionValue(at: cell))")
        }
    }

    @Test("The teaching board has exactly one solution")
    func boardIsUnique() {
        let puzzle = TutorialScript.board
        #expect(BacktrackingSolver.countSolutions(size: puzzle.size,
                                                  cages: puzzle.cages, limit: 2) == 1)
    }

    @Test("The script ends on a celebration, so nothing after the win needs input")
    func scriptEndsNonInteractive() {
        // A won game swallows every tap. If any interactive step followed the
        // final placement the tutorial would look frozen — which is precisely
        // how the previous version broke.
        guard case .celebrate = TutorialScript.rules.last else {
            Issue.record("script must end with .celebrate")
            return
        }
        let interactiveAfterSolve = TutorialScript.rules
            .drop { if case .solveFreely = $0 { return false } else { return true } }
            .dropFirst()
            .filter { if case .celebrate = $0 { return false } else { return true } }
        #expect(interactiveAfterSolve.isEmpty)
    }

    @Test("Every step says something")
    func everyStepHasCopy() {
        for step in TutorialScript.rules {
            #expect(!step.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Input filtering

    @Test("A wrong digit does not advance, and is not silent")
    func wrongDigitIsRefused() {
        let engine = TutorialEngine()
        engine.advance()          // step 2, reading
        engine.advance()          // step 3, requireEntry 2 at r2c2
        guard case .requireEntry(_, let cell, let digit) = engine.step else {
            Issue.record("expected a requireEntry step")
            return
        }
        let before = engine.index
        engine.handleDigit(digit == 1 ? 2 : 1)
        #expect(engine.index == before)
        #expect(engine.feedback != nil)
        #expect(engine.rejections == 1)
        #expect(engine.displayGame.board.entries[cell] == nil)
    }

    @Test("A tap away from the target is refused")
    func offTargetTapIsRefused() {
        let engine = TutorialEngine()
        engine.advance()
        engine.advance()
        guard case .requireEntry(_, let cell, _) = engine.step else {
            Issue.record("expected a requireEntry step")
            return
        }
        let elsewhere = Cell(cell.row == 0 ? 1 : 0, cell.col)
        engine.handleTap(elsewhere)
        #expect(engine.rejections == 1)
        #expect(engine.displayGame.selected == cell, "selection must stay on the target")
    }

    @Test("Reading steps refuse board input rather than accepting it quietly")
    func readingStepsAreLocked() {
        let engine = TutorialEngine()
        #expect(engine.step.advancesOnNext)
        engine.handleDigit(1)
        engine.handleTap(Cell(0, 0))
        #expect(engine.rejections == 2)
        #expect(engine.displayGame.board.entries.isEmpty)
    }

    @Test("The correct digit places it and moves on")
    func correctDigitAdvances() {
        let engine = TutorialEngine()
        engine.advance()
        engine.advance()
        guard case .requireEntry(_, let cell, let digit) = engine.step else {
            Issue.record("expected a requireEntry step")
            return
        }
        let before = engine.index
        engine.handleDigit(digit)
        #expect(engine.displayGame.board.entries[cell] == digit)
        #expect(engine.index > before)
        #expect(engine.rejections == 0)
    }

    // MARK: - Hand-holding

    @Test("Required steps pre-select their cell, so the player only presses a digit")
    func requiredStepsPrimeTheSelection() {
        let engine = TutorialEngine()
        var seen = 0
        for _ in 0..<TutorialScript.rules.count {
            if case .requireEntry(_, let cell, let digit) = engine.step {
                #expect(engine.displayGame.selected == cell)
                seen += 1
                engine.handleDigit(digit)
            } else if engine.canAdvance {
                engine.advance()
            } else {
                break
            }
        }
        #expect(seen >= 4, "the tutorial should walk the player through several placements")
    }

    @Test("Notes mode is off when the board is handed over")
    func notesModeIsOffAtSolveFreely() {
        let engine = TutorialEngine()
        // Force it on mid-script the way a stray tap once could.
        engine.displayGame.notesMode = true
        while !engine.isFinished {
            if case .solveFreely = engine.step { break }
            if case .requireEntry(_, _, let digit) = engine.step {
                engine.handleDigit(digit)
            } else {
                engine.advance()
            }
        }
        guard case .solveFreely = engine.step else {
            Issue.record("never reached solveFreely")
            return
        }
        #expect(engine.displayGame.notesMode == false)
    }

    // MARK: - The one that matters

    @Test("The whole script can be completed by following it")
    func scriptIsCompletable() {
        let engine = TutorialEngine()
        let puzzle = TutorialScript.board
        var guard_ = 0

        while !engine.isFinished && guard_ < 200 {
            guard_ += 1
            switch engine.step {
            case .say, .sayHighlighting:
                engine.advance()
            case .requireEntry(_, _, let digit):
                engine.handleDigit(digit)
            case .solveFreely:
                // Play the remaining cells the way the copy tells you to:
                // tap a cell, press the right digit.
                for row in 0..<puzzle.size {
                    for col in 0..<puzzle.size {
                        let cell = Cell(row, col)
                        guard engine.displayGame.board.entries[cell] == nil else { continue }
                        engine.handleTap(cell)
                        engine.handleDigit(puzzle.solutionValue(at: cell))
                    }
                }
            case .celebrate:
                break
            }
        }

        #expect(engine.isFinished, "the script wedged after \(guard_) actions")
        if case .celebrate = engine.step {} else {
            Issue.record("finished on \(engine.step), not the celebration")
        }
        #expect(engine.displayGame.board.isSolved(for: puzzle))
        #expect(engine.rejections == 0, "following the instructions should never be refused")
    }
}
