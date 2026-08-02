//
//  enginecheck.swift
//  Numeriqo engine CLI harness
//
//  Compile with the engine sources and run outside the simulator:
//
//      swiftc -O -o /tmp/enginecheck Numeriqo/Engine/*.swift Tools/enginecheck.swift
//      /tmp/enginecheck
//
//  Benchmark output goes to stderr — stdout is block-buffered under a pipe.
//

import Foundation

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: @autoclosure () -> String = "assertion failed") {
    checks += 1
    if !condition {
        failures += 1
        print("  FAIL: \(message())")
    }
}

func section(_ title: String) {
    print("\n\(title)")
    print(String(repeating: "-", count: title.count))
}

// MARK: - All cage shapes of a given size within a small grid

/// Every orthogonally connected set of `k` cells inside a `gridSize` grid,
/// deduplicated by conflict graph so we test each distinct *shape* once.
func distinctShapes(count k: Int, gridSize: Int) -> [[Cell]] {
    var all: [[Cell]] = []
    var seen = Set<[Int]>()

    var current: [Cell] = []

    func grow() {
        if current.count == k {
            let shape = CageCombinations.Shape(cells: current.sorted())
            let signature = [shape.count] + shape.conflicts
            if seen.insert(signature).inserted {
                all.append(current.sorted())
            }
            return
        }
        // Candidate frontier: cells orthogonally adjacent to the current set.
        var frontier = Set<Cell>()
        if current.isEmpty {
            for r in 0..<gridSize { for c in 0..<gridSize { frontier.insert(Cell(r, c)) } }
        } else {
            for cell in current {
                for n in [Cell(cell.row - 1, cell.col), Cell(cell.row + 1, cell.col),
                          Cell(cell.row, cell.col - 1), Cell(cell.row, cell.col + 1)] {
                    guard n.row >= 0, n.row < gridSize, n.col >= 0, n.col < gridSize else { continue }
                    if !current.contains(n) { frontier.insert(n) }
                }
            }
        }
        for cell in frontier.sorted() {
            current.append(cell)
            grow()
            current.removeLast()
        }
    }

    grow()
    return all
}

// MARK: - 1. Differential test against brute force

section("1. Cage enumeration vs brute force")

var comparisons = 0
for gridSize in 3...6 {
    for k in 1...min(4, gridSize * gridSize) {
        let shapes = distinctShapes(count: k, gridSize: gridSize)
        for operation in Operation.allCases {
            if operation == .none && k != 1 { continue }
            if operation != .none && k == 1 { continue }
            if operation.requiresExactlyTwoCells && k != 2 { continue }

            // Targets worth probing: everything reachable, plus a couple past the end.
            let maxTarget: Int
            switch operation {
            case .none:     maxTarget = gridSize + 1
            case .add:      maxTarget = k * gridSize + 1
            case .multiply: maxTarget = Int(pow(Double(gridSize), Double(k))) + 1
            case .subtract: maxTarget = gridSize + 1
            case .divide:   maxTarget = gridSize + 1
            }

            for target in 0...min(maxTarget, 400) {
                for cells in shapes {
                    CageCombinations.clearCache()
                    let fast = CageCombinations.assignments(
                        gridSize: gridSize, operation: operation, target: target, cells: cells
                    ).map { $0 }.sorted { $0.lexicographicallyPrecedes($1) }

                    let slow = CageCombinations.bruteForceAssignments(
                        gridSize: gridSize, operation: operation, target: target, cells: cells
                    ).sorted { $0.lexicographicallyPrecedes($1) }

                    comparisons += 1
                    if fast != slow {
                        failures += 1
                        checks += 1
                        print("  FAIL n=\(gridSize) \(operation.rawValue) target=\(target) cells=\(cells.map { "(\($0.row),\($0.col))" }.joined())")
                        print("        fast=\(fast.prefix(6))  slow=\(slow.prefix(6))")
                        print("        counts fast=\(fast.count) slow=\(slow.count)")
                    }
                }
            }
        }
    }
}
checks += 1
print("  compared \(comparisons) (gridSize, operation, target, shape) combinations")

// MARK: - 2. The repeat rule

section("2. Digits may repeat in a dog-leg, never in a straight line")

// 6x6, three-cell 20x. Straight line -> {1,4,5}. L-shape -> also {2,2,5}.
let straight20 = [Cell(0, 0), Cell(0, 1), Cell(0, 2)]
let elbow20 = [Cell(0, 0), Cell(0, 1), Cell(1, 1)]

