//
//  BoardSpeech.swift
//  Numeriqo
//
//  Everything VoiceOver says about the board. The board is drawn, so speech
//  has to carry what sight gets from the grid: where a cell is, which cage it
//  belongs to, what just changed, and what a hint is pointing at.
//
//  Ported from Just Kakuro's BoardSpeech; the words are Numeriqo's.
//

import SwiftUI

enum BoardSpeech {

    /// 1-based, the way people count.
    static func position(_ cell: Cell) -> String {
        "row \(cell.row + 1), column \(cell.col + 1)"
    }

    /// "cage 12 plus, 3 cells", or "free cell 4" for a single-cell cage.
    static func cage(_ cage: Cage) -> String {
        cage.isFreebie
            ? "free cell \(cage.target)"
            : "cage \(cage.target) \(spoken(cage.operation)), \(cage.cells.count) cells"
    }

    /// The cell's content, then its cage: "7, incorrect, cage 12 plus, 3 cells".
    static func cellValue(_ game: NumeriqoGame, at cell: Cell) -> String {
        var parts: [String] = []
        if let entry = game.board.entries[cell] {
            parts.append("\(entry)")
            if game.incorrectCells.contains(cell) { parts.append("incorrect") }
        } else {
            let notes = game.board.notes(at: cell).sorted()
            parts.append(notes.isEmpty ? "empty" : "notes \(notes.map(String.init).joined(separator: ", "))")
        }
        if let cage = game.puzzle.cage(containing: cell) {
            parts.append(self.cage(cage))
        }
        return parts.joined(separator: ", ")
    }

    /// What changed on the board, for a player who can't see it change.
    ///
    /// Names up to three placements, then counts. Completed cages and lines
    /// are named too: they are the moments the haptics mark, and the only
    /// progress a VoiceOver player otherwise has to infer.
    static func boardChanged(old: BoardState, new: BoardState, puzzle: Puzzle) -> String? {
        var parts: [String] = []
        let placed = new.entries.filter { old.entries[$0.key] != $0.value }.sorted { $0.key < $1.key }
        let cleared = old.entries.keys.filter { new.entries[$0] == nil }.sorted()

        if placed.count <= 3 {
            parts += placed.map { "\($0.value) at \(position($0.key))" }
        } else {
            parts.append("\(placed.count) digits placed")
        }
        if cleared.count == 1, let cell = cleared.first {
            parts.append("\(position(cell)) cleared")
        } else if cleared.count > 1 {
            parts.append("\(cleared.count) cells cleared")
        }

        // Completion is only news when a digit went in.
        if !placed.isEmpty {
            for cage in puzzle.cages where !cage.isFreebie
                && !isSatisfied(cage, in: old) && isSatisfied(cage, in: new) {
                parts.append("cage \(cage.target) \(spoken(cage.operation)) complete")
            }
            for line in lines(size: puzzle.size)
                where !isComplete(line, in: old, size: puzzle.size) && isComplete(line, in: new, size: puzzle.size) {
                parts.append("\(line.kind == .row ? "row" : "column") \(line.index + 1) complete")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ". ")
    }

    /// The hint as shown, plus where it points. The banner says "these cells";
    /// this names them.
    static func spokenHint(_ hint: Hint) -> String {
        var parts = [hint.text]
        if hint.showsArgument, !hint.focusCells.isEmpty, hint.focusCells.count <= 4 {
            parts.append("Look at " + hint.focusCells.map(position).joined(separator: "; ") + ".")
        }
        if hint.level == .resolution, !hint.isError, let step = hint.step {
            let placements = step.placements.map { "\($0.digit) at \(position($0.cell))" }
            if !placements.isEmpty { parts.append("Place " + placements.joined(separator: ", ") + ".") }
        }
        return parts.joined(separator: " ")
    }

    static func announce(_ text: String) {
        AccessibilityNotification.Announcement(text).post()
    }

    static func spoken(_ operation: Operation) -> String {
        switch operation {
        case .none: "free"
        case .add: "plus"
        case .subtract: "minus"
        case .multiply: "times"
        case .divide: "divided by"
        }
    }

    // MARK: - Private

    private static func isSatisfied(_ cage: Cage, in board: BoardState) -> Bool {
        let digits = cage.cells.compactMap { board.entries[$0] }
        return digits.count == cage.cells.count && cage.operation.satisfies(digits, target: cage.target)
    }

    private static func lines(size: Int) -> [Line] {
        (0..<size).flatMap { [Line(kind: .row, index: $0), Line(kind: .column, index: $0)] }
    }

    private static func isComplete(_ line: Line, in board: BoardState, size: Int) -> Bool {
        let values = line.cells(size: size).compactMap { board.entries[$0] }
        return values.count == size && Set(values).count == size
    }
}

/// An edit made from a cell's accessibility actions.
enum CellEdit: Equatable {
    case digit(Int)
    case clear
}

extension String {
    /// "row 2, column 3" → "Row 2, column 3".
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
