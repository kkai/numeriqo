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
        /// Cells fixed by propagation (naked/hidden singles — no guessing).
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

    /// Number of feasible value tuples per cage (same order as `cages`),
    /// or nil for a malformed/unsatisfiable cage set. Feeds difficulty
    /// rating: ambiguous cages make puzzles harder.
    static func tupleCounts(size: Int, cages: [SolverCage]) -> [Int]? {
        guard size >= 1, size <= 15, let engine = Engine(size: size, cages: cages) else { return nil }
        return engine.cageTuples.map(\.count)
    }

    /// Precomputed, reusable validation context: cage tuple enumeration runs
    /// once per puzzle, then many cheap partial-grid checks share it.
    struct ValidationContext {
        private let engine: Engine

        init?(size: Int, cages: [SolverCage]) {
            guard size >= 1, size <= 15, let engine = Engine(size: size, cages: cages) else { return nil }
            self.engine = engine
        }

        /// Single-pass local consistency: the partial applies without row/col
        /// duplicates, no empty cell has an empty row/col candidate mask, and
        /// every cage keeps at least one live tuple. Deliberately NO singles
        /// propagation and NO search — solutions are unique, so anything
        /// stronger would reject every digit but the correct one and leak the
        /// solution through the number pad.
        func isLocallyConsistent(partial: [[Int?]]) -> Bool {
            var probe = engine
            guard probe.apply(partial: partial) else { return false }
            return probe.localConsistencyCheck()
        }
    }

    private static func solutions(size: Int, cages: [SolverCage], partial: [[Int?]]?, limit: Int, stats: inout Stats) -> [[[Int]]] {
        guard size >= 1, size <= 15, limit > 0 else { return [] }
        guard var engine = Engine(size: size, cages: cages) else { return [] }
        guard engine.apply(partial: partial) else { return [] }
        var found: [[[Int]]] = []
        engine.search(limit: limit, depth: 0, found: &found, stats: &stats)
        return found
    }

    // MARK: - Engine

    private struct Engine {
        let size: Int
        let cellCount: Int
        let fullMask: UInt16                  // bits 1...size set
        let cageCells: [[Int]]                // cage index -> flat cell indices
        let cageTuples: [[[Int]]]             // cage index -> feasible value tuples (aligned with cageCells)
        let cagesOfCell: [[Int]]              // flat cell index -> cage indices containing it
        var values: [Int]                     // 0 = empty
        var rowUsed: [UInt16]
        var colUsed: [UInt16]
        var masks: [UInt16]                   // propagated candidate masks for unassigned cells

        /// Returns nil when a cage is malformed or has no feasible values at all.
        init?(size: Int, cages: [SolverCage]) {
            self.size = size
            self.cellCount = size * size
            self.fullMask = UInt16((1 << (size + 1)) - 2)
            self.values = Array(repeating: 0, count: cellCount)
            self.rowUsed = Array(repeating: 0, count: size)
            self.colUsed = Array(repeating: 0, count: size)
            self.masks = Array(repeating: 0, count: cellCount)

            var cells: [[Int]] = []
            var tuples: [[[Int]]] = []
            var byCell: [[Int]] = Array(repeating: [], count: cellCount)

            for (index, cage) in cages.enumerated() {
                var cageCellList: [Int] = []
                for pos in cage.positions {
                    guard pos.row >= 0, pos.row < size, pos.col >= 0, pos.col < size else { return nil }
                    let cell = pos.row * size + pos.col
                    cageCellList.append(cell)
                    byCell[cell].append(index)
                }
                let feasible = Engine.enumerateTuples(cage: cage, size: size)
                if feasible.isEmpty { return nil }
                cells.append(cageCellList)
                tuples.append(feasible)
            }

            self.cageCells = cells
            self.cageTuples = tuples
            self.cagesOfCell = byCell
        }

        /// All value assignments for a cage that hit the target (via
        /// Operation.calculate) and respect distinctness between cage cells
        /// sharing a row or column. Cages are ≤4 cells, so exhaustive
        /// enumeration at init is cheap and pays for itself during search.
        private static func enumerateTuples(cage: SolverCage, size: Int) -> [[Int]] {
            let positions = cage.positions
            var result: [[Int]] = []
            var current: [Int] = []

            func extend(_ index: Int) {
                if index == positions.count {
                    if cage.operation.calculate(current) == cage.target {
                        result.append(current)
                    }
                    return
                }
                let pos = positions[index]
                candidateLoop: for value in 1...size {
                    for j in 0..<index where current[j] == value {
                        let other = positions[j]
                        if other.row == pos.row || other.col == pos.col {
                            continue candidateLoop
                        }
                    }
                    current.append(value)
                    extend(index + 1)
                    current.removeLast()
                }
            }

            extend(0)
            return result
        }

        mutating func apply(partial: [[Int?]]?) -> Bool {
            guard let partial else { return true }
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
            // Cage contradictions in the givens surface via propagate() in search.
            return true
        }

        // MARK: Search

        func search(limit: Int, depth: Int, found: inout [[[Int]]], stats: inout Stats) {
            var node = self
            guard node.propagate(stats: &stats) else { return }
            guard let (cell, candidates) = node.branchCell() else {
                found.append(node.currentGrid())
                return
            }
            stats.guessCount += 1
            stats.maxDepth = max(stats.maxDepth, depth + 1)
            var mask = candidates
            while mask != 0 {
                let value = mask.trailingZeroBitCount
                mask &= mask - 1
                var child = node
                child.place(cell, value)
                child.search(limit: limit, depth: depth + 1, found: &found, stats: &stats)
                if found.count >= limit { return }
            }
        }

        /// The unassigned cell with the fewest candidates, or nil when the
        /// grid is complete. Uses the masks left by the last propagate() pass.
        private func branchCell() -> (Int, UInt16)? {
            var bestCell = -1
            var bestMask: UInt16 = 0
            var bestCount = Int.max
            for cell in 0..<cellCount where values[cell] == 0 {
                let count = masks[cell].nonzeroBitCount
                if count < bestCount {
                    bestCount = count
                    bestCell = cell
                    bestMask = masks[cell]
                }
            }
            return bestCell == -1 ? nil : (bestCell, bestMask)
        }

        private mutating func place(_ cell: Int, _ value: Int) {
            let bit = UInt16(1 << value)
            values[cell] = value
            rowUsed[cell / size] |= bit
            colUsed[cell % size] |= bit
        }

        /// Recomputes candidate masks (row/col legality intersected with the
        /// values live cage tuples still allow) and assigns naked and hidden
        /// singles until a fixed point. Returns false on contradiction.
        private mutating func propagate(stats: inout Stats) -> Bool {
            restart: while true {
                // Row/col legality.
                var complete = true
                for cell in 0..<cellCount where values[cell] == 0 {
                    complete = false
                    masks[cell] = fullMask & ~rowUsed[cell / size] & ~colUsed[cell % size]
                }
                if complete { return allCagesExact() }

                // Narrow by cage feasibility: a value survives only if some
                // live tuple of the covering cage uses it there.
                for cage in cageCells.indices {
                    let cells = cageCells[cage]
                    var hasUnassigned = false
                    for cell in cells where values[cell] == 0 { hasUnassigned = true; break }

                    var allowed = [UInt16](repeating: 0, count: cells.count)
                    var anyLive = false
                    tupleLoop: for tuple in cageTuples[cage] {
                        for (i, cell) in cells.enumerated() {
                            if values[cell] != 0 {
                                if values[cell] != tuple[i] { continue tupleLoop }
                            } else if masks[cell] & UInt16(1 << tuple[i]) == 0 {
                                continue tupleLoop
                            }
                        }
                        anyLive = true
                        if !hasUnassigned { break }
                        for (i, cell) in cells.enumerated() where values[cell] == 0 {
                            allowed[i] |= UInt16(1 << tuple[i])
                        }
                    }
                    if !anyLive { return false }
                    for (i, cell) in cells.enumerated() where values[cell] == 0 {
                        masks[cell] &= allowed[i]
                        if masks[cell] == 0 { return false }
                    }
                }

                // Naked singles: cells with exactly one candidate. Masks go
                // stale as singles are placed, so recheck row/col legality —
                // two same-row cells narrowed to the same value is a
                // contradiction.
                var assignedAny = false
                for cell in 0..<cellCount where values[cell] == 0 && masks[cell].nonzeroBitCount == 1 {
                    let value = masks[cell].trailingZeroBitCount
                    let bit = UInt16(1 << value)
                    if rowUsed[cell / size] & bit != 0 || colUsed[cell % size] & bit != 0 {
                        return false
                    }
                    place(cell, value)
                    stats.propagationSolvedCells += 1
                    assignedAny = true
                }
                if assignedAny { continue restart }

                // Hidden singles: a missing value with only one legal cell
                // in its row (resp. column).
                for row in 0..<size {
                    var missing = fullMask & ~rowUsed[row]
                    while missing != 0 {
                        let value = missing.trailingZeroBitCount
                        missing &= missing - 1
                        let bit = UInt16(1 << value)
                        var onlyCell = -1
                        var count = 0
                        for col in 0..<size {
                            let cell = row * size + col
                            if values[cell] == 0 && masks[cell] & bit != 0 {
                                count += 1
                                if count > 1 { break }
                                onlyCell = cell
                            }
                        }
                        if count == 0 { return false }
                        if count == 1 {
                            place(onlyCell, value)
                            stats.propagationSolvedCells += 1
                            continue restart
                        }
                    }
                }
                for col in 0..<size {
                    var missing = fullMask & ~colUsed[col]
                    while missing != 0 {
                        let value = missing.trailingZeroBitCount
                        missing &= missing - 1
                        let bit = UInt16(1 << value)
                        var onlyCell = -1
                        var count = 0
                        for row in 0..<size {
                            let cell = row * size + col
                            if values[cell] == 0 && masks[cell] & bit != 0 {
                                count += 1
                                if count > 1 { break }
                                onlyCell = cell
                            }
                        }
                        if count == 0 { return false }
                        if count == 1 {
                            place(onlyCell, value)
                            stats.propagationSolvedCells += 1
                            continue restart
                        }
                    }
                }

                return true
            }
        }

        /// One pass of row/col mask computation plus cage tuple-liveness
        /// checking, with no singles assignment. Cages partition the grid,
        /// so this single pass is already the fixed point for this strength
        /// of check — there is nothing to iterate.
        mutating func localConsistencyCheck() -> Bool {
            var complete = true
            for cell in 0..<cellCount where values[cell] == 0 {
                complete = false
                masks[cell] = fullMask & ~rowUsed[cell / size] & ~colUsed[cell % size]
                if masks[cell] == 0 { return false }
            }
            if complete { return allCagesExact() }

            for cage in cageCells.indices {
                let cells = cageCells[cage]
                var anyLive = false
                tupleLoop: for tuple in cageTuples[cage] {
                    for (i, cell) in cells.enumerated() {
                        if values[cell] != 0 {
                            if values[cell] != tuple[i] { continue tupleLoop }
                        } else if masks[cell] & UInt16(1 << tuple[i]) == 0 {
                            continue tupleLoop
                        }
                    }
                    anyLive = true
                    break
                }
                if !anyLive { return false }
            }
            return true
        }

        /// Exact check of every cage once the grid is complete.
        private func allCagesExact() -> Bool {
            for cage in cageCells.indices {
                let cells = cageCells[cage]
                var live = false
                tupleLoop: for tuple in cageTuples[cage] {
                    for (i, cell) in cells.enumerated() where values[cell] != tuple[i] {
                        continue tupleLoop
                    }
                    live = true
                    break
                }
                if !live { return false }
            }
            return true
        }

        private func currentGrid() -> [[Int]] {
            (0..<size).map { row in
                (0..<size).map { col in values[row * size + col] }
            }
        }
    }
}