let straightSets = CageCombinations.multisets(
    for: Cage(cells: straight20, operation: .multiply, target: 20), gridSize: 6
)
let elbowSets = CageCombinations.multisets(
    for: Cage(cells: elbow20, operation: .multiply, target: 20), gridSize: 6
)

expect(straightSets == [[1, 4, 5]], "straight 20x should be only {1,4,5}, got \(straightSets)")
expect(elbowSets.contains([1, 4, 5]), "L-shaped 20x should include {1,4,5}, got \(elbowSets)")
expect(elbowSets.contains([2, 2, 5]), "L-shaped 20x should include {2,2,5}, got \(elbowSets)")

// The two 2s must land in cells that share neither row nor column.
let elbowCage = Cage(cells: elbow20, operation: .multiply, target: 20)
for assignment in CageCombinations.assignments(for: elbowCage, gridSize: 6) {
    for a in 0..<3 {
        for b in (a + 1)..<3 where assignment[a] == assignment[b] {
            expect(
                !elbowCage.cells[a].conflicts(with: elbowCage.cells[b]),
                "repeat placed in conflicting cells: \(assignment)"
            )
        }
    }
}

// A straight-line cage can never produce a repeat, at any size or target.
for gridSize in 3...6 {
    for target in 1...(3 * gridSize) {
        let cage = Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)], operation: .add, target: target)
        for assignment in CageCombinations.assignments(for: cage, gridSize: gridSize) {
            expect(Set(assignment).count == assignment.count,
                   "straight-line add cage repeated a digit: \(assignment) n=\(gridSize) t=\(target)")
        }
    }
}

// MARK: - 3. Two-cell subtraction and division tables

section("3. Two-cell - and / pair counts")

// docs/TECHNIQUES.md T5: in an NxN grid, `t-` has exactly N-t pairs
// and `t/` has exactly floor(N/t).
for gridSize in 3...9 {
    for target in 1..<gridSize {
        let cage = Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .subtract, target: target)
        let sets = CageCombinations.multisets(for: cage, gridSize: gridSize)
        expect(sets.count == gridSize - target,
               "n=\(gridSize) \(target)- expected \(gridSize - target) pairs, got \(sets.count)")
    }
    for target in 2...gridSize {
        let cage = Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .divide, target: target)
        let sets = CageCombinations.multisets(for: cage, gridSize: gridSize)
        expect(sets.count == gridSize / target,
               "n=\(gridSize) \(target)/ expected \(gridSize / target) pairs, got \(sets.count)")
    }
}

// The forced pairs a beginner board depends on (6x6).
expect(CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .subtract, target: 5), gridSize: 6
) == [[1, 6]], "6x6 5- should be forced {1,6}")

for (target, expected) in [(4, [1, 4]), (5, [1, 5]), (6, [1, 6])] {
    let got = CageCombinations.multisets(
        for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .divide, target: target), gridSize: 6
    )
    expect(got == [expected], "6x6 \(target)/ should be forced \(expected), got \(got)")
}

// 6x6 2/ can never contain a 5 — no whole-number partner exists.
let twoDiv = CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .divide, target: 2), gridSize: 6
)
expect(twoDiv == [[1, 2], [2, 4], [3, 6]], "6x6 2/ pairs wrong: \(twoDiv)")
expect(!twoDiv.contains { $0.contains(5) }, "6x6 2/ must never contain a 5")

// MARK: - 4. Known worked examples from the docs

section("4. Worked examples from docs/TECHNIQUES.md")

// T4: 6x6 40x on three cells -> {2,4,5} only (3 and 6 do not divide 40).
for cells in [[Cell(0, 0), Cell(0, 1), Cell(0, 2)], [Cell(0, 0), Cell(0, 1), Cell(1, 1)]] {
    let sets = CageCombinations.multisets(
        for: Cage(cells: cells, operation: .multiply, target: 40), gridSize: 6
    )
    expect(sets == [[2, 4, 5]], "6x6 40x should be {2,4,5}, got \(sets)")
}

// T3: 6x6 three-cell 7+ straight line -> {1,2,4} only.
let sevenPlus = CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)], operation: .add, target: 7), gridSize: 6
)
expect(sevenPlus == [[1, 2, 4]], "6x6 straight 7+ should be {1,2,4}, got \(sevenPlus)")

// T11: 6x6 two-cell 11+ -> {5,6} only.
let elevenPlus = CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .add, target: 11), gridSize: 6
)
expect(elevenPlus == [[5, 6]], "6x6 11+ should be {5,6}, got \(elevenPlus)")

