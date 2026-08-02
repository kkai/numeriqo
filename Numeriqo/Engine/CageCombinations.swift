//
//  CageCombinations.swift
//  Numeriqo
//
//  The correctness lynchpin of the whole engine. See docs/ARCHITECTURE.md §3.
//
//  Calcudoku permits a digit to repeat inside a cage, provided the repeated
//  cells share neither a row nor a column. So enumeration cannot work on sets
//  the way Killer Sudoku or Kakuro does — it must produce *multisets*, then
//  filter by the cage's actual geometry.
//
//      6x6, three-cell 20x cage:
//        straight line -> {1,4,5} only
//        L-shaped      -> {1,4,5} and {2,2,5}, the 2s in elbow positions
//
//  Getting this wrong silently corrupts difficulty grading, hints, and
//  generation all at once, so it is tested differentially against brute force
//  for every (N <= 6, operation, target, shape).
//

import Foundation

nonisolated enum CageCombinations {

    // MARK: - Shape

    /// The only geometric fact enumeration needs: which cells may not share a
    /// digit. Two cages with the same conflict graph have the same solution
    /// set, whatever their absolute position, which is what makes caching work.
    struct Shape: Hashable, Sendable {
        let count: Int
        /// `conflicts[i]` is a bitmask over `j < i` of cells conflicting with `i`.
        let conflicts: [Int]

        init(cells: [Cell]) {
            count = cells.count
            var masks = [Int](repeating: 0, count: cells.count)
            for i in 0..<cells.count {
                for j in 0..<i where cells[i].conflicts(with: cells[j]) {
                    masks[i] |= (1 << j)
                }
            }
            conflicts = masks
        }
    }

    private struct Key: Hashable, Sendable {
        let gridSize: Int
        let operation: Operation
        let target: Int
        let shape: Shape
    }

    // MARK: - Cache

    private static let cache = Cache()

    private final class Cache: @unchecked Sendable {
        private var storage: [Key: [[Int]]] = [:]
        private let lock = NSLock()

        func value(for key: Key, build: () -> [[Int]]) -> [[Int]] {
            lock.lock()
            if let hit = storage[key] {
                lock.unlock()
                return hit
            }
            lock.unlock()

            let built = build()

            lock.lock()
            storage[key] = built
            lock.unlock()
            return built
        }

        func removeAll() {
            lock.lock()
            storage.removeAll()
            lock.unlock()
        }
    }

    /// Tests only.
    static func clearCache() { cache.removeAll() }

    // MARK: - Entry points

    /// Every legal assignment of digits to the cage's cells, in `cage.cells`
    /// order. Cached.
    static func assignments(for cage: Cage, gridSize: Int) -> [[Int]] {
        assignments(
            gridSize: gridSize,
            operation: cage.operation,
            target: cage.target,
            cells: cage.cells
        )
    }

    static func assignments(
        gridSize: Int,
        operation: Operation,
        target: Int,
        cells: [Cell]
    ) -> [[Int]] {
        guard gridSize > 0, !cells.isEmpty else { return [] }
        let key = Key(
            gridSize: gridSize,
            operation: operation,
            target: target,
            shape: Shape(cells: cells)
        )
        return cache.value(for: key) {
            enumerate(gridSize: gridSize, operation: operation, target: target, shape: key.shape)
        }
    }

    /// The distinct digit multisets a cage can hold, sorted — what the teaching
    /// UI shows when the player taps a clue. Derived from `assignments`, so it
    /// automatically respects geometry.
    static func multisets(for cage: Cage, gridSize: Int) -> [[Int]] {
        var seen = Set<[Int]>()
        var out: [[Int]] = []
        for assignment in assignments(for: cage, gridSize: gridSize) {
            let sorted = assignment.sorted()
            if seen.insert(sorted).inserted { out.append(sorted) }
        }
        return out.sorted { $0.lexicographicallyPrecedes($1) }
    }

    /// Union of digits that can appear in each cell of the cage, as a candidate
    /// bitmask per cell (bit `d-1` set means digit `d` is possible).
    ///
    /// This is what technique T6 (cage digit exclusion) consumes.
    static func candidateMasks(for cage: Cage, gridSize: Int) -> [UInt16] {
        var masks = [UInt16](repeating: 0, count: cage.cells.count)
        for assignment in assignments(for: cage, gridSize: gridSize) {
            for (i, digit) in assignment.enumerated() {
                masks[i] |= UInt16(1 << (digit - 1))
            }
        }
        return masks
    }

    // MARK: - Enumeration

    private static func enumerate(
        gridSize: Int,
        operation: Operation,
        target: Int,
        shape: Shape
    ) -> [[Int]] {
        let k = shape.count

        // Structural rejects. A malformed cage has no assignments at all.
        //
        // Written as separate guards rather than a multi-pattern switch: in
        // `case .subtract, .divide where k != 2`, the `where` binds only to
        // `.divide`, so `.subtract` would match unconditionally. That reads
        // correct and is not.
        switch operation {
        case .none:
            guard k == 1, (1...gridSize).contains(target) else { return [] }
        case .subtract, .divide:
            guard k == 2 else { return [] }
        case .add, .multiply:
            guard k >= 1 else { return [] }
        }

        var results: [[Int]] = []
        var current = [Int](repeating: 0, count: k)

        // Precomputed bounds for the additive/multiplicative prunes.
        // maxProduct[r] = gridSize^r, saturating, so deep cages don't overflow.
        var maxProduct = [Int](repeating: 1, count: k + 1)
        for r in 1...max(k, 1) {
            let (v, overflow) = maxProduct[r - 1].multipliedReportingOverflow(by: gridSize)
            maxProduct[r] = overflow ? Int.max : v
        }

        func place(_ i: Int, sum: Int, product: Int) {
            if i == k {
                if operation.satisfies(current, target: target) {
                    results.append(current)
                }
                return
            }

            let conflictMask = shape.conflicts[i]
            let remaining = k - i - 1

            digitLoop: for digit in 1...gridSize {
                // Latin constraint against already-placed conflicting cells.
                var mask = conflictMask
                while mask != 0 {
                    let j = mask.trailingZeroBitCount
                    if current[j] == digit { continue digitLoop }
                    mask &= mask - 1
                }

                let newSum = sum + digit
                let newProduct = product.multipliedReportingOverflow(by: digit).overflow
                    ? Int.max
                    : product * digit

                // Arithmetic feasibility of the partial assignment.
                switch operation {
                case .add:
                    // The remaining cells contribute at least `remaining` and
                    // at most `remaining * gridSize`.
                    if newSum + remaining > target { continue }
                    if newSum + remaining * gridSize < target { continue }
                case .multiply:
                    if newProduct > target { continue }
                    // Every remaining factor is a whole number, so the partial
                    // product must divide the target.
                    if newProduct > 0 && target % newProduct != 0 { continue }
                    if maxProduct[remaining] != Int.max,
                       newProduct * maxProduct[remaining] < target { continue }
                case .none, .subtract, .divide:
                    break  // cheap to check exactly at the leaf
                }

                current[i] = digit
                place(i + 1, sum: newSum, product: newProduct)
            }
        }

        place(0, sum: 0, product: 1)
        return results
    }

    // MARK: - Reference implementation

    /// Deliberately naive: enumerate every digit tuple and filter. Exponential,
    /// and only ever used to prove `assignments` correct in tests.
    static func bruteForceAssignments(
        gridSize: Int,
        operation: Operation,
        target: Int,
        cells: [Cell]
    ) -> [[Int]] {
        let k = cells.count
        guard k > 0, gridSize > 0 else { return [] }

        var results: [[Int]] = []
        var current = [Int](repeating: 0, count: k)

        func recurse(_ i: Int) {
            if i == k {
                // Latin check across the whole tuple.
                for a in 0..<k {
                    for b in (a + 1)..<k
                    where current[a] == current[b] && cells[a].conflicts(with: cells[b]) {
                        return
                    }
                }
                if operation.satisfies(current, target: target) {
                    results.append(current)
                }
                return
            }
            for digit in 1...gridSize {
                current[i] = digit
                recurse(i + 1)
            }
        }

        recurse(0)
        return results
    }
}
