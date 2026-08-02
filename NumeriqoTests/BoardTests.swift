//
//  BoardTests.swift
//  NumeriqoTests
//
//  Play-layer behaviour that the engine harness cannot reach, because it needs
//  the @MainActor game model and the view-layer geometry.
//

import Foundation
import Testing
@testable import Numeriqo

@Suite @MainActor struct BoardTests {

    private func makeGame(size: Int = 5) throws -> NumeriqoGame {
        let generated = try #require(PuzzleGenerator.generate(size: size, seed: 4242))
        return NumeriqoGame(puzzle: generated.puzzle, difficulty: .steady)
    }

    // MARK: - Geometry

    @Test func geometryCoversTheBoardAndRoundTripsTaps() {
        let geo = BoardGeometry(size: 6, container: CGSize(width: 390, height: 500))

        // Whole-point cell sizes: fractional ones seam at some scales and not
        // others, which reads as a rendering bug.
        #expect(geo.cellSize == geo.cellSize.rounded(.down))

        for row in 0..<6 {
            for col in 0..<6 {
                let cell = Cell(row, col)
                let hit = geo.cell(at: geo.center(for: cell))
                #expect(hit == cell, "\(cell) did not round-trip through its own centre")
            }
        }
        #expect(geo.cell(at: CGPoint(x: -10, y: -10)) == nil)
    }

    // MARK: - Cage outline

    @Test func cageOutlineIsOneClosedContour() throws {
        let geo = BoardGeometry(size: 5, container: CGSize(width: 350, height: 350))
        // An L-shaped dog-leg: the case where a naive corner inset breaks, and
        // the case that must still trim as a single travelling stroke.
        let cells = [Cell(0, 0), Cell(0, 1), Cell(1, 1)]
        let path = CageOutline(cells: cells, geometry: geo).path(in: geo.boardRect)

        #expect(!path.isEmpty)
        var subpaths = 0
        path.forEach { element in
            if case .move = element { subpaths += 1 }
        }
        #expect(subpaths == 1,
                "outline has \(subpaths) subpaths; .trim would not read as one stroke")
    }

    @Test func cageOutlineStartsDeterministically() throws {
        let geo = BoardGeometry(size: 5, container: CGSize(width: 350, height: 350))
        let cells = [Cell(1, 1), Cell(1, 2), Cell(2, 2), Cell(2, 1)]

        // Built repeatedly, the stroke must begin at the same point every time —
        // otherwise the reveal starts at a random corner on each launch.
        func firstPoint() -> CGPoint? {
            var start: CGPoint?
            CageOutline(cells: cells, geometry: geo)
                .path(in: geo.boardRect)
                .forEach { element in
                    if case .move(let point) = element, start == nil { start = point }
                }
            return start
        }

        let a = try #require(firstPoint())
        for _ in 0..<12 {
            #expect(firstPoint() == a, "cage outline start point is not deterministic")
        }
    }

    // MARK: - Input

    @Test func numberFirstArmsADigitThenPlacesIt() throws {
        let game = try makeGame()
        let target = Cell(0, 0)

        game.press(3)
        #expect(game.activeDigit == 3, "pressing a digit with no selection should arm it")

        game.tap(target)
        #expect(game.board.entries[target] == 3)
    }

    @Test func cellFirstSelectsThenTypes() throws {
        let game = try makeGame()
        let target = Cell(1, 2)

        game.tap(target)
        #expect(game.selected == target)
        // Re-tapping must NOT deselect: a driver re-tapping a selected cell
        // would otherwise look exactly like the app ignoring input.
        game.tap(target)
        #expect(game.selected == target)

        game.press(2)
        #expect(game.board.entries[target] == 2)
    }

    @Test func placingRetiresTheDigitFromPeerNotesAsOneUndo() throws {
        let game = try makeGame()
        let target = Cell(0, 0)
        let peer = Cell(0, 1)

        game.notesMode = true
        game.place(4, at: peer)
        #expect(game.board.notes(at: peer).contains(4))

        game.notesMode = false
        game.place(4, at: target)
        #expect(!game.board.notes(at: peer).contains(4), "peer note survived the placement")

        // One undo must restore both halves.
        game.undo()
        #expect(game.board.entries[target] == nil)
        #expect(game.board.notes(at: peer).contains(4), "undo did not restore the peer note")
    }

    @Test func blockedDigitsUseOnlyTheLatinConstraint() throws {
        let game = try makeGame()
        game.place(1, at: Cell(0, 0))
        #expect(game.isBlocked(digit: 1, at: Cell(0, 3)), "row mate should be blocked")
        #expect(game.isBlocked(digit: 1, at: Cell(3, 0)), "column mate should be blocked")
        #expect(!game.isBlocked(digit: 1, at: Cell(3, 3)), "unrelated cell must not be blocked")
    }

    // MARK: - Errors

    @Test func wrongDigitsAreFlaggedEvenWhenLocallyLegal() throws {
        let game = try makeGame()
        let cell = Cell(0, 0)
        let truth = game.puzzle.solutionValue(at: cell)
        let wrong = truth == 1 ? 2 : 1

        game.place(wrong, at: cell)
        // Nothing about this breaks a visible rule — it is simply not the digit
        // that goes here, which is exactly the error that lets a player drift.
        #expect(!game.isBlocked(digit: wrong, at: cell))
        #expect(game.incorrectCells.contains(cell))

        game.undo()
        #expect(game.incorrectCells.isEmpty)
    }

    // MARK: - Hints

    @Test func hintLoopConvergesAndEveryStepIsCorrect() throws {
        let game = try makeGame()
        var rounds = 0

        while game.phase != .won {
            rounds += 1
            #expect(rounds < 400, "hint loop did not converge")
            guard let step = game.nextStep() else { break }

            // A hint must never place a digit that disagrees with the solution.
            for placement in step.placements {
                #expect(game.puzzle.solutionValue(at: placement.cell) == placement.digit,
                        "\(step.technique.displayName) proposed a wrong digit")
            }

            let before = game.board
            game.apply(step)
            #expect(game.board != before,
                    "\(step.technique.displayName) applied but changed nothing")
        }

        #expect(game.phase == .won, "applying hints did not finish the puzzle")
        #expect(game.board.isSolved(for: game.puzzle))
    }

    @Test func anyGeneratedPuzzleShipsSolvableAndUnique() throws {
        for seed in UInt64(0)..<4 {
            let generated = try #require(PuzzleGenerator.generate(size: 6, seed: seed &* 977))
            #expect(generated.grade?.solved == true, "seed \(seed) shipped unsolvable")
            #expect(BacktrackingSolver.countSolutions(
                size: 6, cages: generated.puzzle.cages, limit: 2) == 1)
        }
    }
}