// T20 parity: 6x6 two-cell 12x -> {2,6} and {3,4}.
let twelveTimes = CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .multiply, target: 12), gridSize: 6
)
expect(twelveTimes == [[2, 6], [3, 4]], "6x6 12x should be {2,6},{3,4}, got \(twelveTimes)")

// 25x requires two 5s, so it can only exist on a dog-leg.
expect(CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .multiply, target: 25), gridSize: 6
).isEmpty, "6x6 straight 25x must be impossible")
expect(CageCombinations.multisets(
    for: Cage(cells: [Cell(0, 0), Cell(1, 1)], operation: .multiply, target: 25), gridSize: 6
) == [[5, 5]], "6x6 dog-leg 25x should be {5,5}")

// MARK: - 5. Model invariants

section("5. Model invariants")

expect(Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)], operation: .add, target: 6).isStraightLine)
expect(Cage(cells: [Cell(0, 0), Cell(1, 0), Cell(2, 0)], operation: .add, target: 6).isStraightLine)
expect(!Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(1, 1)], operation: .add, target: 6).isStraightLine)

expect(Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .add, target: 3).isOrthogonallyConnected)
expect(!Cage(cells: [Cell(0, 0), Cell(2, 2)], operation: .add, target: 3).isOrthogonallyConnected)

// Well-formedness rejects the degenerate - and / targets.
expect(!Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .subtract, target: 0)
    .isWellFormed(gridSize: 6), "0- implies a repeat and must be rejected")
expect(!Cage(cells: [Cell(0, 0), Cell(0, 1)], operation: .divide, target: 1)
    .isWellFormed(gridSize: 6), "1/ implies a repeat and must be rejected")
expect(!Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2)], operation: .subtract, target: 2)
    .isWellFormed(gridSize: 6), "- on three cells must be rejected")

// Rule of N / n! constants used by T14 and T16.
expect(LatinSquare.lineSum(size: 4) == 10)
expect(LatinSquare.lineSum(size: 6) == 21)
expect(LatinSquare.lineSum(size: 9) == 45)
expect(LatinSquare.lineProduct(size: 6) == 720)
expect(LatinSquare.lineProduct(size: 9) == 362_880)

expect(LatinSquare.isValid([[1, 2], [2, 1]], size: 2))
expect(!LatinSquare.isValid([[1, 2], [1, 2]], size: 2))

// MARK: - 6. Cache correctness and cost

section("6. Cache")

CageCombinations.clearCache()
let cacheCage = Cage(cells: [Cell(0, 0), Cell(0, 1), Cell(1, 1)], operation: .add, target: 9)
let cold = CageCombinations.assignments(for: cacheCage, gridSize: 6)
let warm = CageCombinations.assignments(for: cacheCage, gridSize: 6)
expect(cold == warm, "cache returned a different result than the cold call")

// Shape-equal cages at different positions must share a cache entry, so the
// results must agree cell-for-cell.
let shifted = Cage(cells: [Cell(2, 3), Cell(2, 4), Cell(3, 4)], operation: .add, target: 9)
expect(CageCombinations.assignments(for: shifted, gridSize: 6) == cold,
       "translated cage of identical shape should enumerate identically")

// A 9x9 five-cell cage is the realistic worst case in generation.
let big = Cage(
    cells: [Cell(0, 0), Cell(0, 1), Cell(0, 2), Cell(1, 2), Cell(2, 2)],
    operation: .multiply, target: 15_120
)
CageCombinations.clearCache()
let start = Date()
let bigResults = CageCombinations.assignments(for: big, gridSize: 9)
let elapsed = Date().timeIntervalSince(start)
FileHandle.standardError.write(
    "  9x9 five-cell 15120x: \(bigResults.count) assignments in \(String(format: "%.1f", elapsed * 1000))ms\n"
        .data(using: .utf8)!
)
expect(!bigResults.isEmpty, "9x9 15120x should have assignments (9*8*7*6*5)")
expect(bigResults.allSatisfy { $0.reduce(1, *) == 15_120 }, "big cage produced a wrong product")

// MARK: - 7. Latin square generation

section("7. Latin square generation")

for size in 3...9 {
    var rng = SeededRandomNumberGenerator(seed: UInt64(size) &* 7919)
    guard let square = PuzzleGenerator.latinSquare(size: size, using: &rng) else {
        expect(false, "failed to generate a \(size)x\(size) Latin square")
        continue
    }
    expect(LatinSquare.isValid(square, size: size), "invalid \(size)x\(size) Latin square")
}

