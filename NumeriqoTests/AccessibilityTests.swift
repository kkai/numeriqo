//
//  AccessibilityTests.swift
//  NumeriqoTests
//
//  What VoiceOver says about the board (BoardSpeech), the notes-clearing the
//  cell's "Clear" action relies on, and Increase Contrast. 3.1's accessibility
//  work; see docs/ACCESSIBILITY.md.
//

import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Numeriqo

@Suite @MainActor struct BoardSpeechTests {

    private func makeGame(size: Int = 5) throws -> NumeriqoGame {
        let generated = try #require(PuzzleGenerator.generate(size: size, seed: 4242))
        return NumeriqoGame(puzzle: generated.puzzle, difficulty: .steady)
    }

    @Test func positionsCountFromOne() {
        #expect(BoardSpeech.position(Cell(0, 0)) == "row 1, column 1")
        #expect(BoardSpeech.position(Cell(3, 4)).capitalizedFirst == "Row 4, column 5")
    }

    @Test func cellValueNamesContentsThenCage() throws {
        let game = try makeGame()
        let cell = try #require(game.puzzle.cages.first { !$0.isFreebie }?.cells.first)
        let cage = try #require(game.puzzle.cage(containing: cell))

        #expect(BoardSpeech.cellValue(game, at: cell) == "empty, \(BoardSpeech.cage(cage))")

        game.notesMode = true
        game.place(1, at: cell)
        game.place(3, at: cell)
        #expect(BoardSpeech.cellValue(game, at: cell).hasPrefix("notes 1, 3, cage "))

        game.notesMode = false
        let answer = game.puzzle.solutionValue(at: cell)
        game.place(answer, at: cell)
        #expect(BoardSpeech.cellValue(game, at: cell).hasPrefix("\(answer), cage "))
    }

    @Test func aWrongDigitIsSpokenAsIncorrect() throws {
        let game = try makeGame()
        let cell = Cell(0, 0)
        let wrong = game.puzzle.solutionValue(at: cell) % game.puzzle.size + 1
        game.place(wrong, at: cell)
        #expect(BoardSpeech.cellValue(game, at: cell).hasPrefix("\(wrong), incorrect"))
    }

    @Test func freeCellsAndOperationsAreSpokenInWords() {
        let free = Cage(cells: [Cell(0, 0)], operation: .none, target: 4)
        let times = Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .multiply, target: 12)
        #expect(BoardSpeech.cage(free) == "free cell 4")
        #expect(BoardSpeech.cage(times) == "cage 12 times, 2 cells")
    }

    @Test func aPlacementIsNamed() throws {
        let game = try makeGame()
        let before = game.board
        let cell = Cell(1, 2)
        let digit = game.puzzle.solutionValue(at: cell)
        game.place(digit, at: cell)
        let spoken = try #require(BoardSpeech.boardChanged(old: before, new: game.board, puzzle: game.puzzle))
        #expect(spoken.hasPrefix("\(digit) at row 2, column 3"))
    }

    @Test func notesAloneSayNothing() throws {
        let game = try makeGame()
        let before = game.board
        game.toggleNote(2, at: Cell(0, 0))
        #expect(BoardSpeech.boardChanged(old: before, new: game.board, puzzle: game.puzzle) == nil)
    }

    @Test func aClearIsNamed() throws {
        let game = try makeGame()
        game.place(1, at: Cell(0, 0))
        let before = game.board
        game.clear(at: Cell(0, 0))
        #expect(BoardSpeech.boardChanged(old: before, new: game.board, puzzle: game.puzzle)
                == "row 1, column 1 cleared")
    }

    /// Completing a row is news; it is what the line-complete haptic marks.
    @Test func completingARowSaysSo() throws {
        let game = try makeGame()
        let size = game.puzzle.size
        for col in 0..<(size - 1) {
            game.place(game.puzzle.solutionValue(at: Cell(0, col)), at: Cell(0, col))
        }
        let before = game.board
        let last = Cell(0, size - 1)
        game.place(game.puzzle.solutionValue(at: last), at: last)
        let spoken = try #require(BoardSpeech.boardChanged(old: before, new: game.board, puzzle: game.puzzle))
        #expect(spoken.contains("row 1 complete"))
    }

    @Test func manyPlacementsAreCounted() throws {
        let game = try makeGame()
        let before = game.board
        var after = before
        for col in 0..<4 { after.entries[Cell(2, col)] = game.puzzle.solutionValue(at: Cell(2, col)) }
        let spoken = try #require(BoardSpeech.boardChanged(old: before, new: after, puzzle: game.puzzle))
        #expect(spoken.hasPrefix("4 digits placed"))
    }

    /// The cell's "Clear" action on a cell holding only notes. The pad's Erase
    /// cannot do this, so it gets its own undoable move.
    @Test func clearingNotesIsOneUndoableMove() throws {
        let game = try makeGame()
        let cell = Cell(0, 0)
        game.toggleNote(1, at: cell)
        game.toggleNote(2, at: cell)
        game.clearNotes(at: cell)
        #expect(game.board.notes(at: cell).isEmpty)
        game.undo()
        #expect(game.board.notes(at: cell) == [1, 2])
    }

    @Test func clearingNotesLeavesADigitAlone() throws {
        let game = try makeGame()
        let cell = Cell(0, 0)
        game.place(game.puzzle.solutionValue(at: cell), at: cell)
        let undoDepth = game.undoStack.count
        game.clearNotes(at: cell)
        #expect(game.board.entries[cell] != nil)
        #expect(game.undoStack.count == undoDepth, "nothing to clear, so nothing to undo")
    }
}

