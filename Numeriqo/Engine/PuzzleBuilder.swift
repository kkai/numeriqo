//
//  PuzzleBuilder.swift
//  Numeriqo
//
//  Builds a Puzzle from an ASCII cage map plus a solution grid, deriving every
//  clue. Hand-typing cage targets in fixtures is unreadable and gets the
//  arithmetic wrong; here the solution is the source of truth and the clues
//  cannot disagree with it.
//
//      PuzzleBuilder.puzzle(
//          cageMap: ["AAB",
//                    "CAB",
//                    "CCB"],
//          solution: [[1, 2, 3],
//                     [2, 3, 1],
//                     [3, 1, 2]],
//          operations: ["A": .add, "B": .multiply, "C": .subtract])
//
//  Used by test fixtures and, later, by hand-authored tutorial and practice
//  boards.
//

import Foundation

nonisolated enum PuzzleBuilder {

    enum BuildError: Error, CustomStringConvertible {
        case emptyMap
        case ragged
        case sizeMismatch
        case notALatinSquare
        case disconnectedCage(Character)
        case badOperation(Character, String)

        var description: String {
            switch self {
            case .emptyMap: "cage map is empty"
            case .ragged: "cage map rows differ in length"
            case .sizeMismatch: "cage map and solution differ in size"
            case .notALatinSquare: "solution is not a Latin square"
            case .disconnectedCage(let c): "cage '\(c)' is not orthogonally connected"
            case .badOperation(let c, let why): "cage '\(c)': \(why)"
            }
        }
    }

    /// Throwing variant, for use where a malformed fixture should be diagnosed
    /// rather than trapped.
    static func makePuzzle(
        cageMap: [String],
        solution: [[Int]],
        operations: [Character: Operation] = [:]
    ) throws -> Puzzle {
        guard let first = cageMap.first, !first.isEmpty else { throw BuildError.emptyMap }
        let size = cageMap.count
        guard cageMap.allSatisfy({ $0.count == size }) else { throw BuildError.ragged }
        guard solution.count == size, solution.allSatisfy({ $0.count == size })
        else { throw BuildError.sizeMismatch }
        guard LatinSquare.isValid(solution, size: size) else { throw BuildError.notALatinSquare }

        // Group cells by cage label, preserving reading order.
        var groups: [Character: [Cell]] = [:]
        var order: [Character] = []
        for (r, row) in cageMap.enumerated() {
            for (c, label) in Array(row).enumerated() {
                if groups[label] == nil { order.append(label) }
                groups[label, default: []].append(Cell(r, c))
            }
        }

        var cages: [Cage] = []
        cages.reserveCapacity(order.count)

        for label in order {
            let cells = groups[label]!.sorted()
            let probe = Cage(cells: cells, operation: .add, target: 1)
            guard probe.isOrthogonallyConnected else { throw BuildError.disconnectedCage(label) }

            let digits = cells.map { solution[$0.row][$0.col] }
            let requested = operations[label]
            let (operation, target) = try derive(
                operation: requested, digits: digits, size: size, label: label
            )
            cages.append(Cage(cells: cells, operation: operation, target: target))
        }

        return Puzzle(size: size, cages: cages, solution: solution)
    }

    /// Trapping variant for fixtures, where a malformed board is a programming
    /// error and should fail loudly at the point of definition.
    static func puzzle(
        cageMap: [String],
        solution: [[Int]],
        operations: [Character: Operation] = [:]
    ) -> Puzzle {
        do {
            return try makePuzzle(cageMap: cageMap, solution: solution, operations: operations)
        } catch {
            preconditionFailure("PuzzleBuilder: \(error)")
        }
    }

    /// Resolves the clue for one cage. When no operation is requested, picks the
    /// most constraining legal one — fixtures usually want the tightest clue so
    /// the technique under test is the natural way in.
    private static func derive(
        operation requested: Operation?,
        digits: [Int],
        size: Int,
        label: Character
    ) throws -> (Operation, Int) {
        if digits.count == 1 {
            if let requested, requested != .none {
                throw BuildError.badOperation(label, "single-cell cages take no operation")
            }
            return (.none, digits[0])
        }

        guard let requested else {
            // No preference: take the tightest legal clue, so the technique a
            // fixture is exercising stays the natural way into the board.
            // Division and subtraction are the most constraining two-cell
            // clues, then multiplication, then addition.
            let hi = digits.max()!, lo = digits.min()!
            var options: [(Operation, Int)] = [
                (.add, digits.reduce(0, +)),
                (.multiply, digits.reduce(1, *)),
            ]
            if digits.count == 2 {
                if hi - lo > 0 { options.append((.subtract, hi - lo)) }
                if lo > 0, hi % lo == 0, hi / lo > 1 { options.append((.divide, hi / lo)) }
            }
            for op in [Operation.divide, .subtract, .multiply, .add] {
                if let hit = options.first(where: { $0.0 == op }) { return hit }
            }
            return options[0]
        }

        switch requested {
        case .none:
            throw BuildError.badOperation(label, "multi-cell cage cannot use .none")
        case .add:
            return (.add, digits.reduce(0, +))
        case .multiply:
            return (.multiply, digits.reduce(1, *))
        case .subtract:
            guard digits.count == 2 else {
                throw BuildError.badOperation(label, "subtraction needs exactly two cells")
            }
            let target = abs(digits[0] - digits[1])
            guard target > 0 else {
                throw BuildError.badOperation(label, "subtraction target 0 implies a repeat")
            }
            return (.subtract, target)
        case .divide:
            guard digits.count == 2 else {
                throw BuildError.badOperation(label, "division needs exactly two cells")
            }
            let hi = max(digits[0], digits[1]), lo = min(digits[0], digits[1])
            guard lo > 0, hi % lo == 0 else {
                throw BuildError.badOperation(label, "\(hi) is not divisible by \(lo)")
            }
            let target = hi / lo
            guard target > 1 else {
                throw BuildError.badOperation(label, "division target 1 implies a repeat")
            }
            return (.divide, target)
        }
    }
}
