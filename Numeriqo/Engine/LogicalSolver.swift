//
//  LogicalSolver.swift
//  Numeriqo
//
//  The human-technique solver, and the thing the whole product rests on.
//
//  It solves the way a person does: applying the cheapest applicable technique
//  in curriculum order and naming each deduction. The SAME `nextStep` code path
//  grades difficulty during generation and powers the in-game hint engine
//  against the player's actual entries and notes.
//
//  It never guesses. A puzzle it cannot finish is rejected at generation, which
//  is what makes the hint guarantee real — see docs/ARCHITECTURE.md §4.
//

import Foundation

nonisolated struct LogicalSolver: Sendable {

    // MARK: - Result

    struct SolveResult: Sendable {
        let solved: Bool
        let trace: [TechniqueApplication]

        var histogram: [Technique: Int] {
            trace.reduce(into: [:]) { $0[$1.technique, default: 0] += 1 }
        }

        /// The hardest technique the puzzle actually required. Labels what a
        /// puzzle *teaches*, which is what the Academy and practice drills
        /// target — distinct from the weighted difficulty score.
        var hardestTechnique: Technique? {
            trace.map(\.technique).max()
        }
    }

    // MARK: - State

    /// Candidate state for a solve: entries plus per-cell candidate bitmasks.
    struct State: Sendable {
        let size: Int
        var entries: [Cell: Int]
        var candidates: [Cell: UInt16]

        init(puzzle: Puzzle, board: BoardState? = nil) {
            size = puzzle.size
            entries = board?.entries ?? [:]
            candidates = [:]

            let everything = DigitSet.all(size: puzzle.size)
            for cell in puzzle.allCells where entries[cell] == nil {
                candidates[cell] = everything
            }

            // Seed candidates from the player's notes where present. Notes are
            // the player's visible knowledge, so hints never re-teach them.
            //
            // A cell with NO notes means "no knowledge" and keeps the full set
            // — emptying it instead would make the solver think the board was
            // contradictory the moment the player stopped taking notes.
            if let board {
                for (cell, notes) in board.notes
                where entries[cell] == nil && !notes.isEmpty {
                    candidates[cell] = DigitSet.fromDigits(notes)
                }
            }
        }

        func candidates(at cell: Cell) -> UInt16 { candidates[cell] ?? 0 }

        /// Cells in reading order. Detectors must iterate deterministically —
        /// `candidates` is a Dictionary, so never iterate it unsorted.
        var openCells: [Cell] { candidates.keys.sorted() }

        func openCells(in line: Line) -> [Cell] {
            line.cells(size: size).filter { candidates[$0] != nil }
        }

        /// Digits already placed in a line.
        func usedDigits(in line: Line) -> UInt16 {
            line.cells(size: size).reduce(UInt16(0)) { mask, cell in
                if let d = entries[cell] { return mask | DigitSet.mask(d) }
                return mask
            }
        }
    }

    // MARK: - Full solve (generation / grading)

    static func solve(_ puzzle: Puzzle) -> SolveResult {
        var state = State(puzzle: puzzle)
        var trace: [TechniqueApplication] = []

        // Ceiling proportional to the work available: every step must either
        // place a digit or remove a candidate, so this cannot be hit by a
        // correct solver. It bounds a buggy one instead of hanging.
        let ceiling = puzzle.size * puzzle.size * puzzle.size * 4

        while trace.count < ceiling,
              let step = nextStep(puzzle: puzzle, state: &state, apply: true) {
            trace.append(step)
            if state.candidates.isEmpty { break }
        }

        let solved = puzzle.allCells.allSatisfy { state.entries[$0] != nil }
        return SolveResult(solved: solved, trace: trace)
    }

    // MARK: - Next step (hints)

    /// The next applicable technique for the player's board, without mutating it.
    static func nextStep(puzzle: Puzzle, board: BoardState) -> TechniqueApplication? {
        var state = State(puzzle: puzzle, board: board)
        return nextStep(puzzle: puzzle, state: &state, apply: false)
    }

    typealias Detector = @Sendable (Puzzle, inout State) -> TechniqueApplication?

    /// Dispatch table keyed off `Technique.allCases`, so the solver order and
    /// the curriculum cannot drift apart. A hand-maintained parallel array is
    /// the obvious alternative and has no way to notice when it goes stale.
    static func detector(for technique: Technique) -> Detector {
        switch technique {
        case .freebieCage: detectFreebieCage
        case .divisibility: detectDivisibility
        case .minMaxBounds: detectMinMaxBounds
        case .pairSets: detectPairSets
        case .cageCombination: detectCageCombination
        case .nakedSingle: detectNakedSingle
        case .hiddenSingle: detectHiddenSingle
        case .lastCellInLine: detectLastCellInLine
        case .nakedSubset: detectNakedSubset
        case .hiddenSubset: detectHiddenSubset
        case .pointingCage: detectPointingCage
        case .claimingLine: detectClaimingLine
        case .ruleOfN: detectRuleOfN
        case .outie: detectOutie
        case .parity: detectParity
        case .xWing: detectXWing
        }
    }

    /// Core dispatch: tries techniques in curriculum order and returns the
    /// first that makes progress. When `apply` is true the step is applied.
    static func nextStep(
        puzzle: Puzzle,
        state: inout State,
        apply: Bool
    ) -> TechniqueApplication? {
        for technique in Technique.allCases {
            // Probe against a throwaway copy so a detector that ultimately
            // returns nil cannot leak partial mutation into the real state.
            var probe = state
            guard let step = detector(for: technique)(puzzle, &probe) else { continue }
            guard step.isUseful else { continue }
            if apply { applyStep(step, to: &state) }
            return step
        }
        return nil
    }

    // MARK: - Applying

    static func applyStep(_ step: TechniqueApplication, to state: inout State) {
        for elimination in step.eliminations {
            if let current = state.candidates[elimination.cell] {
                state.candidates[elimination.cell] = current & ~elimination.digits
            }
        }
        for placement in step.placements {
            state.entries[placement.cell] = placement.digit
            state.candidates[placement.cell] = nil
        }
    }

    /// Replays a step's eliminations onto a player's board notes, seeding notes
    /// from the full candidate set where a cell has none yet.
    ///
    /// Without the seeding, applying an elimination to an un-noted cell would
    /// look like nothing happened.
    static func applyEliminations(
        _ step: TechniqueApplication,
        to board: inout BoardState,
        size: Int
    ) {
        let everything = Set(1...size)
        for elimination in step.eliminations {
            let removed = Set(DigitSet.digits(elimination.digits))
            let existing = board.notes(at: elimination.cell)
            let base = existing.isEmpty ? everything : existing
            let next = base.subtracting(removed)
            board.notes[elimination.cell] = next.isEmpty ? nil : next
        }
    }

    // MARK: - Shared helpers

    /// Digits still viable in each cell of a cage, given current candidates.
    ///
    /// Returns nil when the cage has no viable assignment at all, which means
    /// the board is contradictory.
    private static func viableCageMasks(
        cage: Cage,
        gridSize: Int,
        state: State
    ) -> (masks: [UInt16], surviving: [[Int]])? {
        let assignments = CageCombinations.assignments(for: cage, gridSize: gridSize)
        var masks = [UInt16](repeating: 0, count: cage.cells.count)
        var surviving: [[Int]] = []

        for assignment in assignments {
            var viable = true
            for (i, digit) in assignment.enumerated() {
                let cell = cage.cells[i]
                if let entry = state.entries[cell] {
                    if entry != digit { viable = false; break }
                } else if !DigitSet.contains(state.candidates(at: cell), digit) {
                    viable = false
                    break
                }
            }
            guard viable else { continue }
            surviving.append(assignment)
            for (i, digit) in assignment.enumerated() {
                masks[i] |= DigitSet.mask(digit)
            }
        }

        return surviving.isEmpty ? nil : (masks, surviving)
    }

    /// Builds an elimination step from per-cage allowed masks, keeping only
    /// eliminations that actually remove a present candidate.
    private static func eliminationStep(
        technique: Technique,
        cage: Cage,
        cageIndex: Int,
        allowed: [UInt16],
        state: State,
        digits: [Int] = [],
        combinations: [UInt16] = []
    ) -> TechniqueApplication? {
        var eliminations: [Elimination] = []
        var focus: [Cell] = []

        for (i, cell) in cage.cells.enumerated() {
            guard let current = state.candidates[cell] else { continue }
            let removed = current & ~allowed[i]
            guard removed != 0 else { continue }
            eliminations.append(Elimination(cell: cell, digits: removed))
            focus.append(cell)
        }
        guard !eliminations.isEmpty else { return nil }

        var step = TechniqueApplication(technique: technique)
        step.eliminations = eliminations
        step.focusCells = cage.cells
        step.involvedCages = [cageIndex]
        step.explanation = ExplanationData(
            cageIndices: [cageIndex],
            digits: digits,
            combinations: combinations
        )
        return step
    }

    private static func allLines(size: Int) -> [Line] {
        (0..<size).map { Line(kind: .row, index: $0) }
            + (0..<size).map { Line(kind: .column, index: $0) }
    }

    // MARK: - T1 Freebie cage

    /// A single-cell cage has no operator: the target is the digit.
    static let detectFreebieCage: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated() where cage.isFreebie {
            let cell = cage.cells[0]
            guard state.entries[cell] == nil else { continue }
            guard DigitSet.contains(state.candidates(at: cell), cage.target) else { continue }

            var step = TechniqueApplication(technique: .freebieCage)
            step.placements = [Placement(cell: cell, digit: cage.target)]
            step.focusCells = [cell]
            step.involvedCages = [index]
            step.explanation = ExplanationData(cageIndices: [index], digits: [cage.target])
            return step
        }
        return nil
    }

    // MARK: - T2 Cage combination

    /// Only digits appearing in some still-viable assignment of the cage can
    /// remain. This is the workhorse every other cage technique rests on.
    static let detectCageCombination: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated() where !cage.isFreebie {
            guard let (masks, surviving) = viableCageMasks(
                cage: cage, gridSize: puzzle.size, state: state
            ) else { continue }

            // Teach as "combinations" only while the cage is genuinely
            // ambiguous; a fully determined cage is clearer as one of the
            // sharper techniques below.
            guard surviving.count > 1 else { continue }

            let combos = Set(surviving.map { DigitSet.fromDigits($0) }).sorted()
            if let step = eliminationStep(
                technique: .cageCombination, cage: cage, cageIndex: index,
                allowed: masks, state: state, combinations: combos
            ) { return step }
        }
        return nil
    }

    // MARK: - T3 Min/max bounds

    /// A digit is impossible if, taking it, the rest of an additive cage cannot
    /// reach the target — or cannot avoid overshooting it.
    ///
    /// Bounds are computed loosely (min/max of each remaining cell's candidates
    /// independently, ignoring the Latin constraint between them). That is a
    /// SUPERSET of the true achievable range, so it can only under-eliminate,
    /// never wrongly eliminate.
    static let detectMinMaxBounds: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated()
        where cage.operation == .add && cage.cells.count >= 2 {
            var allowed = [UInt16](repeating: 0, count: cage.cells.count)
            var anyChange = false

            for (i, cell) in cage.cells.enumerated() {
                let current: UInt16
                if let entry = state.entries[cell] {
                    current = DigitSet.mask(entry)
                } else {
                    current = state.candidates(at: cell)
                }

                // Bounds contributed by the other cells.
                var othersMin = 0, othersMax = 0
                for (j, other) in cage.cells.enumerated() where j != i {
                    if let entry = state.entries[other] {
                        othersMin += entry
                        othersMax += entry
                    } else {
                        let mask = state.candidates(at: other)
                        guard mask != 0 else { othersMin = Int.max; break }
                        othersMin += DigitSet.digits(mask).min()!
                        othersMax += DigitSet.digits(mask).max()!
                    }
                }
                guard othersMin != Int.max else { continue }

                for digit in DigitSet.digits(current) {
                    let remainder = cage.target - digit
                    if remainder >= othersMin && remainder <= othersMax {
                        allowed[i] |= DigitSet.mask(digit)
                    } else {
                        anyChange = true
                    }
                }
            }

            guard anyChange else { continue }
            if let step = eliminationStep(
                technique: .minMaxBounds, cage: cage, cageIndex: index,
                allowed: allowed, state: state
            ) { return step }
        }
        return nil
    }

    // MARK: - T4 Divisibility

    /// A digit that does not divide a multiplicative cage's target cannot
    /// appear in it.
    static let detectDivisibility: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated()
        where cage.operation == .multiply && cage.cells.count >= 2 {
            var allowed = [UInt16](repeating: 0, count: cage.cells.count)
            var removedDigits = Set<Int>()
            var anyChange = false

            for (i, cell) in cage.cells.enumerated() {
                guard let current = state.candidates[cell] else {
                    if let entry = state.entries[cell] { allowed[i] = DigitSet.mask(entry) }
                    continue
                }
                for digit in DigitSet.digits(current) {
                    if digit != 0 && cage.target % digit == 0 {
                        allowed[i] |= DigitSet.mask(digit)
                    } else {
                        removedDigits.insert(digit)
                        anyChange = true
                    }
                }
            }

            guard anyChange else { continue }
            if let step = eliminationStep(
                technique: .divisibility, cage: cage, cageIndex: index,
                allowed: allowed, state: state, digits: removedDigits.sorted()
            ) { return step }
        }
        return nil
    }

    // MARK: - T5 Pair sets

    /// Two-cell subtraction and division cages have very small candidate sets,
    /// and knowing their shape is a real skill. `5−` in a 6x6 is only {1,6};
    /// `2÷` can never contain a 5.
    static let detectPairSets: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated()
        where cage.operation == .subtract || cage.operation == .divide {
            guard let (masks, surviving) = viableCageMasks(
                cage: cage, gridSize: puzzle.size, state: state
            ) else { continue }

            let combos = Set(surviving.map { DigitSet.fromDigits($0) }).sorted()
            if let step = eliminationStep(
                technique: .pairSets, cage: cage, cageIndex: index,
                allowed: masks, state: state, combinations: combos
            ) { return step }
        }
        return nil
    }

    // MARK: - T6 Naked single

    /// One candidate left in a cell.
    static let detectNakedSingle: Detector = { _, state in
        for cell in state.openCells {
            let mask = state.candidates(at: cell)
            guard DigitSet.count(mask) == 1 else { continue }
            let digit = DigitSet.digits(mask)[0]

            var step = TechniqueApplication(technique: .nakedSingle)
            step.placements = [Placement(cell: cell, digit: digit)]
            step.focusCells = [cell]
            step.explanation = ExplanationData(digits: [digit])
            return step
        }
        return nil
    }

    // MARK: - T7 Hidden single

    /// A digit that can legally occupy only one cell of a row or column, even
    /// though that cell has other candidates.
    static let detectHiddenSingle: Detector = { puzzle, state in
        for line in allLines(size: puzzle.size) {
            let open = state.openCells(in: line)
            guard open.count > 1 else { continue }
            let used = state.usedDigits(in: line)

            for digit in 1...puzzle.size where !DigitSet.contains(used, digit) {
                let bit = DigitSet.mask(digit)
                let homes = open.filter { DigitSet.contains(state.candidates(at: $0), digit) }
                guard homes.count == 1, let home = homes.first else { continue }
                // A cell with only this candidate is a naked single, which is
                // the simpler explanation — leave it to T6.
                guard state.candidates(at: home) != bit else { continue }

                var step = TechniqueApplication(technique: .hiddenSingle)
                step.placements = [Placement(cell: home, digit: digit)]
                step.focusCells = line.cells(size: puzzle.size)
                step.explanation = ExplanationData(digits: [digit], line: line)
                return step
            }
        }
        return nil
    }

    // MARK: - T8 Last cell in a line

    /// A row or column with exactly one empty cell.
    static let detectLastCellInLine: Detector = { puzzle, state in
        for line in allLines(size: puzzle.size) {
            let open = state.openCells(in: line)
            guard open.count == 1, let cell = open.first else { continue }
            let used = state.usedDigits(in: line)
            let missing = DigitSet.all(size: puzzle.size) & ~used
            guard DigitSet.count(missing) == 1 else { continue }
            let digit = DigitSet.digits(missing)[0]
            guard DigitSet.contains(state.candidates(at: cell), digit) else { continue }

            var step = TechniqueApplication(technique: .lastCellInLine)
            step.placements = [Placement(cell: cell, digit: digit)]
            step.focusCells = line.cells(size: puzzle.size)
            step.explanation = ExplanationData(digits: [digit], line: line)
            return step
        }
        return nil
    }

    // MARK: - T9 Naked subset

    /// `k` cells in a line whose candidates union to exactly `k` digits: those
    /// digits belong to those cells, so they leave the rest of the line.
    static let detectNakedSubset: Detector = { puzzle, state in
        for line in allLines(size: puzzle.size) {
            let open = state.openCells(in: line)
            guard open.count >= 3 else { continue }

            for k in 2...min(4, open.count - 1) {
                for group in combinations(of: open, choose: k) {
                    let union = group.reduce(UInt16(0)) { $0 | state.candidates(at: $1) }
                    guard DigitSet.count(union) == k else { continue }

                    var eliminations: [Elimination] = []
                    for cell in open where !group.contains(cell) {
                        let removed = state.candidates(at: cell) & union
                        guard removed != 0 else { continue }
                        eliminations.append(Elimination(cell: cell, digits: removed))
                    }
                    guard !eliminations.isEmpty else { continue }

                    var step = TechniqueApplication(technique: .nakedSubset)
                    step.eliminations = eliminations
                    step.focusCells = group
                    step.explanation = ExplanationData(
                        digits: DigitSet.digits(union), line: line
                    )
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - T10 Hidden subset

    /// `k` digits in a line that can only occur in `k` cells: those cells hold
    /// exactly those digits, so every other candidate leaves them.
    static let detectHiddenSubset: Detector = { puzzle, state in
        for line in allLines(size: puzzle.size) {
            let open = state.openCells(in: line)
            guard open.count >= 3 else { continue }
            let used = state.usedDigits(in: line)
            let available = DigitSet.digits(DigitSet.all(size: puzzle.size) & ~used)
            guard available.count >= 3 else { continue }

            for k in 2...min(4, available.count - 1) {
                for group in combinations(of: available, choose: k) {
                    let mask = DigitSet.fromDigits(group)
                    let homes = open.filter { state.candidates(at: $0) & mask != 0 }
                    guard homes.count == k else { continue }

                    var eliminations: [Elimination] = []
                    for cell in homes {
                        let removed = state.candidates(at: cell) & ~mask
                        guard removed != 0 else { continue }
                        eliminations.append(Elimination(cell: cell, digits: removed))
                    }
                    guard !eliminations.isEmpty else { continue }

                    var step = TechniqueApplication(technique: .hiddenSubset)
                    step.eliminations = eliminations
                    step.focusCells = homes
                    step.explanation = ExplanationData(digits: group, line: line)
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - T11 Pointing (cage → line)

    /// If a digit must appear in a cage, and every cell that could hold it lies
    /// in one row or column, then it lives in that line — so it leaves the rest
    /// of the line.
    static let detectPointingCage: Detector = { puzzle, state in
        for (index, cage) in puzzle.cages.enumerated() where cage.cells.count >= 2 {
            guard let (_, surviving) = viableCageMasks(
                cage: cage, gridSize: puzzle.size, state: state
            ) else { continue }

            for digit in 1...puzzle.size {
                // The digit must be REQUIRED — present in every viable
                // assignment. If some assignment omits it, nothing follows.
                guard surviving.allSatisfy({ $0.contains(digit) }) else { continue }

                // Cells that could hold it.
                var homes: [Cell] = []
                for (i, cell) in cage.cells.enumerated()
                where surviving.contains(where: { $0[i] == digit }) {
                    homes.append(cell)
                }
                guard homes.count >= 1 else { continue }

                for line in linesContainingAll(homes) {
                    var eliminations: [Elimination] = []
                    for cell in line.cells(size: puzzle.size)
                    where !cage.cells.contains(cell) {
                        guard let current = state.candidates[cell],
                              DigitSet.contains(current, digit) else { continue }
                        eliminations.append(Elimination(cell: cell, digits: DigitSet.mask(digit)))
                    }
                    guard !eliminations.isEmpty else { continue }

                    var step = TechniqueApplication(technique: .pointingCage)
                    step.eliminations = eliminations
                    step.focusCells = homes
                    step.involvedCages = [index]
                    step.explanation = ExplanationData(
                        cageIndices: [index], digits: [digit], line: line
                    )
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - T12 Claiming (line → cage)

    /// If a digit in a line can only sit inside one cage's cells, that cage must
    /// contain it — which kills every cage assignment that omits it.
    static let detectClaimingLine: Detector = { puzzle, state in
        for line in allLines(size: puzzle.size) {
            let open = state.openCells(in: line)
            guard open.count >= 2 else { continue }
            let used = state.usedDigits(in: line)

            for digit in 1...puzzle.size where !DigitSet.contains(used, digit) {
                let homes = open.filter { DigitSet.contains(state.candidates(at: $0), digit) }
                guard homes.count >= 2 else { continue }  // one home is a hidden single

                // All homes must belong to the same cage.
                guard let first = puzzle.cageIndex(containing: homes[0]) else { continue }
                guard homes.allSatisfy({ puzzle.cageIndex(containing: $0) == first })
                else { continue }

                let cage = puzzle.cages[first]
                guard let (_, surviving) = viableCageMasks(
                    cage: cage, gridSize: puzzle.size, state: state
                ) else { continue }

                // Keep only assignments placing the digit somewhere in this line.
                let kept = surviving.filter { assignment in
                    zip(cage.cells, assignment).contains { line.contains($0.0) && $0.1 == digit }
                }
                guard !kept.isEmpty, kept.count < surviving.count else { continue }

                var allowed = [UInt16](repeating: 0, count: cage.cells.count)
                for assignment in kept {
                    for (i, d) in assignment.enumerated() { allowed[i] |= DigitSet.mask(d) }
                }

                if var step = eliminationStep(
                    technique: .claimingLine, cage: cage, cageIndex: first,
                    allowed: allowed, state: state, digits: [digit]
                ) {
                    step.explanation.line = line
                    step.focusCells = homes
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - T13 Rule of N

    /// Every row and column sums to `N(N+1)/2`. Cages lying wholly inside a line
    /// account for part of that total, so the cells they leave over have a known
    /// sum — often pinning a single cell outright.
    static let detectRuleOfN: Detector = { puzzle, state in
        let lineTotal = LatinSquare.lineSum(size: puzzle.size)

        for line in allLines(size: puzzle.size) {
            let inside = puzzle.cages.enumerated().filter { _, cage in
                cage.cells.allSatisfy { line.contains($0) }
            }
            guard !inside.isEmpty else { continue }

            // Bound the contribution of each wholly-contained cage.
            var knownMin = 0, knownMax = 0
            var covered = Set<Cell>()
            var ok = true
            for (_, cage) in inside {
                guard let (_, surviving) = viableCageMasks(
                    cage: cage, gridSize: puzzle.size, state: state
                ) else { ok = false; break }
                let sums = surviving.map { $0.reduce(0, +) }
                knownMin += sums.min()!
                knownMax += sums.max()!
                covered.formUnion(cage.cells)
            }
            guard ok else { continue }

            // What the line's other cells must total.
            var remainder = line.cells(size: puzzle.size).filter { !covered.contains($0) }
            guard !remainder.isEmpty, remainder.count <= 4 else { continue }

            var placedTotal = 0
            remainder.removeAll { cell in
                if let value = state.entries[cell] { placedTotal += value; return true }
                return false
            }
            guard !remainder.isEmpty else { continue }

            let targetMin = lineTotal - knownMax - placedTotal
            let targetMax = lineTotal - knownMin - placedTotal

            var allowed = [UInt16](repeating: 0, count: remainder.count)
            var changed = false

            for (i, cell) in remainder.enumerated() {
                // Range the other open remainder cells can supply.
                var othersMin = 0, othersMax = 0
                var viable = true
                for (j, other) in remainder.enumerated() where j != i {
                    let mask = state.candidates(at: other)
                    guard mask != 0 else { viable = false; break }
                    let digits = DigitSet.digits(mask)
                    othersMin += digits.min()!
                    othersMax += digits.max()!
                }
                guard viable else { continue }

                for digit in DigitSet.digits(state.candidates(at: cell)) {
                    // This digit is possible only if the rest can close the gap.
                    let lo = targetMin - digit, hi = targetMax - digit
                    if hi >= othersMin && lo <= othersMax {
                        allowed[i] |= DigitSet.mask(digit)
                    } else {
                        changed = true
                    }
                }
            }
            guard changed else { continue }

            var eliminations: [Elimination] = []
            for (i, cell) in remainder.enumerated() {
                guard let current = state.candidates[cell] else { continue }
                let removed = current & ~allowed[i]
                guard removed != 0 else { continue }
                eliminations.append(Elimination(cell: cell, digits: removed))
            }
            guard !eliminations.isEmpty else { continue }

            var step = TechniqueApplication(technique: .ruleOfN)
            step.eliminations = eliminations
            step.focusCells = line.cells(size: puzzle.size)
            step.involvedCages = inside.map(\.offset)
            step.explanation = ExplanationData(
                cageIndices: inside.map(\.offset), line: line
            )
            return step
        }
        return nil
    }

    // MARK: - T14 Outie

    /// When the cages covering a line spill past it by exactly one cell, that
    /// cell is the difference between their total and the line's.
    static let detectOutie: Detector = { puzzle, state in
        let lineTotal = LatinSquare.lineSum(size: puzzle.size)

        for line in allLines(size: puzzle.size) {
            let lineCells = Set(line.cells(size: puzzle.size))
            let touching = puzzle.cages.enumerated().filter { _, cage in
                cage.cells.contains { lineCells.contains($0) }
            }
            guard !touching.isEmpty else { continue }

            let union = Set(touching.flatMap { $0.element.cells })
            let spill = union.subtracting(lineCells)
            guard spill.count == 1, let outside = spill.first else { continue }
            guard state.entries[outside] == nil else { continue }
            guard state.candidates[outside] != nil else { continue }

            // Every touching cage needs a determined sum for the arithmetic
            // to close; a range would only bound the outie, which the Rule of N
            // detector already covers.
            var total = 0
            var ok = true
            for (_, cage) in touching {
                guard let (_, surviving) = viableCageMasks(
                    cage: cage, gridSize: puzzle.size, state: state
                ) else { ok = false; break }
                let sums = Set(surviving.map { $0.reduce(0, +) })
                guard sums.count == 1, let sum = sums.first else { ok = false; break }
                total += sum
            }
            guard ok else { continue }

            let value = total - lineTotal
            guard value >= 1, value <= puzzle.size else { continue }
            guard DigitSet.contains(state.candidates(at: outside), value) else { continue }
            guard state.candidates(at: outside) != DigitSet.mask(value) else { continue }

            var step = TechniqueApplication(technique: .outie)
            step.placements = [Placement(cell: outside, digit: value)]
            step.focusCells = line.cells(size: puzzle.size) + [outside]
            step.involvedCages = touching.map(\.offset)
            step.explanation = ExplanationData(
                cageIndices: touching.map(\.offset), digits: [value], line: line
            )
            return step
        }
        return nil
    }

    // MARK: - T15 Parity

    /// Every line holds exactly `ceil(N/2)` odd digits and `floor(N/2)` even
    /// ones. Once the odd slots are spoken for, every remaining cell must be
    /// even — and the other way round.
    ///
    /// Genuinely Calcudoku-native: Sudoku has no analogue.
    static let detectParity: Detector = { puzzle, state in
        let size = puzzle.size
        let oddSlots = (size + 1) / 2
        let evenSlots = size / 2
        let oddMask = DigitSet.fromDigits(stride(from: 1, through: size, by: 2))
        let evenMask = DigitSet.fromDigits(stride(from: 2, through: size, by: 2))

        for line in allLines(size: size) {
            var placedOdd = 0, placedEven = 0
            for cell in line.cells(size: size) {
                guard let value = state.entries[cell] else { continue }
                if value % 2 == 0 { placedEven += 1 } else { placedOdd += 1 }
            }

            let open = state.openCells(in: line)
            guard open.count >= 2 else { continue }

            let forcedOdd = open.filter { state.candidates(at: $0) & evenMask == 0 }
            let forcedEven = open.filter { state.candidates(at: $0) & oddMask == 0 }

            // Odd slots exhausted: everything still free must be even.
            if placedOdd + forcedOdd.count == oddSlots {
                var eliminations: [Elimination] = []
                for cell in open where !forcedOdd.contains(cell) {
                    let removed = state.candidates(at: cell) & oddMask
                    guard removed != 0 else { continue }
                    eliminations.append(Elimination(cell: cell, digits: removed))
                }
                if !eliminations.isEmpty {
                    var step = TechniqueApplication(technique: .parity)
                    step.eliminations = eliminations
                    step.focusCells = line.cells(size: size)
                    step.explanation = ExplanationData(
                        digits: DigitSet.digits(oddMask), line: line
                    )
                    return step
                }
            }

            // And symmetrically.
            if placedEven + forcedEven.count == evenSlots {
                var eliminations: [Elimination] = []
                for cell in open where !forcedEven.contains(cell) {
                    let removed = state.candidates(at: cell) & evenMask
                    guard removed != 0 else { continue }
                    eliminations.append(Elimination(cell: cell, digits: removed))
                }
                if !eliminations.isEmpty {
                    var step = TechniqueApplication(technique: .parity)
                    step.eliminations = eliminations
                    step.focusCells = line.cells(size: size)
                    step.explanation = ExplanationData(
                        digits: DigitSet.digits(evenMask), line: line
                    )
                    return step
                }
            }
        }
        return nil
    }

    // MARK: - T16 X-Wing

    /// A digit confined to the same two columns in two different rows occupies
    /// one cell in each, so it leaves those columns everywhere else. Reads
    /// cleanly here because rows and columns are the only groups — there are no
    /// boxes to complicate it.
    static let detectXWing: Detector = { puzzle, state in
        let size = puzzle.size

        for orientation in [Line.Kind.row, .column] {
            let cross: Line.Kind = orientation == .row ? .column : .row

            for digit in 1...size {
                // Which cross-indices can hold this digit, per line.
                var positions: [Int: [Int]] = [:]
                for index in 0..<size {
                    let line = Line(kind: orientation, index: index)
                    guard !DigitSet.contains(state.usedDigits(in: line), digit) else { continue }
                    let homes = state.openCells(in: line)
                        .filter { DigitSet.contains(state.candidates(at: $0), digit) }
                        .map { orientation == .row ? $0.col : $0.row }
                    if homes.count == 2 { positions[index] = homes.sorted() }
                }
                guard positions.count >= 2 else { continue }

                let keys = positions.keys.sorted()
                for i in 0..<keys.count {
                    for j in (i + 1)..<keys.count {
                        let a = keys[i], b = keys[j]
                        guard positions[a] == positions[b], let pair = positions[a] else { continue }

                        var eliminations: [Elimination] = []
                        for crossIndex in pair {
                            let crossLine = Line(kind: cross, index: crossIndex)
                            for cell in state.openCells(in: crossLine) {
                                let own = orientation == .row ? cell.row : cell.col
                                guard own != a, own != b else { continue }
                                guard DigitSet.contains(state.candidates(at: cell), digit)
                                else { continue }
                                eliminations.append(
                                    Elimination(cell: cell, digits: DigitSet.mask(digit))
                                )
                            }
                        }
                        guard !eliminations.isEmpty else { continue }

                        var focus: [Cell] = []
                        for own in [a, b] {
                            for crossIndex in pair {
                                focus.append(
                                    orientation == .row
                                        ? Cell(own, crossIndex)
                                        : Cell(crossIndex, own)
                                )
                            }
                        }

                        var step = TechniqueApplication(technique: .xWing)
                        step.eliminations = eliminations
                        step.focusCells = focus
                        step.explanation = ExplanationData(digits: [digit])
                        return step
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Combinatorial helper

    /// Lines containing every one of the given cells. Empty when they are
    /// spread across both a row and a column.
    private static func linesContainingAll(_ cells: [Cell]) -> [Line] {
        guard let first = cells.first else { return [] }
        var out: [Line] = []
        if cells.allSatisfy({ $0.row == first.row }) {
            out.append(Line(kind: .row, index: first.row))
        }
        if cells.allSatisfy({ $0.col == first.col }) {
            out.append(Line(kind: .column, index: first.col))
        }
        return out
    }

    /// All `k`-subsets, in a deterministic order.
    private static func combinations<T>(of items: [T], choose k: Int) -> [[T]] {
        guard k > 0, k <= items.count else { return [] }
        var result: [[T]] = []
        var current: [T] = []

        func recurse(_ start: Int) {
            if current.count == k { result.append(current); return }
            guard start < items.count else { return }
            for i in start..<items.count {
                current.append(items[i])
                recurse(i + 1)
                current.removeLast()
            }
        }

        recurse(0)
        return result
    }
}