// Determinism: the same seed must reproduce the same square, or dailies break.
for size in [4, 6, 9] {
    var a = SeededRandomNumberGenerator(seed: 12345)
    var b = SeededRandomNumberGenerator(seed: 12345)
    expect(PuzzleGenerator.latinSquare(size: size, using: &a)
        == PuzzleGenerator.latinSquare(size: size, using: &b),
        "\(size)x\(size) generation is not deterministic for a fixed seed")
}

// Variety: the legacy cyclic construction made every row a shift of every
// other. Confirm we are not doing that — distinct seeds should give distinct
// squares, and rows should not all be rotations of row 0.
do {
    var squares = Set<[[Int]]>()
    for seed in 0..<40 {
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        if let s = PuzzleGenerator.latinSquare(size: 6, using: &rng) { squares.insert(s) }
    }
    expect(squares.count >= 35, "expected varied 6x6 squares, got \(squares.count) distinct of 40")

    var rotationBound = 0
    for square in squares {
        let first = square[0]
        let allRotations = square.allSatisfy { row in
            (0..<6).contains { k in row == Array(first[k...] + first[..<k]) }
        }
        if allRotations { rotationBound += 1 }
    }
    expect(rotationBound < squares.count / 2,
           "\(rotationBound)/\(squares.count) squares are pure row-rotations — cyclic bias")
}

// MARK: - 8. Cage partition

section("8. Cage partition")

for size in 3...9 {
    var rng = SeededRandomNumberGenerator(seed: UInt64(size) &* 104_729)
    let opts = PuzzleGenerator.Options.forSize(size)
    let groups = PuzzleGenerator.partition(size: size, options: opts, using: &rng)

    let all = groups.flatMap { $0 }
    expect(all.count == size * size, "\(size)x\(size) partition covered \(all.count) cells")
    expect(Set(all).count == all.count, "\(size)x\(size) partition has overlapping cages")
    expect(groups.allSatisfy { $0.count <= opts.maxCageSize },
           "\(size)x\(size) partition exceeded maxCageSize")
    expect(groups.allSatisfy {
        Cage(cells: $0, operation: .add, target: 1).isOrthogonallyConnected
    }, "\(size)x\(size) partition produced a disconnected cage")
}

// MARK: - 9. End-to-end generation

section("9. End-to-end generation (uniqueness proved)")

for size in 3...7 {
    var generated = 0
    var totalAttempts = 0
    let start = Date()

    for seed in 0..<6 {
        guard let result = PuzzleGenerator.generate(
            size: size, seed: UInt64(seed &* 31 &+ size &* 977)
        ) else { continue }
        generated += 1
        totalAttempts += result.attempts

        let puzzle = result.puzzle
        expect(puzzle.isWellFormed(), "\(size)x\(size) seed \(seed): malformed puzzle")

        // The invariant the whole product rests on.
        let count = BacktrackingSolver.countSolutions(size: size, cages: puzzle.cages, limit: 2)
        expect(count == 1, "\(size)x\(size) seed \(seed): \(count) solutions, expected exactly 1")

        // The solver must recover the very grid the generator started from.
        if let solved = BacktrackingSolver.solve(size: size, cages: puzzle.cages) {
            expect(solved == puzzle.solution,
                   "\(size)x\(size) seed \(seed): solver disagreed with the seeded solution")
        } else {
            expect(false, "\(size)x\(size) seed \(seed): solver found no solution")
        }
    }

    let elapsed = Date().timeIntervalSince(start)
    expect(generated >= 5, "\(size)x\(size) generated only \(generated)/6")
    FileHandle.standardError.write(
        "  \(size)x\(size): \(generated)/6 in \(String(format: "%.2f", elapsed))s "
            .appending("(avg \(String(format: "%.1f", Double(totalAttempts) / Double(max(generated, 1)))) attempts)\n")
            .data(using: .utf8)!
    )
}

// Generation determinism — dailies depend on it.
do {
    let a = PuzzleGenerator.generate(size: 5, seed: 424_242)
    let b = PuzzleGenerator.generate(size: 5, seed: 424_242)
    expect(a?.puzzle == b?.puzzle, "generation is not deterministic for a fixed seed")
}

// MARK: - 10. Generation quality

section("10. Generation quality")

