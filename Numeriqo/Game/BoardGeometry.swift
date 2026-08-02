//
//  BoardGeometry.swift
//  Numeriqo
//
//  One source of truth for where everything on the board sits.
//
//  The legacy app mixed absolute cage geometry with stack-laid cells and needed
//  half-point fudges to reconcile the two. Here every layer — cells, hairlines,
//  cage outlines, clue labels, and the hint's drawn argument — is positioned
//  against this single struct.
//
//  It is also what makes the drawn argument possible at all: connecting two
//  cells with a stroke requires knowing their frames, and computing rects up
//  front means no `anchorPreference` plumbing.
//

import SwiftUI

nonisolated struct BoardGeometry: Equatable, Sendable {
    let size: Int
    let cellSize: CGFloat
    let origin: CGPoint

    /// Fits a `size × size` board inside `container`, centred.
    ///
    /// `cellSize` is floored to a whole point: fractional cell sizes put seams
    /// between cells on some scales and not others, which reads as a rendering
    /// bug. The cap keeps a board on a large iPad from ballooning until it stops
    /// reading as a grid.
    init(size: Int, container: CGSize, maxCellSize: CGFloat = 72) {
        self.size = max(size, 1)
        let available = min(container.width, container.height)
        let fitted = (available / CGFloat(self.size)).rounded(.down)
        self.cellSize = max(min(fitted, maxCellSize), 1)

        let board = self.cellSize * CGFloat(self.size)
        self.origin = CGPoint(
            x: ((container.width - board) / 2).rounded(),
            y: ((container.height - board) / 2).rounded()
        )
    }

    var boardLength: CGFloat { cellSize * CGFloat(size) }

    var boardRect: CGRect {
        CGRect(x: origin.x, y: origin.y, width: boardLength, height: boardLength)
    }

    func rect(for cell: Cell) -> CGRect {
        CGRect(
            x: origin.x + CGFloat(cell.col) * cellSize,
            y: origin.y + CGFloat(cell.row) * cellSize,
            width: cellSize,
            height: cellSize
        )
    }

    func center(for cell: Cell) -> CGPoint {
        let r = rect(for: cell)
        return CGPoint(x: r.midX, y: r.midY)
    }

    /// The cell under a point, or nil outside the board.
    func cell(at point: CGPoint) -> Cell? {
        guard boardRect.contains(point) else { return nil }
        let col = Int((point.x - origin.x) / cellSize)
        let row = Int((point.y - origin.y) / cellSize)
        guard row >= 0, row < size, col >= 0, col < size else { return nil }
        return Cell(row, col)
    }

    // MARK: - Derived type sizes

    var digitSize: CGFloat { cellSize * 0.50 }
    var clueSize: CGFloat { max(cellSize * 0.24, 9) }
    var noteSize: CGFloat { max(cellSize * 0.19, 7) }

    /// Vertical space the clue occupies at the top of an anchor cell. Notes in
    /// that cell start below it — otherwise "144x" prints straight through
    /// "1 2 3" and neither can be read.
    var clueGutter: CGFloat { clueSize * 1.15 }
}
