//
//  Models.swift
//  Numeriqo
//
//  Core engine value types. No SwiftUI, no UIKit — see docs/ARCHITECTURE.md.
//

import Foundation

// MARK: - Position

nonisolated struct Cell: Hashable, Sendable, Comparable, Codable {
    let row: Int
    let col: Int

    init(_ row: Int, _ col: Int) {
        self.row = row
        self.col = col
    }

    /// Two cells conflict when the Latin constraint forbids them holding the
    /// same digit — i.e. they share a row or a column.
    func conflicts(with other: Cell) -> Bool {
        row == other.row || col == other.col
    }

    static func < (lhs: Cell, rhs: Cell) -> Bool {
        (lhs.row, lhs.col) < (rhs.row, rhs.col)
    }
}

// MARK: - Operation

nonisolated enum Operation: String, Sendable, CaseIterable, Codable {
    /// A single-cell cage. The target *is* the digit.
    case none
    case add
    case subtract
    case multiply
    case divide

    /// Subtraction and division are non-associative, so they are restricted to
    /// two-cell cages — the standard (Will Shortz) convention. See docs/RULES.md §3.4.
    var requiresExactlyTwoCells: Bool {
        self == .subtract || self == .divide
    }

    var symbol: String {
        switch self {
        case .none: ""
        case .add: "+"
        case .subtract: "−"
        case .multiply: "×"
        case .divide: "÷"
        }
    }

    /// Whether `digits` satisfy this operation for `target`.
    ///
    /// `subtract` and `divide` are order-independent: the player is never told
    /// which cell is the minuend or dividend.
    func satisfies(_ digits: [Int], target: Int) -> Bool {
        switch self {
        case .none:
            return digits.count == 1 && digits[0] == target
        case .add:
            return digits.reduce(0, +) == target
        case .multiply:
            return digits.reduce(1, *) == target
        case .subtract:
            guard digits.count == 2 else { return false }
            return abs(digits[0] - digits[1]) == target
        case .divide:
            guard digits.count == 2 else { return false }
            let hi = max(digits[0], digits[1])
            let lo = min(digits[0], digits[1])
            guard lo > 0, hi % lo == 0 else { return false }
            return hi / lo == target
        }
    }
}

// MARK: - Cage

nonisolated struct Cage: Sendable, Codable, Equatable {
    let cells: [Cell]
    let operation: Operation
    let target: Int

    init(cells: [Cell], operation: Operation, target: Int) {
        precondition(!cells.isEmpty, "a cage must contain at least one cell")
        self.cells = cells.sorted()
        self.operation = operation
        self.target = target
    }

    /// Where the clue label draws: the top-left cell in reading order.
    var anchor: Cell { cells[0] }

    var isFreebie: Bool { cells.count == 1 }

    /// A cage whose cells all share one row or one column. Such a cage can
    /// never repeat a digit; a dog-leg cage can. This distinction drives
    /// combination enumeration — see docs/TECHNIQUES.md T2.
    var isStraightLine: Bool {
        let rows = Set(cells.map(\.row))
        let cols = Set(cells.map(\.col))
        return rows.count == 1 || cols.count == 1
    }

    var clueText: String {
        operation == .none ? "\(target)" : "\(target)\(operation.symbol)"
    }

    /// Structural validity, independent of any solution.
    func isWellFormed(gridSize: Int) -> Bool {
        guard cells.allSatisfy({ $0.row >= 0 && $0.row < gridSize && $0.col >= 0 && $0.col < gridSize })
        else { return false }
        guard Set(cells).count == cells.count else { return false }
        guard isOrthogonallyConnected else { return false }

        switch operation {
        case .none:
            return cells.count == 1 && (1...gridSize).contains(target)
        case .subtract:
            // target 0 would mean a repeat, which makes the clue useless.
            return cells.count == 2 && target > 0 && target < gridSize
        case .divide:
            // target 1 would mean a repeat.
            return cells.count == 2 && target > 1 && target <= gridSize
        case .add, .multiply:
            return cells.count >= 2 && target > 0
        }
    }

    /// Cages must be edge-connected: every cell reachable from any other by
    /// orthogonal steps within the cage.
    var isOrthogonallyConnected: Bool {
        guard let start = cells.first else { return false }
        var seen: Set<Cell> = [start]
        var stack = [start]
        let members = Set(cells)

        while let cell = stack.popLast() {
            let neighbours = [
                Cell(cell.row - 1, cell.col), Cell(cell.row + 1, cell.col),
                Cell(cell.row, cell.col - 1), Cell(cell.row, cell.col + 1),
            ]
            for n in neighbours where members.contains(n) && !seen.contains(n) {
                seen.insert(n)
                stack.append(n)
            }
        }
        return seen.count == cells.count
    }
}

// MARK: - Puzzle

nonisolated struct Puzzle: Sendable, Codable, Equatable {
    let size: Int
    let cages: [Cage]
    /// Row-major. The unique solution, proved at generation time.
    let solution: [[Int]]

    func solutionValue(at cell: Cell) -> Int {
        solution[cell.row][cell.col]
    }

    /// The cage containing a cell, or nil if the partition is malformed.
    func cage(containing cell: Cell) -> Cage? {
        cages.first { $0.cells.contains(cell) }
    }

    /// Every cell belongs to exactly one cage, every cage is well formed, and
    /// the stored solution is a Latin square satisfying every cage.
    func isWellFormed() -> Bool {
        let all = cages.flatMap(\.cells)
        guard Set(all).count == all.count, all.count == size * size else { return false }
        guard cages.allSatisfy({ $0.isWellFormed(gridSize: size) }) else { return false }
        guard LatinSquare.isValid(solution, size: size) else { return false }
        return cages.allSatisfy { cage in
            cage.operation.satisfies(cage.cells.map { solution[$0.row][$0.col] }, target: cage.target)
        }
    }
}

// MARK: - Latin square helpers

nonisolated enum LatinSquare {
    /// The digits of any row or column sum to this — the Rule of N (T14).
    static func lineSum(size: Int) -> Int { size * (size + 1) / 2 }

    /// The digits of any row or column multiply to this — the Rule of n! (T16).
    static func lineProduct(size: Int) -> Int { (1...max(size, 1)).reduce(1, *) }

    static func isValid(_ grid: [[Int]], size: Int) -> Bool {
        guard grid.count == size, grid.allSatisfy({ $0.count == size }) else { return false }
        let expected = Set(1...size)
        for i in 0..<size {
            guard Set(grid[i]) == expected else { return false }
            guard Set((0..<size).map { grid[$0][i] }) == expected else { return false }
        }
        return true
    }
}