// A generator can buy uniqueness cheaply by emitting freebies — fast, unique,
// and not worth solving. These bounds pin the shape of what ships.
for size in [5, 6, 7, 9] {
    var freebieShares: [Double] = []
    var cageSizes: [Double] = []
    var opCounts: [Operation: Int] = [:]
    var produced = 0

    for seed in 0..<25 {
        guard let r = PuzzleGenerator.generate(
            size: size, seed: UInt64(seed &* 6151 &+ size)
        ) else { continue }
        produced += 1
        let cages = r.puzzle.cages
        freebieShares.append(Double(cages.filter(\.isFreebie).count) / Double(cages.count))
        cageSizes.append(Double(cages.map(\.cells.count).reduce(0, +)) / Double(cages.count))
        for c in cages { opCounts[c.operation, default: 0] += 1 }

        expect(PuzzleGenerator.meetsQualityBar(r.puzzle, options: .forSize(size)),
               "\(size)x\(size) seed \(seed): shipped a puzzle below the quality bar")
    }

    expect(produced == 25, "\(size)x\(size) produced only \(produced)/25")

    let meanFreebie = freebieShares.reduce(0, +) / Double(max(freebieShares.count, 1))
    let meanCage = cageSizes.reduce(0, +) / Double(max(cageSizes.count, 1))
    expect(meanFreebie <= 0.15,
           "\(size)x\(size) mean freebie share \(Int(meanFreebie * 100))% exceeds 15%")
    expect(meanCage >= 2.0,
           "\(size)x\(size) mean cage size \(meanCage) below 2.0 — cages are fragmenting")

    // No single operator may dominate, or boards read as monotonous.
    let total = opCounts.values.reduce(0, +)
    for op in [Operation.add, .multiply] {
        let share = Double(opCounts[op] ?? 0) / Double(max(total, 1))
        expect(share <= 0.50,
               "\(size)x\(size) \(op.rawValue) is \(Int(share * 100))% of cages — too monotonous")
    }

    FileHandle.standardError.write(
        String(format: "  %dx%d freebies %4.1f%%  avg cage %.2f\n",
               size, size, meanFreebie * 100, meanCage).data(using: .utf8)!
    )
}

// MARK: - 11. Fixtures

section("11. Fixtures are sound boards")

// A fixture that is ambiguous or unsolvable silently weakens every test built
// on it, so re-prove both properties here rather than trusting the diagrams.
for (name, puzzle) in Fixtures.all {
    expect(puzzle.isWellFormed(), "\(name): malformed")
    let solutions = BacktrackingSolver.countSolutions(
        size: puzzle.size, cages: puzzle.cages, limit: 2
    )
    expect(solutions == 1, "\(name): \(solutions) solutions, expected exactly 1")

    let result = LogicalSolver.solve(puzzle)
    expect(result.solved, "\(name): curriculum cannot finish it")
}

// The 5x5 is the soundness board because it uses every core detector. The
// advanced techniques need harder boards and are covered by the generated
// sweep instead.
do {
    let result = LogicalSolver.solve(Fixtures.full5x5)
    let missing = Technique.allCases
        .filter { $0 <= Technique.coreCeiling && result.histogram[$0] == nil }
    expect(missing.isEmpty,
           "full5x5 no longer exercises every core technique; missing "
               + "\(missing.map(\.displayName))")
}

// MARK: - 12. Solver soundness

section("12. Solver soundness")

// The highest-value test in the suite: an unsound detector produces a *wrong*
// hint, which is worse than no hint. This catches one on any board without
// per-technique setup.
func assertSound(_ puzzle: Puzzle, _ label: String) {
    let result = LogicalSolver.solve(puzzle)
    for step in result.trace {
        for placement in step.placements {
            expect(puzzle.solutionValue(at: placement.cell) == placement.digit,
                   "\(label): \(step.technique.displayName) placed \(placement.digit) at "
                       + "\(placement.cell) but the solution is "
                       + "\(puzzle.solutionValue(at: placement.cell))")
        }
        for elimination in step.eliminations {
            let truth = puzzle.solutionValue(at: elimination.cell)
            expect(!DigitSet.contains(elimination.digits, truth),
                   "\(label): \(step.technique.displayName) eliminated the solution digit "
                       + "\(truth) from \(elimination.cell)")
        }
        expect(step.isUseful, "\(label): \(step.technique.displayName) returned a no-op step")
    }
}

for (name, puzzle) in Fixtures.all { assertSound(puzzle, name) }

// And over generated boards, which cover far more shapes than fixtures can.
for size in 4...7 {
    for seed in 0..<12 {
        guard let r = PuzzleGenerator.generate(
            size: size, seed: UInt64(seed &* 811 &+ size)
        ) else { continue }
        assertSound(r.puzzle, "generated \(size)x\(size)/\(seed)")
    }
}

// MARK: - 13. Determinism and dispatch