#if canImport(UIKit)
/// Increase Contrast, resolved the way UIKit resolves it.
@Suite struct ContrastTests {

    private static func traits(dark: Bool, high: Bool) -> UITraitCollection {
        UITraitCollection { t in
            t.userInterfaceStyle = dark ? .dark : .light
            t.accessibilityContrast = high ? .high : .normal
        }
    }

    /// Flattens `color` (which may be translucent) over `background`.
    private static func components(_ color: Color, over background: Color, dark: Bool, high: Bool) -> (Double, Double, Double) {
        let t = traits(dark: dark, high: high)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        UIColor(color).resolvedColor(with: t).getRed(&r, green: &g, blue: &b, alpha: &a)
        UIColor(background).resolvedColor(with: t).getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return (Double(r * a + br * (1 - a)), Double(g * a + bg * (1 - a)), Double(b * a + bb * (1 - a)))
    }

    private static func luminance(_ c: (Double, Double, Double)) -> Double {
        func lin(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(c.0) + 0.7152 * lin(c.1) + 0.0722 * lin(c.2)
    }

    static func ratio(_ color: Color, on background: Color, dark: Bool, high: Bool) -> Double {
        let fg = luminance(components(color, over: background, dark: dark, high: high))
        let bg = luminance(components(background, over: background, dark: dark, high: high))
        return (max(fg, bg) + 0.05) / (min(fg, bg) + 0.05)
    }

    /// With Increase Contrast on, every colour that carries meaning or text
    /// reaches 7:1 (WCAG AAA) on both board surfaces, in light and dark.
    @Test(arguments: [false, true])
    func meaningfulColoursReachAAAWhenAsked(dark: Bool) {
        let tokens: [(String, Color)] = [
            ("inkSecondary", Theme.inkSecondary), ("clueInk", Theme.clueInk),
            ("error", Theme.error),
        ] + Difficulty.allCases.map { ("accent \($0)", Theme.tierAccent($0)) }
        for (name, token) in tokens {
            for background in [Theme.paper, Theme.surface] {
                let r = Self.ratio(token, on: background, dark: dark, high: true)
                #expect(r >= 7, "\(name) is \(r) in \(dark ? "dark" : "light") at high contrast")
            }
        }
    }

    /// The tokens that recede on purpose must actually change when asked.
    /// Paper, surface and ink are already at full strength and stay put.
    @Test(arguments: [false, true])
    func recedingTokensChangeAtHighContrast(dark: Bool) {
        let receding: [Color] = [Theme.inkSecondary, Theme.clueInk, Theme.cellRule, Theme.cageRule, Theme.error]
            + Difficulty.allCases.map { Theme.tierAccent($0) }
        for token in receding {
            let ui = UIColor(token)
            #expect(ui.resolvedColor(with: Self.traits(dark: dark, high: false))
                    != ui.resolvedColor(with: Self.traits(dark: dark, high: true)))
        }
        let ink = UIColor(Theme.ink)
        #expect(ink.resolvedColor(with: Self.traits(dark: dark, high: false))
                == ink.resolvedColor(with: Self.traits(dark: dark, high: true)))
    }
}
#endif
