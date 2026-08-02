//
//  BacktrackingSolver.swift
//  Numeriqo
//
//  Uniqueness proof ONLY. This solver is never a hint source — it may guess,
//  and a guess is exactly what the teaching product refuses to show a player.
//  Human-readable deduction lives in LogicalSolver. See docs/ARCHITECTURE.md §3.
//

import Foundation

nonisolated enum BacktrackingSolver {

    /// Number of solutions, stopping as soon as `limit` is reached.
    /// A well-formed puzzle returns exactly 1.
    static func countSolutions(size: Int, cages: [Cage], limit: Int = 2) -> Int {
        guard var engine = Engine(size: size, cages: cages) else { return 0 }
        var found = 0
        var budget = Budget(nodes: nodeBudget(for: size))
        engine.search(limit: limit, found: &found, budget: &budget, collect: nil)
        return found
    }

    /// The first solution found, or nil if there is none.
    static func solve(size: Int, cages: [Cage]) -> [[Int]]? {
        guard var engine = Engine(size: size, cages: cages) else { return nil }
        var found = 0
        var solution: [Int]?
        var budget = Budget(nodes: nodeBudget(for: size))
        engine.search(limit: 1, found: &found, budget: &budget, collect: { solution = $0 })
        guard let flat = solution else { return nil }
        return (0..<size).map { r in Array(flat[(r * size)..<((r + 1) * size)]) }
    }

    /// Two distinct solutions, when they exist — used by the generator's
    /// uniqueness repair to find the cell where they disagree.
    static func twoSolutions(size: Int, cages: [Cage]) -> ([Int], [Int])? {
        guard var engine = Engine(size: size, cages: cages) else { return nil }
        var found = 0
        var collected: [[Int]] = []
        var budget = Budget(nodes: nodeBudget(for: size))
        engine.search(limit: 2, found: &found, budget: &budget, collect: { collected.append($0) })
        guard collected.count == 2 else { return nil }
        return (collected[0], collected[1])
    }

    /// Deterministic node ceiling. Bounded by node count rather than wall clock
    /// so that a given seed always produces the same result — a time-based
    /// deadline would make generation tests flaky. See docs/ARCHITECTURE.md §4.
    static func nodeBudget(for size: Int) -> Int {
        switch size {
        case ...4: 200_000
        case 5: 400_000
        case 6: 800_000
        case 7: 2_000_000
        case 8: 4_000_000
        default: 8_000_000
        }
    }

    struct Budget {
        var nodes: Int
        var exhausted = false

        mutating func consume() -> Bool {
            if nodes <= 0 { exhausted = true; return false }
            nodes -= 1
            return true
        }
    }

    // MARK: - Engine

    private struct Engine {
        let size: Int
        let cages: [Cage]
        /// Per cage, every legal assignment, as flat cell indices → digit.
        let cageAssignments: [[[Int]]]
        /// Per cage, the flat cell index of each of its cells.
        let cageCellIndices: [[Int]]
        /// Flat cell index → cage index.
        let cageOfCell: [Int]

        var candidates: [UInt16]
        var values: [Int]  // 0 means empty

        init?(size: Int, cages: [Cage]) {
            guard size > 0 else { return nil }
            let cellCount = size * size

            var ofCell = [Int](repeating: -1, count: cellCount)
            var indices: [[Int]] = []
            indices.reserveCapacity(cages.count)

            for (ci, cage) in cages.enumerated() {
                var idx: [Int] = []
                idx.reserveCapacity(cage.cells.count)
                for cell in cage.cells {
                    guard cell.row >= 0, cell.row < size, cell.col >= 0, cell.col < size
                    else { return nil }
                    let flat = cell.row * size + cell.col
                    guard ofCell[flat] == -1 else { return nil }  // overlapping cages
                    ofCell[flat] = ci
                    idx.append(flat)
                }
                indices.append(idx)
            }
            guard !ofCell.contains(-1) else { return nil }  // incomplete partition

            var assignments: [[[Int]]] = []
            assignments.reserveCapacity(cages.count)
            for cage in cages {
                let list = CageCombinations.assignments(for: cage, gridSize: size)
                if list.isEmpty { return nil }  // unsatisfiable cage
                assignments.append(list)
            }

            self.size = size
            self.cages = cages
            self.cageAssignments = assignments
            self.cageCellIndices = indices
            self.cageOfCell = ofCell
            self.candidates = [UInt16](repeating: UInt16((1 << size) - 1), count: cellCount)
            self.values = [Int](repeating: 0, count: cellCount)
        }

        // MARK: Propagation

        /// Narrow candidates to a fixpoint. Returns false on contradiction.
        mutating func propagate() -> Bool {
            var changed = true
            while changed {
                changed = false

                // 1. Cage feasibility: a digit survives in a cell only if some
                //    still-viable assignment of its cage places it there.
                for ci in cages.indices {
                    let cells = cageCellIndices[ci]
                    var unions = [UInt16](repeating: 0, count: cells.count)
                    var anyViable = false

                    for assignment in cageAssignments[ci] {
                        var viable = true
                        for (k, digit) in assignment.enumerated() {
                            if candidates[cells[k]] & UInt16(1 << (digit - 1)) == 0 {
                                viable = false
                                break
                            }
                        }
                        guard viable else { continue }
                        anyViable = true
                        for (k, digit) in assignment.enumerated() {
                            unions[k] |= UInt16(1 << (digit - 1))
                        }
                    }
                    guard anyViable else { return false }

                    for (k, flat) in cells.enumerated() where candidates[flat] != unions[k] {
                        let narrowed = candidates[flat] & unions[k]
                        if narrowed == 0 { return false }
                        if narrowed != candidates[flat] {
                            candidates[flat] = narrowed
                            changed = true
                        }
                    }
                }

                // 2. Naked singles, and elimination from row/column peers.
                for flat in candidates.indices {
                    let mask = candidates[flat]
                    if mask == 0 { return false }
                    guard mask.nonzeroBitCount == 1 else { continue }
                    let digit = mask.trailingZeroBitCount + 1
                    if values[flat] == digit { continue }
                    values[flat] = digit
                    changed = true

                    let row = flat / size, col = flat % size
                    let clear = ~mask
                    for c in 0..<size where c != col {
                        let peer = row * size + c
                        let next = candidates[peer] & clear
                        if next == 0 { return false }
                        candidates[peer] = next
                    }
                    for r in 0..<size where r != row {
                        let peer = r * size + col
                        let next = candidates[peer] & clear
                        if next == 0 { return false }
                        candidates[peer] = next
                    }
                }

                // 3. Hidden singles in rows and columns.
                for line in 0..<size {
                    for digit in 1...size {
                        let bit = UInt16(1 << (digit - 1))

                        var seen = 0, place = -1
                        for c in 0..<size where candidates[line * size + c] & bit != 0 {
                            seen += 1; place = line * size + c
                        }
                        if seen == 0 { return false }
                        if seen == 1, candidates[place] != bit {
                            candidates[place] = bit
                            changed = true
                        }

                        seen = 0; place = -1
                        for r in 0..<size where candidates[r * size + line] & bit != 0 {
                            seen += 1; place = r * size + line
                        }
                        if seen == 0 { return false }
                        if seen == 1, candidates[place] != bit {
                            candidates[place] = bit
                            changed = true
                        }
                    }
                }
            }
            return true
        }

        // MARK: Search

        mutating func search(
            limit: Int,
            found: inout Int,
            budget: inout Budget,
            collect: (([Int]) -> Void)?
        ) {
            guard budget.consume() else { return }
            guard propagate() else { return }

            // Most-constrained cell first.
            var target = -1
            var best = Int.max
            for flat in candidates.indices {
                let n = candidates[flat].nonzeroBitCount
                if n > 1 && n < best { best = n; target = flat }
            }

            if target == -1 {
                // Fully determined — verify every cage exactly.
                var grid = [Int](repeating: 0, count: size * size)
                for flat in candidates.indices {
                    grid[flat] = candidates[flat].trailingZeroBitCount + 1
                }
                guard isComplete(grid) else { return }
                found += 1
                collect?(grid)
                return
            }

            let mask = candidates[target]
            for digit in 1...size where mask & UInt16(1 << (digit - 1)) != 0 {
                var branch = self
                branch.candidates[target] = UInt16(1 << (digit - 1))
                branch.search(limit: limit, found: &found, budget: &budget, collect: collect)
                if found >= limit || budget.exhausted { return }
            }
        }

        private func isComplete(_ grid: [Int]) -> Bool {
            for line in 0..<size {
                var rowSeen = Set<Int>(), colSeen = Set<Int>()
                for i in 0..<size {
                    rowSeen.insert(grid[line * size + i])
                    colSeen.insert(grid[i * size + line])
                }
                if rowSeen.count != size || colSeen.count != size { return false }
            }
            for (ci, cage) in cages.enumerated() {
                let digits = cageCellIndices[ci].map { grid[$0] }
                if !cage.operation.satisfies(digits, target: cage.target) { return false }
            }
            return true
        }
    }
}
