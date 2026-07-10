//
//  MathMazeSolver.swift
//  Numeriqo
//
//  Backtracking solver with constraint propagation for MathMaze puzzles.
//  Pure logic — no UI dependencies. Cage arithmetic delegates to
//  Operation.calculate so solver semantics always match what the game
//  accepts at win-check time (notably: subtract is abs, divide is
//  truncating max/min with no divisibility requirement).
//

import Foundation

/// Lightweight cage representation for solving (Cage itself carries UI color state).
struct SolverCage: Hashable {
    let positions: [Position]
    let operation: Operation
    let target: Int
}

enum MathMazeSolver {

    struct Stats {
        /// Cells fixed by naked-single propagation (no guessing needed).
        var propagationSolvedCells = 0
        /// Branch points where the solver had to guess among ≥2 candidates.
        var guessCount = 0
        /// Deepest guess stack reached during the search.
        var maxDepth = 0
    }

    /// Finds up to `limit` complete solutions. Early-exits once `limit` is reached.
    static func solutions(size: Int, cages: [SolverCage], partial: [[Int?]]? = nil, limit: Int) -> [[[Int]]] {
        var stats = Stats()
        return solutions(size: size, cages: cages, partial: partial, limit: limit, stats: &stats)
    }

    static func countSolutions(size: Int, cages: [SolverCage], limit: Int = 2) -> Int {
        solutions(size: size, cages: cages, limit: limit).count
    }

    static func solve(size: Int, cages: [SolverCage], partial: [[Int?]]? = nil) -> [[Int]]? {
        solutions(size: size, cages: cages, partial: partial, limit: 1).first
    }

    static func solveWithStats(size: Int, cages: [SolverCage], partial: [[Int?]]? = nil) -> (solution: [[Int]]?, stats: Stats) {
        var stats = Stats()
        let found = solutions(size: size, cages: cages, partial: partial, limit: 1, stats: &stats)
        return (found.first, stats)
    }

    private static func solutions(size: Int, cages: [SolverCage], partial: [[Int?]]?, limit: Int, stats: inout Stats) -> [[[Int]]] {
        guard size >= 1, size <= 15, limit > 0 else { return [] }
        var engine = Engine(size: size, cages: cages)
        guard engine.isConsistent, engine.apply(partial: partial) else { return [] }
        engine.search(limit: limit, depth: 0, stats: &stats)
        return engine.found
    }

    // MARK: - Engine

    private struct Engine {
        let size: Int
        let cellCount: Int
        let fullMask: UInt16          // bits 1...size set
        let cages: [SolverCage]
        var cageCells: [[Int]]        // cage index -> flat cell indices
        var cagesOfCell: [[Int]]      // flat cell index -> cage indices containing it
        var values: [Int]             // 0 = empty
        var rowUsed: [UInt16]
        var colUsed: [UInt16]
        var found: [[[Int]]] = []
        var isConsistent = true

        init(size: Int, cages: [SolverCage]) {
            self.size = size
            self.cellCount = size * size
            self.fullMask = UInt16((1 << (size + 1)) - 2)
            self.cages = cages
            self.cageCells = []
            self.cagesOfCell = Array(repeating: [], count: cellCount)
            self.values = Array(repeating: 0, count: cellCount)
            self.rowUsed = Array(repeating: 0, count: size)
            self.colUsed = Array(repeating: 0, count: size)

            for (index, cage) in cages.enumerated() {
                var cells: [Int] = []
                for pos in cage.positions {
                    guard pos.row >= 0, pos.row < size, pos.col >= 0, pos.col < size else {
                        isConsistent = false
                        cageCells.append([])
                        return
                    }
                    let cell = pos.row * size + pos.col
                    cells.append(cell)
                    cagesOfCell[cell].append(index)
                }
                cageCells.append(cells)
            }
        }

        mutating func apply(partial: [[Int?]]?) -> Bool {
            guard let partial else { return allCagesCompletable() }
            guard partial.count == size else { return false }
            for row in 0..<size {
                guard partial[row].count == size else { return false }
                for col in 0..<size {
                    guard let value = partial[row][col] else { continue }
                    guard value >= 1, value <= size else { return false }
                    let bit = UInt16(1 << value)
                    if rowUsed[row] & bit != 0 || colUsed[col] & bit != 0 { return false }
                    values[row * size + col] = value
                    rowUsed[row] |= bit
                    colUsed[col] |= bit
                }
            }
            return allCagesCompletable()
        }

        private mutating func allCagesCompletable() -> Bool {
            for index in cages.indices where !cageCompletable(index) {
                return false
            }
            return true
        }

