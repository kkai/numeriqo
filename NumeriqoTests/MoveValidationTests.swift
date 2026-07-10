//
//  MoveValidationTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

private func makeCage(_ op: Operation, _ target: Int, _ cells: [(Int, Int)], color: Int = 0) -> Cage {
    Cage(
        positions: Set(cells.map { Position(row: $0.0, col: $0.1) }),
        operation: op,
        target: target,
        colorID: CageColorID.fromIndex(color)
    )
}

/// 3×3 fixture with solution [[3,2,1],[1,3,2],[2,1,3]]: a pinned single-cell
/// cage at (0,2) plus permissive row-sum cages.
private func rowDeadEndGame() -> MathMazeGame {
    let solution = [[3, 2, 1], [1, 3, 2], [2, 1, 3]]
    let cages = [
        makeCage(.add, 5, [(0, 0), (0, 1)], color: 0),
        makeCage(.none, 1, [(0, 2)], color: 1),
        makeCage(.add, 6, [(1, 0), (1, 1), (1, 2)], color: 2),
        makeCage(.add, 6, [(2, 0), (2, 1), (2, 2)], color: 3),
    ]
    return MathMazeGame(puzzle: GeneratedPuzzle(size: 3, solution: solution, cages: cages))
}

struct MoveValidationTests {

    @Test func rejectsMoveThatStarvesSingleCellCageInSameRow() {
        let game = rowDeadEndGame()
        // Placing 1 at (0,0) leaves the ".none 1" cage at (0,2) unfillable —
        // the old heuristics accepted this dead end.
        #expect(!game.isValidMove(1, at: Position(row: 0, col: 0)))
        // Sanity: the seed digit is accepted.
        #expect(game.isValidMove(3, at: Position(row: 0, col: 0)))
    }

    @Test func rejectsMoveThatStarvesSingleCellCageInSameColumn() {
        // Solution [[3,2,1],[1,3,2],[2,1,3]] with the pin at (2,0) = 2.
        let solution = [[3, 2, 1], [1, 3, 2], [2, 1, 3]]
        let cages = [
            makeCage(.add, 6, [(0, 0), (0, 1), (0, 2)], color: 0),
            makeCage(.add, 6, [(1, 0), (1, 1), (1, 2)], color: 1),
            makeCage(.none, 2, [(2, 0)], color: 2),
            makeCage(.add, 4, [(2, 1), (2, 2)], color: 3),
        ]
        let game = MathMazeGame(puzzle: GeneratedPuzzle(size: 3, solution: solution, cages: cages))
        // 2 at (0,0) uses up column 0's only 2 above the pinned cage.
        #expect(!game.isValidMove(2, at: Position(row: 0, col: 0)))
        #expect(game.isValidMove(3, at: Position(row: 0, col: 0)))
    }

    @Test(arguments: 3...9)
    func neverRejectsTheSeedSolution(size: Int) {
        let game = MathMazeGame(puzzle: MathMazeGame.generatePuzzle(size: size))
        var positions = (0..<size).flatMap { row in
            (0..<size).map { Position(row: row, col: $0) }
        }
        positions.shuffle()
        for position in positions {
            let seedValue = game.solution[position.row][position.col]
            #expect(game.isValidMove(seedValue, at: position),
                    "seed digit \(seedValue) rejected at \(position)")
            // Write directly so checkCompletion (and best-time persistence)
            // is not triggered on the final cell.
            game.grid[position.row][position.col] = seedValue
        }
    }

    @Test func rejectsCompletingCageWithWrongArithmetic() {
        let game = rowDeadEndGame()
        // (0,0)+(0,1) must sum to 5. Start with a legal 3...
        game.grid[0][0] = 3
        // ...then 1 completes the cage to 4 ≠ 5 (and 1 is row-legal here).
        #expect(!game.isValidMove(1, at: Position(row: 0, col: 1)))
        #expect(game.isValidMove(2, at: Position(row: 0, col: 1)))
    }

    @Test func stillRejectsRowAndColumnDuplicates() {
        let game = rowDeadEndGame()
        game.grid[0][0] = 3
        #expect(!game.isValidMove(3, at: Position(row: 0, col: 1)))  // row dup
        #expect(!game.isValidMove(3, at: Position(row: 2, col: 0)))  // col dup
    }

    @Test(arguments: [4, 5, 6])
    func doesNotLeakTheSolutionThroughEnabledDigits(size: Int) {
        // On an empty grid, cells in multi-cell cages must generally keep
        // several digits enabled; only single-cell cages may pin one digit.
        // Measured baselines (empty grid, 40 puzzles/size): mean enabled
        // 1.83 / 2.35 / 2.82 and >=2-digit share 63% / 78% / 85% for sizes
        // 4 / 5 / 6 — small grids are legitimately pinned by uniqueness
        // repair. Thresholds sit well below baseline; a full-solve leak
        // would pin ~100% of cells and trip all of them.
        let minMean: [Int: Double] = [4: 1.4, 5: 1.8, 6: 2.2]
        let minMultiShare: [Int: Double] = [4: 0.45, 5: 0.60, 6: 0.70]

        var enabledCounts: [Int] = []
        for _ in 0..<10 {
            let game = MathMazeGame(puzzle: MathMazeGame.generatePuzzle(size: size))
            for row in 0..<size {
                for col in 0..<size {
                    let position = Position(row: row, col: col)
                    guard let cage = game.getCage(for: position), cage.positions.count > 1 else { continue }
                    let enabled = (1...size).filter { game.isValidMove($0, at: position) }.count
                    enabledCounts.append(enabled)
                }
            }
        }
        let mean = Double(enabledCounts.reduce(0, +)) / Double(enabledCounts.count)
        let multiShare = Double(enabledCounts.filter { $0 >= 2 }.count) / Double(enabledCounts.count)
        #expect(mean >= minMean[size]!,
                "mean enabled digits \(mean) below floor — validation may be leaking the solution")
        #expect(multiShare >= minMultiShare[size]!,
                "share of cells with >=2 enabled digits \(multiShare) below floor")
    }

    @Test func filledCellSelfQueryStaysValid() {
        let game = rowDeadEndGame()
        game.grid[0][0] = 3
        // The grid error-coloring path re-validates a cell's own value.
        #expect(game.isValidMove(3, at: Position(row: 0, col: 0)))
    }

    @Test func cacheInvalidatesOnDirectGridAssignment() {
        let game = rowDeadEndGame()
        let probe = Position(row: 1, col: 0)
        #expect(game.isValidMove(1, at: probe))  // cached as valid
        // Kill the ".none 1" cage at (0,2) via column 2 — no row/col conflict
        // with the probe, so only a stale cache could still say valid.
        game.grid[2][2] = 1
        #expect(!game.isValidMove(1, at: probe))
    }
}
