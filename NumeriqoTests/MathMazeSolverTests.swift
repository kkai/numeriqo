//
//  MathMazeSolverTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

private func cage(_ op: Operation, _ target: Int, _ cells: (Int, Int)...) -> SolverCage {
    SolverCage(
        positions: cells.map { Position(row: $0.0, col: $0.1) },
        operation: op,
        target: target
    )
}

/// A hand-verified 3×3 puzzle with exactly one solution:
///   1 2 3
///   2 3 1
///   3 1 2
private let uniquePuzzleCages: [SolverCage] = [
    cage(.add, 3, (0, 0), (0, 1)),
    cage(.multiply, 3, (0, 2), (1, 2)),
    cage(.subtract, 1, (1, 0), (1, 1)),
    cage(.none, 3, (2, 0)),
    cage(.add, 3, (2, 1), (2, 2)),
]

private let uniquePuzzleSolution = [
    [1, 2, 3],
    [2, 3, 1],
    [3, 1, 2],
]

struct MathMazeSolverTests {

    @Test func uniquePuzzleHasExactlyOneSolution() {
        #expect(MathMazeSolver.countSolutions(size: 3, cages: uniquePuzzleCages) == 1)
        #expect(MathMazeSolver.solve(size: 3, cages: uniquePuzzleCages) == uniquePuzzleSolution)
    }

    @Test func rowSumCagesAdmitAllLatinSquares() {
        // Each row of any 3×3 Latin square sums to 6, so these cages
        // constrain nothing beyond the Latin square rules.
        let cages = [
            cage(.add, 6, (0, 0), (0, 1), (0, 2)),
            cage(.add, 6, (1, 0), (1, 1), (1, 2)),
            cage(.add, 6, (2, 0), (2, 1), (2, 2)),
        ]
        #expect(MathMazeSolver.countSolutions(size: 3, cages: cages, limit: 2) == 2)
        // There are exactly 12 Latin squares of order 3.
        #expect(MathMazeSolver.countSolutions(size: 3, cages: cages, limit: 100) == 12)
    }

    @Test func impossibleSingleCellCageIsUnsolvable() {
        let cages = [cage(.none, 5, (0, 0))]
        #expect(MathMazeSolver.countSolutions(size: 3, cages: cages) == 0)
        #expect(MathMazeSolver.solve(size: 3, cages: cages) == nil)
    }

    @Test func consistentPartialCompletesToUniqueSolution() {
        let partial: [[Int?]] = [
            [1, nil, nil],
            [nil, nil, nil],
            [nil, nil, nil],
        ]
        let solved = MathMazeSolver.solve(size: 3, cages: uniquePuzzleCages, partial: partial)
        #expect(solved == uniquePuzzleSolution)
    }

    @Test func contradictoryPartialHasNoSolution() {
        // The unique solution has 1 at (0,0); forcing 2 there is a dead end.
        let wrongValue: [[Int?]] = [
            [2, nil, nil],
            [nil, nil, nil],
            [nil, nil, nil],
        ]
        #expect(MathMazeSolver.solve(size: 3, cages: uniquePuzzleCages, partial: wrongValue) == nil)

        // A duplicate within a row is rejected outright.
        let duplicateInRow: [[Int?]] = [
            [1, 1, nil],
            [nil, nil, nil],
            [nil, nil, nil],
        ]
        #expect(MathMazeSolver.solve(size: 3, cages: uniquePuzzleCages, partial: duplicateInRow) == nil)
    }

    @Test func divideCageUsesTruncatingDivisionLikeOperationCalculate() {
        // Row 0 must be {2,3} in the divide cage plus a pinned 1.
        // Operation.calculate gives 3/2 == 1 (truncating), so target 1 is
        // satisfiable; an exact-division solver would wrongly find 0 solutions.
        let cages = [
            cage(.divide, 1, (0, 0), (0, 1)),
            cage(.none, 1, (0, 2)),
        ]
        // 2 orders for {2,3} × 2 Latin completions of the remaining rows.
        #expect(MathMazeSolver.countSolutions(size: 3, cages: cages, limit: 100) == 4)
    }

    @Test func subtractCageIsOrderIndependent() {
        // {1,3} in either order satisfies |a-b| == 2.
        let cages = [
            cage(.subtract, 2, (0, 0), (0, 1)),
            cage(.none, 2, (0, 2)),
        ]
        let solutions = MathMazeSolver.solutions(size: 3, cages: cages, limit: 100)
        #expect(solutions.count == 4)
        let firstCellValues = Set(solutions.map { $0[0][0] })
        #expect(firstCellValues == [1, 3])
    }

    @Test func statsReportPropagationWithoutGuessing() {
        // With the first two rows given, every remaining cell is forced by
        // its column, so the solver needs zero guesses.
        let partial: [[Int?]] = [
            [1, 2, 3],
            [2, 3, 1],
            [nil, nil, nil],
        ]
        let (solution, stats) = MathMazeSolver.solveWithStats(size: 3, cages: uniquePuzzleCages, partial: partial)
        #expect(solution == uniquePuzzleSolution)
        #expect(stats.guessCount == 0)
        #expect(stats.propagationSolvedCells == 3)
    }

    @Test func gridOfSingleCellCagesSolvesByPropagationAlone() {
        var cages: [SolverCage] = []
        for row in 0..<3 {
            for col in 0..<3 {
                cages.append(cage(.none, uniquePuzzleSolution[row][col], (row, col)))
            }
        }
        let (solution, stats) = MathMazeSolver.solveWithStats(size: 3, cages: cages)
        #expect(solution == uniquePuzzleSolution)
        #expect(stats.guessCount == 0)
        #expect(stats.propagationSolvedCells == 9)
    }
}
