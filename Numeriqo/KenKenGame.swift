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

struct Cage: Identifiable, Hashable {
    let id = UUID()
    let positions: Set<Position>
    let operation: Operation
    let target: Int
    let color: Color
    
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
    @Published var grid: [[Int?]]
    @Published var cages: [Cage]
    @Published var isCompleted: Bool = false
    @Published var selectedPosition: Position?
    @Published var elapsedTime: TimeInterval = 0
    @Published var startTime: Date?
    
    let size: Int
    private let solution: [[Int]]
    private var timer: Timer?
    private var accumulatedTime: TimeInterval = 0
    private var sessionStartTime: Date?
    private var isTimerRunning: Bool = false
    
    init(size: Int) {
        self.size = size
        self.grid = Array(repeating: Array(repeating: nil, count: size), count: size)
        self.solution = MathMazeGame.generateLatinSquare(size: size)
        self.cages = []
        generatePuzzle()
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
        
        // Check cage constraints
        if let affectedCage = findCage(containing: position) {
            if !isValidCageState(cage: affectedCage, with: tempGrid) {
                return false
            }
        }
        
        return true
    }
    
    private func findCage(containing position: Position) -> Cage? {
        return cages.first { $0.contains(position: position) }
    }
    
    private func isValidCageState(cage: Cage, with grid: [[Int?]]) -> Bool {
        let values: [Int] = cage.positions.compactMap { pos in
            guard pos.row < grid.count && pos.col < grid[pos.row].count else { return nil }
            return grid[pos.row][pos.col]
        }
        
        let emptyCount = cage.positions.count - values.count
        
        // If cage is complete, validate exactly
        if emptyCount == 0 {
            return cage.operation.calculate(values) == cage.target
        }
        
        // If cage is incomplete, check if it's still solvable
        return isCageStillSolvable(cage: cage, filledValues: values, emptyCount: emptyCount)
    }
    
    private func isCageStillSolvable(cage: Cage, filledValues: [Int], emptyCount: Int) -> Bool {
        // For single empty cell, check if any valid number can complete the cage
        if emptyCount == 1 {
            for candidate in 1...size {
                var testValues = filledValues
                testValues.append(candidate)
                if cage.operation.calculate(testValues) == cage.target {
                    return true
                }
            }
            return false
        }
        
        // For multiple empty cells, use more permissive validation
        // This is a simplified check - more complex logic could be added later
        switch cage.operation {
        case .add:
            let currentSum = filledValues.reduce(0, +)
            let remainingSum = cage.target - currentSum
            // Check if remaining sum is achievable with available numbers
            return remainingSum >= emptyCount && remainingSum <= emptyCount * size
        case .multiply:
            let currentProduct = filledValues.reduce(1, *)
            // Basic check: if current product already exceeds target, invalid
            return currentProduct <= cage.target && cage.target % currentProduct == 0
        case .subtract, .divide:
            // For subtraction and division with multiple empty cells, 
            // be more permissive during play
            return emptyCount == 1 || filledValues.count <= 1
        case .none:
            // Single cell cages should be complete or have specific target
            return emptyCount == 0 || (emptyCount == 1 && cage.target >= 1 && cage.target <= size)
        }
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
                BestTimesManager.shared.updateBestTime(for: size, time: completionTime)
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
    
    private func isValidSolution() -> Bool {
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
    
    private func generatePuzzle() {
        var usedPositions: Set<Position> = []
        var generatedCages: [Cage] = []
        
        // Create grayscale colors - different shades of gray
        let grayscaleShades: [Color] = [
            Color.gray.opacity(0.1),
            Color.gray.opacity(0.2),
            Color.gray.opacity(0.3),
            Color.gray.opacity(0.4),
            Color.gray.opacity(0.5),
            Color.gray.opacity(0.15),
            Color.gray.opacity(0.25),
            Color.gray.opacity(0.35),
            Color.gray.opacity(0.45),
            Color.black.opacity(0.1),
            Color.black.opacity(0.15),
            Color.black.opacity(0.2),
            Color.black.opacity(0.25),
            Color.black.opacity(0.3),
            Color.black.opacity(0.35)
        ]
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
                    getAdjacentPositions(pos).filter { !usedPositions.contains($0) }
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
                color: grayscaleShades[colorIndex % grayscaleShades.count]
            )
            
            generatedCages.append(cage)
            colorIndex += 1
        }
        
        self.cages = generatedCages
    }
    
    private func getAdjacentPositions(_ position: Position) -> [Position] {
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
    
    private func calculateOperationAndTarget(for values: [Int]) -> (Operation, Int) {
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
        var square = Array(repeating: Array(repeating: 0, count: size), count: size)
        
        // Generate initial Latin square
        for i in 0..<size {
            for j in 0..<size {
                square[i][j] = ((i + j) % size) + 1
            }
        }
        
        // Shuffle rows and columns to add randomness
        let rowPermutation = (0..<size).shuffled()
        let colPermutation = (0..<size).shuffled()
        
        var shuffledSquare = Array(repeating: Array(repeating: 0, count: size), count: size)
        for i in 0..<size {
            for j in 0..<size {
                shuffledSquare[i][j] = square[rowPermutation[i]][colPermutation[j]]
            }
        }
        
        return shuffledSquare
    }
}