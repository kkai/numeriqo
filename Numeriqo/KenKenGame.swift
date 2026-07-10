//
//  MathMazeGame.swift
//  gengen
//
//  Created by kai on 27.07.25.
//

import Foundation
import SwiftUI

struct Position: Hashable, Equatable {
    let row: Int
    let col: Int
}

enum Operation: String, CaseIterable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"
    case none = ""
    
    func calculate(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        
        switch self {
        case .add:
            return values.reduce(0, +)
        case .subtract:
            guard values.count == 2 else { return nil }
            return abs(values[0] - values[1])
        case .multiply:
            return values.reduce(1, *)
        case .divide:
            guard values.count == 2 else { return nil }
            let sorted = values.sorted(by: >)
            return sorted[1] != 0 ? sorted[0] / sorted[1] : nil
        case .none:
            return values.first
        }
    }
}

/// A fully generated puzzle: seed solution plus a cage set with exactly one solution.
struct GeneratedPuzzle {
    let size: Int
    let solution: [[Int]]
    let cages: [Cage]
    /// The tier this puzzle is presented as (the requested tier when
    /// generated via generatePuzzle(size:difficulty:)).
    let difficulty: Difficulty
    /// The raw DifficultyRater score, kept for debugging and calibration.
    let score: Double

    init(size: Int, solution: [[Int]], cages: [Cage], difficulty: Difficulty = .medium, score: Double = 0) {
        self.size = size
        self.solution = solution
        self.cages = cages
        self.difficulty = difficulty
        self.score = score
    }
}

struct Cage: Identifiable, Hashable {
    let id = UUID()
    let positions: Set<Position>
    let operation: Operation
    let target: Int
    let colorID: CageColorID

    var solverCage: SolverCage {
        SolverCage(positions: Array(positions), operation: operation, target: target)
    }

    var color: Color {
        colorID.adaptiveColor
    }
    
    func contains(position: Position) -> Bool {
        positions.contains(position)
    }
    
    func isValid(with grid: [[Int?]]) -> Bool {
        let values: [Int] = positions.compactMap { pos in
            guard pos.row < grid.count && pos.col < grid[pos.row].count else { return nil }
            return grid[pos.row][pos.col]
        }
        
        guard values.count == positions.count else { return false }
        
        return operation.calculate(values) == target
    }
}

class MathMazeGame: ObservableObject {
    @Published var grid: [[Int?]] {
        didSet { moveCache.removeAll(keepingCapacity: true) }
    }
    @Published var cages: [Cage]
    @Published var isCompleted: Bool = false
    @Published var selectedPosition: Position?
    @Published var elapsedTime: TimeInterval = 0
    @Published var startTime: Date?
    
    let size: Int
    let difficulty: Difficulty
    let solution: [[Int]]
    private var timer: Timer?
    private var accumulatedTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var isTimerRunning: Bool = false

    /// Shares one tuple enumeration across the many isValidMove calls the UI
    /// makes per render; cages never change after init.
    private lazy var validationContext = MathMazeSolver.ValidationContext(
        size: size,
        cages: cages.map(\.solverCage)
    )
    /// Memoized isValidMove results, keyed by (cell, value); cleared whenever
    /// the grid changes.
    private var moveCache: [Int: Bool] = [:]

    convenience init(size: Int, difficulty: Difficulty = .medium) {
        self.init(puzzle: MathMazeGame.generatePuzzle(size: size, difficulty: difficulty))
    }

    init(puzzle: GeneratedPuzzle) {
        self.size = puzzle.size
        self.difficulty = puzzle.difficulty
        self.grid = Array(repeating: Array(repeating: nil, count: puzzle.size), count: puzzle.size)
        self.solution = puzzle.solution
        self.cages = puzzle.cages
        startTimer()
    }
    
    deinit {
        stopTimer()
    }
    
    func setValue(_ value: Int?, at position: Position) {
        guard position.row < size && position.col < size else { return }
        grid[position.row][position.col] = value
        checkCompletion()
    }
    
    func getValue(at position: Position) -> Int? {
        guard position.row < size && position.col < size else { return nil }
        return grid[position.row][position.col]
    }
    
    func getCage(for position: Position) -> Cage? {
        return cages.first { $0.contains(position: position) }
    }
    
