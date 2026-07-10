//
//  PuzzleGenerationTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

struct PuzzleGenerationTests {

    @Test(arguments: 3...9)
    func generatedPuzzlesAreWellFormedAndUnique(size: Int) {
        for _ in 0..<10 {
            let puzzle = MathMazeGame.generatePuzzle(size: size)

            // Cages exactly partition the grid.
            var covered: Set<Position> = []
            var cellCount = 0
            for cage in puzzle.cages {
                cellCount += cage.positions.count
                covered.formUnion(cage.positions)
            }
            #expect(cellCount == size * size, "cages overlap or double-cover cells")
            #expect(covered.count == size * size, "cages do not cover the grid")

            for cage in puzzle.cages {
                // Every cage is 4-adjacency connected.
                #expect(isConnected(cage.positions), "cage \(cage.positions) is disconnected")

                // Operation arity rules.
                switch cage.operation {
                case .none:
                    #expect(cage.positions.count == 1)
                case .subtract, .divide:
                    #expect(cage.positions.count == 2)
                case .add, .multiply:
                    #expect(cage.positions.count >= 2)
                }

                // Every cage validates against the seed solution.
                let seedValues = cage.positions.map { puzzle.solution[$0.row][$0.col] }
                #expect(cage.operation.calculate(seedValues) == cage.target)
            }

            // The headline invariant: exactly one solution, and it is the seed.
            let solutions = MathMazeSolver.solutions(
                size: size,
                cages: puzzle.cages.map(\.solverCage),
                limit: 2
            )
            #expect(solutions.count == 1, "puzzle does not have a unique solution")
            #expect(solutions.first == puzzle.solution)
        }
    }

    @Test func isValidSolutionAcceptsSeedAndRejectsMutations() {
        let game = MathMazeGame(size: 4)

        // Fill the grid with the seed solution directly (setValue would
        // trigger completion handling and best-time persistence).
        game.grid = game.solution.map { row in row.map { Optional($0) } }
        #expect(game.isValidSolution())

        // Swapping two values within a row breaks the column constraint.
        game.grid = game.solution.map { row in row.map { Optional($0) } }
        game.grid[0].swapAt(0, 1)
        #expect(!game.isValidSolution())

        // Changing a single cell breaks its row/column or cage.
        game.grid = game.solution.map { row in row.map { Optional($0) } }
        let original = game.solution[2][2]
        game.grid[2][2] = original == 4 ? 1 : original + 1
        #expect(!game.isValidSolution())
    }

    private func isConnected(_ positions: Set<Position>) -> Bool {
        guard let start = positions.first else { return false }
        var visited: Set<Position> = [start]
        var queue = [start]
        while let pos = queue.popLast() {
            let neighbors = [
                Position(row: pos.row + 1, col: pos.col),
                Position(row: pos.row - 1, col: pos.col),
                Position(row: pos.row, col: pos.col + 1),
                Position(row: pos.row, col: pos.col - 1),
            ]
            for neighbor in neighbors where positions.contains(neighbor) && !visited.contains(neighbor) {
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }
        return visited.count == positions.count
    }
}