section("13. Determinism and dispatch")

for (name, puzzle) in Fixtures.all {
    let a = LogicalSolver.solve(puzzle)
    let b = LogicalSolver.solve(puzzle)
    expect(a.trace == b.trace, "\(name): solve is not deterministic")
    expect(a.solved == b.solved, "\(name): solved flag is not deterministic")
}

// Guards the Technique.allCases-driven dispatch: every case must have a
// detector that is at least callable on a real board.
do {
    let puzzle = Fixtures.full5x5
    for technique in Technique.allCases {
        var state = LogicalSolver.State(puzzle: puzzle)
        _ = LogicalSolver.detector(for: technique)(puzzle, &state)
    }
    checks += 1
}

// A solved board has no next step.
do {
    var board = BoardState()
    for cell in Fixtures.tiny3x3.allCells {
        board.entries[cell] = Fixtures.tiny3x3.solutionValue(at: cell)
    }
    expect(LogicalSolver.nextStep(puzzle: Fixtures.tiny3x3, board: board) == nil,
           "solved board still offers a hint")
    expect(board.isSolved(for: Fixtures.tiny3x3), "solved board not recognised as solved")
    expect(board.incorrectCells(for: Fixtures.tiny3x3).isEmpty, "solved board reports errors")
}

// MARK: - 14. Hint loop converges

section("14. Hint loop converges")

// Asserts progress on EVERY round, not just at the end — that is what catches
// a detector returning a step which applies to nothing.
for (name, puzzle) in Fixtures.all {
    var board = BoardState()
    var rounds = 0
    let ceiling = puzzle.size * puzzle.size * 8
    var stalled = false

    while !board.isComplete(for: puzzle) && rounds < ceiling {
        rounds += 1
        guard let step = LogicalSolver.nextStep(puzzle: puzzle, board: board) else { break }
        let before = board

        for placement in step.placements { board.entries[placement.cell] = placement.digit }
        LogicalSolver.applyEliminations(step, to: &board, size: puzzle.size)

        if board == before {
            expect(false, "\(name): \(step.technique.displayName) made no change on round \(rounds)")
            stalled = true
            break
        }
    }

    if !stalled {
        expect(board.isComplete(for: puzzle),
               "\(name): hint loop stopped after \(rounds) rounds without finishing")
        expect(board.isSolved(for: puzzle), "\(name): hint loop finished with a wrong digit")
        expect(rounds < ceiling, "\(name): hint loop hit the round ceiling")
    }
}

// MARK: - 15. Player notes drive the hint

section("15. Player notes drive the hint")

// The mechanism behind "hints never re-teach what you already know": notes seed
// the solver's candidates, and an un-noted cell means "no knowledge" rather
// than "nothing is possible".
do {
    let puzzle = Fixtures.full5x5

    // An empty board must still produce a hint — a cell with no notes keeps the
    // full candidate set. Seeding it with the empty set instead would make the
    // solver believe the board was contradictory.
    expect(LogicalSolver.nextStep(puzzle: puzzle, board: BoardState()) != nil,
           "empty board produced no hint — notes seeding is inverted")

    // Notes narrow the search: pinning a cell to one candidate makes that cell
    // a naked single, which outranks everything below it in the curriculum.
    var board = BoardState()
    let target = Cell(0, 0)
    board.notes[target] = [puzzle.solutionValue(at: target)]
    let step = LogicalSolver.nextStep(puzzle: puzzle, board: board)
    expect(step != nil, "board with a pinned note produced no hint")
    if let step, step.technique == .nakedSingle {
        expect(step.placements.first?.cell == target,
               "naked single fired on the wrong cell")
        expect(step.placements.first?.digit == puzzle.solutionValue(at: target),
               "naked single placed a digit disagreeing with the solution")
    }
}

// Every hint must be reachable: no step may reference a cell outside the grid,
// and every placement must land on an empty cell.
for (name, puzzle) in Fixtures.all {
    let result = LogicalSolver.solve(puzzle)
    for step in result.trace {
        for cell in step.focusCells + step.placements.map(\.cell) + step.eliminations.map(\.cell) {
            expect(cell.row >= 0 && cell.row < puzzle.size
                       && cell.col >= 0 && cell.col < puzzle.size,
                   "\(name): \(step.technique.displayName) referenced out-of-bounds \(cell)")
        }
        for index in step.involvedCages {
            expect(index >= 0 && index < puzzle.cages.count,
                   "\(name): \(step.technique.displayName) referenced cage index \(index)")
        }
    }
}

// MARK: - 16. Difficulty rater shape