    func isValidMove(_ value: Int, at position: Position) -> Bool {
        var tempGrid = grid
        tempGrid[position.row][position.col] = value

        // Check row constraint
        let row = tempGrid[position.row]
        let rowValues = row.compactMap { $0 }
        if Set(rowValues).count != rowValues.count {
            return false
        }

        // Check column constraint
        let colValues = (0..<size).compactMap { tempGrid[$0][position.col] }
        if Set(colValues).count != colValues.count {
            return false
        }

        // Exact cage feasibility across the whole board (single propagation
        // pass — deliberately no stronger, or the pad would leak the unique
        // solution).
        let key = (position.row * size + position.col) * (size + 1) + value
        if let cached = moveCache[key] {
            return cached
        }
        let result = validationContext?.isLocallyConsistent(partial: tempGrid) ?? true
        moveCache[key] = result
        return result
    }
    
    private func checkCompletion() {
        // Check if grid is full
        for row in grid {
            for cell in row {
                if cell == nil { return }
            }
        }
        
        // Check all constraints
        if isValidSolution() {
            isCompleted = true
            stopTimer()
            // Save best time if applicable
            if let completionTime = elapsedTime as TimeInterval? {
                BestTimesManager.shared.updateBestTime(for: size, difficulty: difficulty, time: completionTime)
            }
        }
    }
    