        // MARK: Search

        mutating func search(limit: Int, depth: Int, stats: inout Stats) {
            var trail: [Int] = []

            while true {
                // Find the unassigned cell with the fewest row/col-legal candidates (MRV).
                var bestCell = -1
                var bestMask: UInt16 = 0
                var bestCount = Int.max
                for cell in 0..<cellCount where values[cell] == 0 {
                    let mask = fullMask & ~rowUsed[cell / size] & ~colUsed[cell % size]
                    let count = mask.nonzeroBitCount
                    if count < bestCount {
                        bestCount = count
                        bestCell = cell
                        bestMask = mask
                        if count == 0 { break }
                    }
                }

                if bestCell == -1 {
                    // Grid complete; every cage was exact-checked on its last assignment.
                    found.append(currentGrid())
                    break
                }
                if bestCount == 0 { break }

                // Filter row/col-legal candidates through exact cage feasibility
                // so cage-forced cells count as propagation, not guesses.
                var filteredMask: UInt16 = 0
                var probe = bestMask
                while probe != 0 {
                    let value = probe.trailingZeroBitCount
                    probe &= probe - 1
                    if assign(bestCell, value) {
                        filteredMask |= UInt16(1 << value)
                        unassign(bestCell, value)
                    }
                }
                let candidateCount = filteredMask.nonzeroBitCount
                if candidateCount == 0 { break }

                if candidateCount == 1 {
                    let value = filteredMask.trailingZeroBitCount
                    _ = assign(bestCell, value)
                    trail.append(bestCell)
                    stats.propagationSolvedCells += 1
                    continue
                }

                // Branch point: try each candidate.
                stats.guessCount += 1
                stats.maxDepth = max(stats.maxDepth, depth + 1)
                var mask = filteredMask
                while mask != 0 {
                    let value = mask.trailingZeroBitCount
                    mask &= mask - 1
                    if assign(bestCell, value) {
                        search(limit: limit, depth: depth + 1, stats: &stats)
                        unassign(bestCell, value)
                        if found.count >= limit { break }
                    }
                }
                break
            }

            for cell in trail.reversed() {
                unassign(cell, values[cell])
            }
        }

        /// Places a value and verifies every cage containing the cell is still
        /// completable. Rolls back and returns false on failure.
        private mutating func assign(_ cell: Int, _ value: Int) -> Bool {
            let bit = UInt16(1 << value)
            values[cell] = value
            rowUsed[cell / size] |= bit
            colUsed[cell % size] |= bit
            for cageIndex in cagesOfCell[cell] where !cageCompletable(cageIndex) {
                unassign(cell, value)
                return false
            }
            return true
        }

        private mutating func unassign(_ cell: Int, _ value: Int) {
            let bit = UInt16(1 << value)
            values[cell] = 0
            rowUsed[cell / size] &= ~bit
            colUsed[cell % size] &= ~bit
        }

        // MARK: Cage feasibility

        /// Exact feasibility: can the cage's unassigned cells be filled with
        /// row/col-legal values so Operation.calculate hits the target?
        /// Cages are ≤4 cells, so exhaustive enumeration is cheap.
        private mutating func cageCompletable(_ cageIndex: Int) -> Bool {
            let cage = cages[cageIndex]
            var filled: [Int] = []
            var empty: [Int] = []
            for cell in cageCells[cageIndex] {
                if values[cell] != 0 {
                    filled.append(values[cell])
                } else {
                    empty.append(cell)
                }
            }
            if empty.isEmpty {
                return cage.operation.calculate(filled) == cage.target
            }
            return completeCage(cage, empty: empty, index: 0, filled: &filled)
        }

        private mutating func completeCage(_ cage: SolverCage, empty: [Int], index: Int, filled: inout [Int]) -> Bool {
            if index == empty.count {
                return cage.operation.calculate(filled) == cage.target
            }
            let cell = empty[index]
            var mask = fullMask & ~rowUsed[cell / size] & ~colUsed[cell % size]
            while mask != 0 {
                let value = mask.trailingZeroBitCount
                mask &= mask - 1
                let bit = UInt16(1 << value)
                rowUsed[cell / size] |= bit
                colUsed[cell % size] |= bit
                filled.append(value)
                let ok = completeCage(cage, empty: empty, index: index + 1, filled: &filled)
                filled.removeLast()
                rowUsed[cell / size] &= ~bit
                colUsed[cell % size] &= ~bit
                if ok { return true }
            }
            return false
        }

        private func currentGrid() -> [[Int]] {
            (0..<size).map { row in
                (0..<size).map { col in values[row * size + col] }
            }
        }
    }
}