section("16. Difficulty rater shape")

// Pin the rater's shape, not its numbers, so recalibration can move thresholds
// without breaking tests.
expect(DifficultyRater.weight(for: .freebieCage) == 0,
       "a freebie is handed to the player and must cost nothing")
expect(DifficultyRater.weight(for: .nakedSingle) < DifficultyRater.weight(for: .hiddenSingle),
       "naked single is the trivial step and must score below hidden single")
expect(DifficultyRater.weight(for: .hiddenSubset) > DifficultyRater.weight(for: .cageCombination),
       "subset work must outrank basic cage enumeration")

do {
    let profile: [Technique: Int] = [.nakedSingle: 3, .hiddenSingle: 2]
    let expected = DifficultyRater.weight(for: .nakedSingle) * 3
        + DifficultyRater.weight(for: .hiddenSingle) * 2
    expect(DifficultyRater.score(profile: profile, solved: true) == expected,
           "score is not the weighted sum")
    expect(DifficultyRater.score(profile: profile, solved: false)
               == expected + DifficultyRater.unsolvedPenalty,
           "unsolved penalty not applied")
    expect(DifficultyRater.score(profile: [:], solved: true) == 0,
           "empty profile should score zero")
}

// Bands must partition scores monotonically at every calibrated boundary.
// Uses a scratch size and restores the table, so this cannot silently
// de-calibrate a real size for the sections that follow.
do {
    // A local table rather than mutating the shared one: a test that mutated
    // global thresholds could silently de-calibrate a real size for every
    // section that ran afterwards.
    let table = [6: [10, 20, 30, 40]]
    let cases: [(Int, Difficulty)] = [
        (0, .gentle), (10, .gentle), (11, .steady), (20, .steady),
        (21, .sharp), (30, .sharp), (31, .deep), (40, .deep), (41, .severe),
    ]
    for (score, band) in cases {
        let got = DifficultyRater.band(forScore: score, size: 6, using: table)
        expect(got == band, "score \(score) banded as \(got), expected \(band)")
    }

    // Uncalibrated sizes must not pretend to a precision we do not have.
    expect(DifficultyRater.band(forScore: 999, size: 6, using: [:]) == .steady,
           "uncalibrated size should fall back to the middle band")
}

// Every shipping size must actually be calibrated, or its puzzles all band
// as Steady and the tier labels become a lie.
for size in 3...9 {
    expect(DifficultyRater.thresholds[size]?.count == 4,
           "size \(size) has no calibrated thresholds — run NUMERIQO_CALIBRATE=1")
    if let bounds = DifficultyRater.thresholds[size] {
        expect(bounds == bounds.sorted(), "size \(size) thresholds are not ascending")
    }
}

// MARK: - 17. Curriculum coverage

section("17. Curriculum coverage")

// The measurement that decides what to build next: which techniques the
// generator actually exercises, and how the tiers spread.
do {
    var usage: [Technique: Int] = [:]
    var hardest: [Technique: Int] = [:]
    var produced = 0

    for size in [5, 6, 7] {
        for seed in 0..<20 {
            guard let r = PuzzleGenerator.generate(
                size: size, seed: UInt64(seed &* 4093 &+ size &* 29)
            ) else { continue }
            produced += 1

            // Solvability gating is the hint guarantee: nothing may ship that
            // the curriculum cannot finish.
            guard let grade = r.grade else {
                expect(false, "\(size)x\(size)/\(seed): shipped without a grade")
                continue
            }
            expect(grade.solved, "\(size)x\(size)/\(seed): shipped an unsolvable puzzle")

            for (t, c) in grade.profile { usage[t, default: 0] += c }
            if let h = grade.hardestTechnique { hardest[h, default: 0] += 1 }
        }
    }

    expect(produced >= 55, "curriculum coverage sampled only \(produced)/60 puzzles")

    let total = usage.values.reduce(0, +)
    for technique in Technique.allCases {
        let count = usage[technique] ?? 0
        FileHandle.standardError.write(
            String(format: "  %-22@ %6d  (%4.1f%%)   tops out in %3d puzzles\n",
                   technique.displayName as NSString, count,
                   Double(count) / Double(max(total, 1)) * 100,
                   hardest[technique] ?? 0).data(using: .utf8)!
        )
    }
}

// MARK: - 18. Reachability

section("18. Reachability")