    private func startTimer() {
        startTime = Date()
        sessionStartTime = Date()
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let sessionStart = self.sessionStartTime else { return }
            self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(sessionStart)
        }
    }
    
    private func stopTimer() {
        if isTimerRunning, let sessionStart = sessionStartTime {
            accumulatedTime += Date().timeIntervalSince(sessionStart)
        }
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        sessionStartTime = nil
    }
    
    func pauseTimer() {
        guard isTimerRunning else { return }
        
        if let sessionStart = sessionStartTime {
            accumulatedTime += Date().timeIntervalSince(sessionStart)
        }
        
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        sessionStartTime = nil
    }
    
    func resumeTimer() {
        guard !isTimerRunning && !isCompleted else { return }
        
        sessionStartTime = Date()
        isTimerRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let sessionStart = self.sessionStartTime else { return }
            self.elapsedTime = self.accumulatedTime + Date().timeIntervalSince(sessionStart)
        }
    }
    
    func isValidSolution() -> Bool {
        // Check row and column constraints
        for i in 0..<size {
            let row = grid[i].compactMap { $0 }
            let col = (0..<size).compactMap { grid[$0][i] }
            
            if Set(row).count != size || Set(col).count != size {
                return false
            }
            
            if Set(row) != Set(1...size) || Set(col) != Set(1...size) {
                return false
            }
        }
        
        // Check cage constraints
        for cage in cages {
            if !cage.isValid(with: grid) {
                return false
            }
        }
        
        return true
    }
    
    /// Generates a puzzle in the requested difficulty band: retries natural
    /// generation until the solver-derived score lands in the band, falling
    /// back to the nearest miss so a puzzle is always returned. Fallback
    /// puzzles are still labeled with the requested tier (mismatches are
    /// rare and land in an adjacent band).
    static func generatePuzzle(size: Int, difficulty: Difficulty) -> GeneratedPuzzle {
        let maxAttempts = size <= 6 ? 20 : 12
        var best: GeneratedPuzzle?
        var bestDistance = Double.infinity

        for _ in 0..<maxAttempts {
            let candidate = generatePuzzle(size: size)
            if candidate.difficulty == difficulty {
                return candidate
            }
            let distance = bandDistance(score: candidate.score, target: difficulty, size: size)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }

        let fallback = best!
        #if DEBUG
        print("[MathMaze] size \(size): no \(difficulty.rawValue) puzzle in \(maxAttempts) attempts; using nearest (score \(fallback.score), rated \(fallback.difficulty.rawValue))")
        #endif
        return GeneratedPuzzle(size: size, solution: fallback.solution, cages: fallback.cages,
                               difficulty: difficulty, score: fallback.score)
    }

    /// Distance from a score to the target band's interval (0 when inside).
    private static func bandDistance(score: Double, target: Difficulty, size: Int) -> Double {
        guard let t = DifficultyRater.thresholds[size] else { return 0 }
        switch target {
        case .easy: return max(0, score - t.easyMax)
        case .medium: return max(t.easyMax - score, score - t.mediumMax, 0)
        case .hard: return max(0, t.mediumMax - score)
        }
    }

    /// Generates a puzzle with a verified unique solution: grows random cages
    /// over a random Latin square, then repairs the cage set (constraining
    /// operations or splitting cages) until the solver proves exactly one
    /// solution exists. The result carries its natural (rated) difficulty.
    static func generatePuzzle(size: Int) -> GeneratedPuzzle {
        let maxRepairsPerSquare = 10
        let maxRegenerations = 20
        var regenerationCount = 0
        var repairCount = 0

        for _ in 0..<maxRegenerations {
            let solution = generateLatinSquare(size: size)
            var cages = growCages(solution: solution, size: size)

            for _ in 0...maxRepairsPerSquare {
                let found = MathMazeSolver.solutions(
                    size: size,
                    cages: cages.map(\.solverCage),
                    limit: 2
                )
                if found.count == 1 {
                    #if DEBUG
                    assert(found[0] == solution, "Unique solution does not match the seed solution")
                    assert(cages.reduce(0) { $0 + $1.positions.count } == size * size,
                           "Cages do not partition the grid")
                    if repairCount > 0 || regenerationCount > 0 {
                        print("[MathMaze] size \(size): \(repairCount) repairs, \(regenerationCount) regenerations")
                    }
                    #endif
                    let finalCages = recolored(cages)
                    let score = DifficultyRater.score(size: size, cages: finalCages.map(\.solverCage)) ?? 0
                    return GeneratedPuzzle(size: size, solution: solution, cages: finalCages,
                                           difficulty: DifficultyRater.band(forScore: score, size: size),
                                           score: score)
                }
                // Zero solutions would mean the seed itself no longer fits —
                // a generation bug; bail to a fresh square.
                guard let alternate = found.first(where: { $0 != solution }) else { break }
                cages = repair(cages: cages, seed: solution, alternate: alternate, size: size)
                repairCount += 1
            }
            regenerationCount += 1
        }
        fatalError("Puzzle generation failed to converge for size \(size)")
    }

    /// Grows random 1–4-cell cages until they cover the grid, with operations
    /// and targets derived from the seed solution.
    static func growCages(solution: [[Int]], size: Int) -> [Cage] {
        var usedPositions: Set<Position> = []
        var generatedCages: [Cage] = []

        var colorIndex = 0

        while usedPositions.count < size * size {
            let availablePositions = (0..<size).flatMap { row in
                (0..<size).compactMap { col in
                    let pos = Position(row: row, col: col)
                    return usedPositions.contains(pos) ? nil : pos
                }
            }

            guard let startPos = availablePositions.randomElement() else { break }

            let cageSize = Int.random(in: 1...min(4, availablePositions.count))
            var cagePositions: Set<Position> = [startPos]
            usedPositions.insert(startPos)

            // Try to add adjacent positions to form a cage
            for _ in 1..<cageSize {
                let candidates = cagePositions.flatMap { pos in
                    getAdjacentPositions(pos, size: size).filter { !usedPositions.contains($0) }
                }

                if let nextPos = candidates.randomElement() {
                    cagePositions.insert(nextPos)
                    usedPositions.insert(nextPos)
                }
            }

            // Calculate target value and operation
            let values = cagePositions.map { solution[$0.row][$0.col] }
            let (operation, target) = calculateOperationAndTarget(for: values)

            let cage = Cage(
                positions: cagePositions,
                operation: operation,
                target: target,
                colorID: CageColorID.fromIndex(colorIndex)
            )

            generatedCages.append(cage)
            colorIndex += 1
        }

        return generatedCages
    }

    /// Makes the cage set more constraining at a cell where `alternate`
    /// diverges from `seed`, so the alternate solution no longer fits.
    private static func repair(cages: [Cage], seed: [[Int]], alternate: [[Int]], size: Int) -> [Cage] {
        var differingCells: [Position] = []
        for row in 0..<size {
            for col in 0..<size where alternate[row][col] != seed[row][col] {
                differingCells.append(Position(row: row, col: col))
            }
        }

        // A single-cell cage pins its value, so among differing cells there is
        // always one covered by a multi-cell cage.
        guard let cell = differingCells.shuffled().first(where: { pos in
            cages.first { $0.contains(position: pos) }.map { $0.positions.count > 1 } ?? false
        }), let cageIndex = cages.firstIndex(where: { $0.contains(position: cell) }) else {
            return cages
        }

        let cage = cages[cageIndex]
        var newCages = cages
        newCages.remove(at: cageIndex)

        if cage.positions.count == 2 && (cage.operation == .add || cage.operation == .multiply) {
            // Swap in a more constraining operation on the same two cells.
            let values = cage.positions.map { seed[$0.row][$0.col] }
            let high = max(values[0], values[1])
            let low = min(values[0], values[1])
            var options: [(Operation, Int)] = [(.subtract, high - low)]
            if low != 0 && high % low == 0 {
                options.append((.divide, high / low))
            }
            let (operation, target) = options.randomElement()!
            newCages.append(Cage(positions: cage.positions, operation: operation,
                                 target: target, colorID: cage.colorID))
        } else {
            // Split: pin the differing cell to the seed value (guaranteed to
            // eliminate this alternate), and re-form what's left of the cage
            // into connected cages.
            newCages.append(Cage(positions: [cell], operation: .none,
                                 target: seed[cell.row][cell.col], colorID: cage.colorID))
            var remaining = cage.positions
            remaining.remove(cell)
            for component in connectedComponents(of: remaining, size: size) {
                let values = component.map { seed[$0.row][$0.col] }
                let (operation, target) = calculateOperationAndTarget(for: values)
                newCages.append(Cage(positions: component, operation: operation,
                                     target: target, colorID: cage.colorID))
            }
        }
        return newCages
    }

    private static func connectedComponents(of positions: Set<Position>, size: Int) -> [Set<Position>] {
        var remaining = positions
        var components: [Set<Position>] = []
        while let start = remaining.first {
            var component: Set<Position> = [start]
            var queue = [start]
            remaining.remove(start)
            while let pos = queue.popLast() {
                for adjacent in getAdjacentPositions(pos, size: size) where remaining.contains(adjacent) {
                    remaining.remove(adjacent)
                    component.insert(adjacent)
                    queue.append(adjacent)
                }
            }
            components.append(component)
        }
        return components
    }

    /// Reassigns cage colors sequentially — repairs can split cages, so
    /// renumbering afterwards keeps neighboring colors distinct.
    private static func recolored(_ cages: [Cage]) -> [Cage] {
        cages.enumerated().map { index, cage in
            Cage(positions: cage.positions, operation: cage.operation,
                 target: cage.target, colorID: CageColorID.fromIndex(index))
        }
    }

    private static func getAdjacentPositions(_ position: Position, size: Int) -> [Position] {
        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        return directions.compactMap { (dRow, dCol) in
            let newRow = position.row + dRow
            let newCol = position.col + dCol
            if newRow >= 0 && newRow < size && newCol >= 0 && newCol < size {
                return Position(row: newRow, col: newCol)
            }
            return nil
        }
    }

    private static func calculateOperationAndTarget(for values: [Int]) -> (Operation, Int) {
        if values.count == 1 {
            return (.none, values[0])
        }
        
        let sortedValues = values.sorted()
        let sum = values.reduce(0, +)
        let product = values.reduce(1, *)
        
        var possibleOperations: [(Operation, Int)] = [(.add, sum), (.multiply, product)]
        
        if values.count == 2 {
            let difference = abs(values[0] - values[1])
            possibleOperations.append((.subtract, difference))
            
            let maxVal = sortedValues.last!
            let minVal = sortedValues.first!
            if minVal != 0 && maxVal % minVal == 0 {
                possibleOperations.append((.divide, maxVal / minVal))
            }
        }
        
        return possibleOperations.randomElement() ?? (.add, sum)
    }
    
    static func generateLatinSquare(size: Int) -> [[Int]] {
        // Randomized backtracking fill: unlike a shuffled cyclic pattern,
        // this reaches every Latin square, so rows aren't cyclic shifts
        // of each other that players could exploit.
        var square = Array(repeating: Array(repeating: 0, count: size), count: size)
        var rowUsed = Array(repeating: Set<Int>(), count: size)
        var colUsed = Array(repeating: Set<Int>(), count: size)

        func fill(_ cell: Int) -> Bool {
            if cell == size * size { return true }
            let row = cell / size
            let col = cell % size
            for value in (1...size).shuffled() {
                if !rowUsed[row].contains(value) && !colUsed[col].contains(value) {
                    square[row][col] = value
                    rowUsed[row].insert(value)
                    colUsed[col].insert(value)
                    if fill(cell + 1) { return true }
                    square[row][col] = 0
                    rowUsed[row].remove(value)
                    colUsed[col].remove(value)
                }
            }
            return false
        }

        let filled = fill(0)
        assert(filled, "Latin square fill always succeeds for size >= 1")
        return square
    }
}