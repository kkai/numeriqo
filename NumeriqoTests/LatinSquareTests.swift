//
//  LatinSquareTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

struct LatinSquareTests {

    @Test(arguments: 3...9)
    func rowsAndColumnsArePermutations(size: Int) {
        for _ in 0..<10 {
            let square = MathMazeGame.generateLatinSquare(size: size)
            #expect(square.count == size)
            let expected = Set(1...size)
            for i in 0..<size {
                #expect(Set(square[i]) == expected, "row \(i) is not a permutation")
                let column = (0..<size).map { square[$0][i] }
                #expect(Set(column) == expected, "column \(i) is not a permutation")
            }
        }
    }

    @Test func generatorReachesNonCyclicSquares() {
        // The old generator produced only squares where every row is a cyclic
        // shift of every other. With true randomization at size 6, the chance
        // that 20 consecutive squares are all fully cyclic is negligible.
        func isFullyCyclic(_ square: [[Int]]) -> Bool {
            let size = square.count
            let first = square[0]
            for row in square.dropFirst() {
                var matchesSomeShift = false
                for shift in 0..<size {
                    if (0..<size).allSatisfy({ row[$0] == first[($0 + shift) % size] }) {
                        matchesSomeShift = true
                        break
                    }
                }
                if !matchesSomeShift { return false }
            }
            return true
        }

        let squares = (0..<20).map { _ in MathMazeGame.generateLatinSquare(size: 6) }
        #expect(squares.contains { !isFullyCyclic($0) })
    }
}