// Pinned in BOTH directions, so a change in detector precedence fails loudly
// rather than silently stranding a lesson with no way to reach it.
do {
    var usage: [Technique: Int] = [:]
    var tops: [Technique: Int] = [:]
    var solvable = 0, sampled = 0

    // Solvability gating off: we want the raw picture of what the curriculum
    // can crack, not just the puzzles it already accepted.
    for size in 4...9 {
        var options = PuzzleGenerator.Options.forSize(size)
        options.requireLogicallySolvable = false
        for seed in 0..<30 {
            guard let r = PuzzleGenerator.generate(
                size: size, options: options, seed: UInt64(seed &* 7919 &+ size &* 13)
            ) else { continue }
            sampled += 1
            let result = LogicalSolver.solve(r.puzzle)
            if result.solved {
                solvable += 1
                if let h = result.hardestTechnique { tops[h, default: 0] += 1 }
            }
            for (t, c) in result.histogram { usage[t, default: 0] += c }
        }
    }

    expect(sampled >= 170, "reachability sampled only \(sampled) puzzles")

    // The curriculum must crack the large majority of unique puzzles, or the
    // generator throws most of its work away.
    let rate = Double(solvable) / Double(max(sampled, 1))
    expect(rate >= 0.70,
           "curriculum solves only \(Int(rate * 100))% of unique puzzles — too much waste")

    let known = Set(Technique.unreachableInGeneratedPuzzles)
    for technique in Technique.allCases {
        let fired = (usage[technique] ?? 0) > 0
        if known.contains(technique) {
            expect(!fired,
                   "\(technique.displayName) is listed unreachable but fired "
                       + "\(usage[technique] ?? 0) times — it can now be searched for, "
                       + "so its drill no longer needs hand-authoring")
        } else {
            expect(fired,
                   "\(technique.displayName) never fired — either it is redundant or a "
                       + "cheaper detector shadows it. Add it to "
                       + "Technique.unreachableInGeneratedPuzzles and hand-author its drill")
        }
    }

    // The tier ceiling must actually spread, or difficulty labels are
    // decoration. Stage A collapsed with 85% of puzzles topping out at one
    // technique; anything that dominant means the curriculum has no headroom.
    let topTotal = tops.values.reduce(0, +)
    if let (dominant, count) = tops.max(by: { $0.value < $1.value }) {
        let share = Double(count) / Double(max(topTotal, 1))
        expect(share <= 0.55,
               "\(dominant.displayName) is the ceiling for \(Int(share * 100))% of puzzles "
                   + "— the tier system cannot differentiate")
    }

    FileHandle.standardError.write(
        String(format: "  curriculum solves %.1f%% of %d unique puzzles\n",
               rate * 100, sampled).data(using: .utf8)!
    )
    for technique in Technique.allCases {
        FileHandle.standardError.write(
            String(format: "  %-22@ steps %6d   tops out %4d\n",
                   technique.displayName as NSString,
                   usage[technique] ?? 0, tops[technique] ?? 0).data(using: .utf8)!
        )
    }
}

// MARK: - Calibration (NUMERIQO_CALIBRATE=1)

if ProcessInfo.processInfo.environment["NUMERIQO_CALIBRATE"] == "1" {
    section("Calibration — paste into DifficultyRater.thresholds")
    var table: [String] = []
    for size in 3...9 {
        var scores: [Int] = []
        for seed in 0..<60 {
            guard let r = PuzzleGenerator.generate(
                size: size, seed: UInt64(seed &* 2_654_435_761 &+ size)
            ), let grade = r.grade else { continue }
            scores.append(grade.score)
        }
        guard scores.count >= 20 else {
            FileHandle.standardError.write(
                "  \(size)x\(size): only \(scores.count) samples, skipped\n".data(using: .utf8)!)
            continue
        }
        scores.sort()
        func quantile(_ f: Double) -> Int {
            scores[min(scores.count - 1, Int(Double(scores.count) * f))]
        }
        let bounds = [quantile(0.2), quantile(0.4), quantile(0.6), quantile(0.8)]
        table.append("        \(size): \(bounds),")
        FileHandle.standardError.write(
            "  \(size)x\(size) n=\(scores.count): \(bounds) "
                .appending("[min \(scores.first!) max \(scores.last!)]\n").data(using: .utf8)!)
    }
    print("\n    static var thresholds: [Int: [Int]] = [")
    for row in table { print(row) }
    print("    ]")
}

// MARK: - Result

print("\n" + String(repeating: "=", count: 46))
if failures == 0 {
    print("PASS — \(checks) checks, \(comparisons) differential comparisons")
    exit(0)
} else {
    print("FAIL — \(failures) failure(s) across \(checks) checks")
    exit(1)
}
