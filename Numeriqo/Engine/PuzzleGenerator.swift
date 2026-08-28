//
//  PuzzleGenerator.swift
//  Numeriqo
//
//  Latin square -> cage partition -> operators -> uniqueness -> grading.
//  See docs/ARCHITECTURE.md §4.
//
//  Invariant: every puzzle leaving `generate` is provably unique. Solvability
//  by LogicalSolver is layered on in Phase 2 — that is what makes the hint
//  guarantee real.
//

import Foundation

nonisolated enum PuzzleGenerator {

    struct Options: Sendable {
        /// Largest cage the partitioner will build. Bigger cages mean far more
        /// combinations to enumerate, so this is the main cost lever.
        var maxCageSize: Int = 4
        /// Share of *cages* that should be single-cell freebies. Too many
        /// trivialise a board; Hard puzzles should approach zero.
        ///
        /// Measured in cages, not cells, so that it is directly comparable with
        /// `maxFreebieFraction` — expressing one in cells and the other in cages
        /// silently made the quality bar reject every board the partitioner was
        /// built to produce.
        var freebieRate: Double = 0.08
        /// Reject a finished puzzle whose freebie share exceeds this. Uniqueness
        /// repair splits cells off as freebies when it must, and a board handed
        /// to the player one third pre-filled is unique but not worth solving.
        ///
        /// Generation costs single-digit milliseconds, so rejecting and
        /// re-rolling is far cheaper than accepting a weak board.
        var maxFreebieFraction: Double = 0.15
        /// Chance of taking the most constraining clue available for a cage
        /// rather than a random legal one.
        ///
        /// Defaults to zero. Tighter clues do raise the natural uniqueness
        /// rate, but the discard-and-retry loop already converges in 3-5
        /// attempts without help, and biasing toward tightness skews the board
        /// heavily to `x` cages — measured 57% multiplication at 0.5 against
        /// 40% at 0.0. Kept as a dial for difficulty tuning, not for
        /// convergence.
        var tightnessBias: Double = 0.0
        /// Attempts before giving up and returning nil.
        ///
        /// Roughly a third of freshly-clued partitions are unique with no
        /// repair at all, and an attempt costs about a millisecond, so a
        /// generous budget here is what lets `generate` reject weak boards
        /// instead of patching them.
        var maxAttempts: Int = 400
        /// Reject puzzles the curriculum cannot finish — the hint guarantee.
        /// Turned off only by tests that need to measure the raw uniqueness
        /// pipeline in isolation.
        var requireLogicallySolvable: Bool = true
        /// Optional predicate on the technique histogram, so practice drills can
        /// demand a board that exercises a specific technique, filtering inside
        /// this one search rather than generating and discarding outside it.
        ///
        /// Must draw no randomness: a default-accept caller has to see the
        /// identical seeded stream, or reproducibility breaks.
        var accepts: (@Sendable ([Technique: Int]) -> Bool)?

        static let `default` = Options()

        static func forSize(_ size: Int) -> Options {
            var o = Options()
            // Large grids need smaller cages to keep enumeration affordable.
            o.maxCageSize = size >= 8 ? 3 : 4
            // Small grids have few cages, so one freebie is a large share.
            o.maxFreebieFraction = size <= 4 ? 0.25 : 0.15
            return o
        }
    }

    /// Whether a finished puzzle is worth showing a player.
    static func meetsQualityBar(_ puzzle: Puzzle, options: Options) -> Bool {
        let cages = puzzle.cages
        guard !cages.isEmpty else { return false }
        let freebies = Double(cages.filter(\.isFreebie).count) / Double(cages.count)
        return freebies <= options.maxFreebieFraction
    }

    // MARK: - Latin square

    /// Randomised backtracking fill.
    ///
    /// Deliberately NOT the legacy cyclic construction `((i+j) % size) + 1`
    /// followed by row/column shuffles: that reaches only the cyclic isotopy
    /// class, so every row is a rearranged shift of every other and the puzzle
    /// space is far smaller than it looks. See docs/ARCHITECTURE.md §4.
    static func latinSquare(size: Int, using rng: inout SeededRandomNumberGenerator) -> [[Int]]? {
        var grid = [[Int]](repeating: [Int](repeating: 0, count: size), count: size)
        var rowMask = [UInt16](repeating: 0, count: size)
        var colMask = [UInt16](repeating: 0, count: size)

        func fill(_ index: Int) -> Bool {
            if index == size * size { return true }
            let r = index / size, c = index % size

            var digits = Array(1...size)
            digits.shuffle(using: &rng)

            for d in digits {
                let bit = UInt16(1 << (d - 1))
                guard rowMask[r] & bit == 0, colMask[c] & bit == 0 else { continue }
                grid[r][c] = d
                rowMask[r] |= bit
                colMask[c] |= bit
                if fill(index + 1) { return true }
                rowMask[r] &= ~bit
                colMask[c] &= ~bit
                grid[r][c] = 0
            }
            return false
        }

        return fill(0) ? grid : nil
    }

    // MARK: - Cage partition

    /// Random flood-fill partition.
    ///
    /// Seeds are taken in reading order, not at random. Random seeding
    /// fragments the free space and strands isolated cells, which then become
    /// unwanted freebies — measured at 21-24% against a requested 6%. Sweeping
    /// keeps the unassigned region contiguous.
    ///
    /// Any singletons that still occur are merged into a neighbour, and the
    /// freebies the puzzle actually wants are then split back out deliberately,
    /// so their count is controlled rather than emergent.
    static func partition(
        size: Int,
        options: Options,
        using rng: inout SeededRandomNumberGenerator
    ) -> [[Cell]] {
        let cellCount = size * size
        var owner = [Int](repeating: -1, count: cellCount)
        var cages: [[Cell]] = []

        func flat(_ cell: Cell) -> Int { cell.row * size + cell.col }
        func inBounds(_ cell: Cell) -> Bool {
            cell.row >= 0 && cell.row < size && cell.col >= 0 && cell.col < size
        }
        func neighbours(_ cell: Cell) -> [Cell] {
            [Cell(cell.row - 1, cell.col), Cell(cell.row + 1, cell.col),
             Cell(cell.row, cell.col - 1), Cell(cell.row, cell.col + 1)].filter(inBounds)
        }

        // 1. Grow cages from the first free cell in reading order.
        for index in 0..<cellCount where owner[index] == -1 {
            let seed = Cell(index / size, index % size)
            let ci = cages.count
            owner[index] = ci
            var cage = [seed]

            let targetSize = Int.random(in: 2...options.maxCageSize, using: &rng)
            while cage.count < targetSize {
                var frontier: [Cell] = []
                for cell in cage {
                    for n in neighbours(cell) where owner[flat(n)] == -1 { frontier.append(n) }
                }
                guard let next = frontier.sorted().randomElement(using: &rng) else { break }
                owner[flat(next)] = ci
                cage.append(next)
            }
            cages.append(cage.sorted())
        }

        // 2. Absorb stranded singletons into an adjacent cage with room.
        var changed = true
        while changed {
            changed = false
            for ci in cages.indices where cages[ci].count == 1 {
                let cell = cages[ci][0]
                let hosts = neighbours(cell)
                    .map { owner[flat($0)] }
                    .filter { $0 != ci && !cages[$0].isEmpty && cages[$0].count < options.maxCageSize }
                guard let host = hosts.sorted().randomElement(using: &rng) else { continue }
                cages[host].append(cell)
                cages[host].sort()
                cages[ci] = []
                owner[flat(cell)] = host
                changed = true
            }
            cages.removeAll(where: \.isEmpty)
            // owner indices shift after compaction; rebuild.
            for (ci, cage) in cages.enumerated() {
                for cell in cage { owner[flat(cell)] = ci }
            }
        }

        // 3. Split out the freebies the puzzle actually wants, taking only cells
        //    whose removal leaves the parent cage connected.
        let wanted = Int((Double(cages.count) * options.freebieRate).rounded())
        var made = 0
        var order = Array(cages.indices)
        order.shuffle(using: &rng)

        for ci in order where made < wanted {
            guard cages[ci].count >= 3 else { continue }
            for candidate in cages[ci].shuffled(using: &rng) {
                let rest = cages[ci].filter { $0 != candidate }
                let probe = Cage(cells: rest, operation: .add, target: 1)
                guard probe.isOrthogonallyConnected else { continue }
                cages[ci] = rest
                cages.append([candidate])
                made += 1
                break
            }
        }

        return cages
    }

    // MARK: - Operators

    /// Pick an operation and target for a cage, given the solution beneath it.
    static func clue(
        for cells: [Cell],
        solution: [[Int]],
        size: Int,
        using rng: inout SeededRandomNumberGenerator
    ) -> (Operation, Int) {
        let digits = cells.map { solution[$0.row][$0.col] }

        if digits.count == 1 {
            return (.none, digits[0])
        }

        var options: [(Operation, Int)] = []

        let sum = digits.reduce(0, +)
        options.append((.add, sum))

        let product = digits.reduce(1, *)
        options.append((.multiply, product))

        // Subtraction and division are two-cell only — see docs/RULES.md §3.4.
        if digits.count == 2 {
            let hi = max(digits[0], digits[1]), lo = min(digits[0], digits[1])
            let difference = hi - lo
            if difference > 0 {
                // Weight the forced pairs: a 5- in a 6x6 is the single most
                // useful clue a beginner can be given.
                options.append((.subtract, difference))
                if difference >= size - 2 { options.append((.subtract, difference)) }
            }
            if lo > 0, hi % lo == 0, hi / lo > 1 {
                let quotient = hi / lo
                options.append((.divide, quotient))
                if quotient >= size - 2 { options.append((.divide, quotient)) }
            }
        }

        return options.randomElement(using: &rng) ?? (.add, sum)
    }

    /// Every clue legal for these cells given the solution, ordered from most
    /// constraining to least — fewest legal assignments first.
    ///
    /// Repair uses this to tighten an ambiguous cage before falling back to
    /// splitting it, which is what keeps freebie counts down.
    static func cluesByTightness(
        for cells: [Cell],
        solution: [[Int]],
        size: Int
    ) -> [(Operation, Int)] {
        let digits = cells.map { solution[$0.row][$0.col] }
        guard digits.count > 1 else { return [(.none, digits[0])] }

        var candidates: [(Operation, Int)] = [
            (.add, digits.reduce(0, +)),
            (.multiply, digits.reduce(1, *)),
        ]
        if digits.count == 2 {
            let hi = max(digits[0], digits[1]), lo = min(digits[0], digits[1])
            if hi - lo > 0 { candidates.append((.subtract, hi - lo)) }
            if lo > 0, hi % lo == 0, hi / lo > 1 { candidates.append((.divide, hi / lo)) }
        }

        return candidates
            .map { clue -> (Operation, Int, Int) in
                let count = CageCombinations.assignments(
                    gridSize: size, operation: clue.0, target: clue.1, cells: cells
                ).count
                return (clue.0, clue.1, count)
            }
            .filter { $0.2 > 0 }
            .sorted { $0.2 < $1.2 }
            .map { ($0.0, $0.1) }
    }

    // MARK: - Generation

    struct Result: Sendable {
        let puzzle: Puzzle
        let attempts: Int
        /// How the curriculum cracks it. Empty when solvability gating is off.
        let grade: DifficultyRater.Grade?

        var techniqueProfile: [Technique: Int] { grade?.profile ?? [:] }
    }

    /// Generates a puzzle that actually lands in the requested band.
    ///
    /// Without this the difficulty picker was decoration: `generate` was called
    /// with no acceptance predicate, its grade was discarded, and the requested
    /// label was stapled onto whatever board came out — so a "Severe 5x5" was
    /// statistically identical to a "Gentle 5x5", and best times were filed
    /// under a tier that meant nothing.
    ///
    /// Falls back to the nearest band rather than failing: refusing to start a
    /// game because one tier is scarce would be worse than a board one step off.
    ///
    /// The budget is sized so the fallback is a genuine edge case. At six
    /// attempts about 28% of Steady dailies graded off-band; the expected
    /// number of attempts to hit the band is ~5, so the typical cost is
    /// unchanged and only the unlucky tail keeps rolling.
    static let bandAttempts = 48

    static func generate(
        matching difficulty: Difficulty,
        size: Int,
        seed: UInt64
    ) -> Result? {
        var nearest: (result: Result, distance: Int)?

        for attempt in 0..<bandAttempts {
            guard let candidate = generate(
                size: size, seed: seed &+ UInt64(attempt) &* 7_919
            ) else { continue }
            guard let band = candidate.grade?.difficulty else { continue }
            if band == difficulty { return candidate }

            let distance = abs(band.order - difficulty.order)
            if nearest == nil || distance < nearest!.distance {
                nearest = (candidate, distance)
            }
        }
        return nearest?.result
    }

    /// Generate a puzzle with exactly one solution, or nil if the attempt
    /// budget is exhausted.
    ///
    /// With `requireLogicallySolvable` set (the default), a puzzle the
    /// curriculum cannot finish is rejected. **This is the hint guarantee**: it
    /// is what makes "the app can always name a next technique" true rather
    /// than aspirational, and it is why the player is never shown a hint they
    /// could not have reasoned to.
    static func generate(
        size: Int,
        options: Options? = nil,
        seed: UInt64
    ) -> Result? {
        let opts = options ?? .forSize(size)
        var rng = SeededRandomNumberGenerator(seed: seed)

        /// Final gate, applied identically on both passes.
        func accept(_ puzzle: Puzzle, attempt: Int, enforceQuality: Bool) -> Result? {
            guard puzzle.isWellFormed() else { return nil }
            if enforceQuality {
                guard meetsQualityBar(puzzle, options: opts) else { return nil }
            }
            guard opts.requireLogicallySolvable else {
                return Result(puzzle: puzzle, attempts: attempt, grade: nil)
            }

            let result = LogicalSolver.solve(puzzle)
            guard result.solved else { return nil }

            let grade = DifficultyRater.grade(result, size: size)
            if let accepts = opts.accepts, !accepts(grade.profile) { return nil }
            return Result(puzzle: puzzle, attempts: attempt, grade: grade)
        }

        // Pass A: discard-and-retry. About a third of freshly-clued partitions
        // are unique on their own, and an attempt is ~1ms, so re-rolling is
        // both cheaper and far kinder to puzzle quality than repairing —
        // repair buys uniqueness by splitting cells into freebies, and a board
        // handed to the player pre-filled is unique but not worth solving.
        let straightBudget = max(1, opts.maxAttempts * 3 / 4)
        for attempt in 1...straightBudget {
            guard let solution = latinSquare(size: size, using: &rng) else { continue }
            let groups = partition(size: size, options: opts, using: &rng)
            let cages = clueAll(groups, solution: solution, size: size, options: opts, using: &rng)

            guard cages.allSatisfy({ $0.isWellFormed(gridSize: size) }) else { continue }
            guard BacktrackingSolver.countSolutions(size: size, cages: cages, limit: 2) == 1
            else { continue }

            let puzzle = Puzzle(size: size, cages: cages, solution: solution)
            if let result = accept(puzzle, attempt: attempt, enforceQuality: true) {
                return result
            }
        }

        // Pass B: fall back to repair, accepting the quality cost rather than
        // returning nothing. Reached only when the grid is so constrained that
        // re-rolling keeps failing.
        for attempt in (straightBudget + 1)...opts.maxAttempts {
            guard let solution = latinSquare(size: size, using: &rng) else { continue }
            let groups = partition(size: size, options: opts, using: &rng)
            var working = clueAll(groups, solution: solution, size: size, options: opts, using: &rng)
            guard working.allSatisfy({ $0.isWellFormed(gridSize: size) }) else { continue }

            for pass in 0..<4 {
                let n = BacktrackingSolver.countSolutions(size: size, cages: working, limit: 2)
                if n == 1 {
                    let puzzle = Puzzle(size: size, cages: working, solution: solution)
                    if let result = accept(puzzle, attempt: attempt, enforceQuality: false) {
                        return result
                    }
                    break
                }
                if n == 0 { break }
                guard let repaired = repair(
                    size: size,
                    cages: working,
                    solution: solution,
                    allowSplitting: pass >= 1,
                    using: &rng
                ) else { break }
                working = repaired
            }
        }
        return nil
    }

    /// Clue every cage, favouring tighter clues with probability
    /// `options.tightnessBias`.
    private static func clueAll(
        _ groups: [[Cell]],
        solution: [[Int]],
        size: Int,
        options: Options,
        using rng: inout SeededRandomNumberGenerator
    ) -> [Cage] {
        var cages: [Cage] = []
        cages.reserveCapacity(groups.count)
        for cells in groups {
            let picked: (Operation, Int)
            if Double.random(in: 0..<1, using: &rng) < options.tightnessBias,
               let tightest = cluesByTightness(for: cells, solution: solution, size: size).first {
                picked = tightest
            } else {
                picked = clue(for: cells, solution: solution, size: size, using: &rng)
            }
            cages.append(Cage(cells: cells, operation: picked.0, target: picked.1))
        }
        return cages
    }

    /// Constrain the cages covering cells where two solutions disagree.
    ///
    /// With `allowSplitting` false this only re-clues — cheap, and it costs the
    /// puzzle nothing. With it true, one divergent cell per cage is split off as
    /// a freebie, which always works but hands the player a cell.
    private static func repair(
        size: Int,
        cages: [Cage],
        solution: [[Int]],
        allowSplitting: Bool,
        using rng: inout SeededRandomNumberGenerator
    ) -> [Cage]? {
        guard let (a, b) = BacktrackingSolver.twoSolutions(size: size, cages: cages) else {
            return nil
        }

        var divergent = Set<Cell>()
        for flat in a.indices where a[flat] != b[flat] {
            divergent.insert(Cell(flat / size, flat % size))
        }
        guard !divergent.isEmpty else { return nil }

        var out: [Cage] = []
        out.reserveCapacity(cages.count)
        var didSomething = false

        for cage in cages {
            guard cage.cells.contains(where: { divergent.contains($0) }), cage.cells.count > 1
            else {
                out.append(cage)
                continue
            }

            // Pass 1: re-clue as tightly as the solution permits.
            if let tightest = cluesByTightness(
                for: cage.cells, solution: solution, size: size
            ).first,
               tightest.0 != cage.operation || tightest.1 != cage.target {
                out.append(Cage(cells: cage.cells, operation: tightest.0, target: tightest.1))
                didSomething = true
                continue
            }

            guard allowSplitting else {
                out.append(cage)
                continue
            }

            // Pass 2: split off a divergent cell, keeping the remainder connected.
            let pivots = cage.cells.filter { divergent.contains($0) }
            var split = false
            for pivot in pivots {
                let rest = cage.cells.filter { $0 != pivot }
                let probe = Cage(cells: rest, operation: .add, target: 1)
                guard rest.count == 1 || probe.isOrthogonallyConnected else { continue }

                out.append(Cage(
                    cells: [pivot], operation: .none, target: solution[pivot.row][pivot.col]
                ))
                if rest.count == 1 {
                    out.append(Cage(
                        cells: rest, operation: .none,
                        target: solution[rest[0].row][rest[0].col]
                    ))
                } else {
                    let (op, target) = cluesByTightness(
                        for: rest, solution: solution, size: size
                    ).first ?? clue(for: rest, solution: solution, size: size, using: &rng)
                    out.append(Cage(cells: rest, operation: op, target: target))
                }
                split = true
                didSomething = true
                break
            }
            if !split { out.append(cage) }
        }

        return didSomething ? out : nil
    }
}
