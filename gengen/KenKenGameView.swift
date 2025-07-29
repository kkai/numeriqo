//
//  MathMazeGameView.swift
//  gengen
//
//  Created by kai on 27.07.25.
//

import SwiftUI

struct MathMazeGameView: View {
    @ObservedObject var game: MathMazeGame
    let onNewGame: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Game grid
            GameGridView(
                game: game,
                onCellTap: { position in
                    game.selectedPosition = position
                }
            )
            
            // Number input buttons
            NumberInputView(game: game)
            
            // Controls
            Button("New Game") {
                onNewGame()
            }
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            #if os(macOS)
            .frame(width: 200, height: 44)
            #else
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            #endif
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        #if os(macOS)
        .frame(maxWidth: 600)
        .padding()
        #endif
        .alert("Congratulations!", isPresented: $game.isCompleted) {
            Button("New Game", action: onNewGame)
            Button("OK") { }
        } message: {
            Text("You solved the puzzle!")
        }
    }
}

struct GameGridView: View {
    @ObservedObject var game: MathMazeGame
    let onCellTap: (Position) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / CGFloat(game.size)
            
            ZStack {
                // Cage backgrounds
                ForEach(game.cages) { cage in
                    CageBackgroundView(cage: cage, cellSize: cellSize, game: game)
                }
                
                // Cage labels
                ForEach(game.cages) { cage in
                    CageLabelView(cage: cage, cellSize: cellSize, game: game)
                }
                
                // Grid cells
                VStack(spacing: 1) {
                    ForEach(0..<game.size, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<game.size, id: \.self) { col in
                                CellView(
                                    position: Position(row: row, col: col),
                                    game: game,
                                    cellSize: cellSize,
                                    onTap: onCellTap
                                )
                                .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
}

struct CageLabelView: View {
    let cage: Cage
    let cellSize: CGFloat
    @ObservedObject var game: MathMazeGame
    
    var body: some View {
        // Cage label (operation and target)
        if let topLeft = cage.positions.min(by: { $0.row < $1.row || ($0.row == $1.row && $0.col < $1.col) }) {
            Text("\(cage.target)\(cage.operation.rawValue)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .position(
                    x: CGFloat(topLeft.col) * (cellSize + 1) + cellSize * 0.35,
                    y: CGFloat(topLeft.row) * (cellSize + 1) + cellSize * 0.15
                )
        }
    }
}

struct CellView: View {
    let position: Position
    @ObservedObject var game: MathMazeGame
    let cellSize: CGFloat
    let onTap: (Position) -> Void
    
    var body: some View {
        ZStack {
            // Transparent cell background
            Rectangle()
                .fill(Color.clear)
            
            // Number display
            if let value = game.getValue(at: position) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        game.isValidMove(value, at: position) ? .primary : .red
                    )
            }
            
            // Selection highlight
            if game.selectedPosition == position {
                Rectangle()
                    .fill(Color.blue.opacity(0.2))
                    .overlay(
                        Rectangle()
                            .stroke(Color.blue, lineWidth: 2)
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(position)
        }
    }
}

struct CageBackgroundView: View {
    let cage: Cage
    let cellSize: CGFloat
    @ObservedObject var game: MathMazeGame
    
    var body: some View {
        ZStack {
            // Background fill for entire cage as a single shape
            Path { path in
                for position in cage.positions {
                    let x = CGFloat(position.col) * (cellSize + 1) - 0.5
                    let y = CGFloat(position.row) * (cellSize + 1) - 0.5
                    path.addRect(CGRect(x: x, y: y, width: cellSize + 2, height: cellSize + 2))
                }
            }
            .fill(cage.color)
            
            // Single border around the entire cage
            CageOutlineView(cage: cage, cellSize: cellSize)
        }
    }
}

struct CageOutlineView: View {
    let cage: Cage
    let cellSize: CGFloat
    
    var body: some View {
        Path { path in
            // Draw border segments around the cage perimeter
            for position in cage.positions {
                let x = CGFloat(position.col) * (cellSize + 1)
                let y = CGFloat(position.row) * (cellSize + 1)
                
                // Check each side of the cell to see if it's on the cage boundary
                
                // Top border
                let topNeighbor = Position(row: position.row - 1, col: position.col)
                if !cage.positions.contains(topNeighbor) {
                    path.move(to: CGPoint(x: x - 1, y: y))
                    path.addLine(to: CGPoint(x: x + cellSize + 1, y: y))
                }
                
                // Bottom border
                let bottomNeighbor = Position(row: position.row + 1, col: position.col)
                if !cage.positions.contains(bottomNeighbor) {
                    path.move(to: CGPoint(x: x - 1, y: y + cellSize))
                    path.addLine(to: CGPoint(x: x + cellSize + 1, y: y + cellSize))
                }
                
                // Left border
                let leftNeighbor = Position(row: position.row, col: position.col - 1)
                if !cage.positions.contains(leftNeighbor) {
                    path.move(to: CGPoint(x: x, y: y - 1))
                    path.addLine(to: CGPoint(x: x, y: y + cellSize + 1))
                }
                
                // Right border
                let rightNeighbor = Position(row: position.row, col: position.col + 1)
                if !cage.positions.contains(rightNeighbor) {
                    path.move(to: CGPoint(x: x + cellSize, y: y - 1))
                    path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize + 1))
                }
            }
        }
        .stroke(Color.black, lineWidth: 3)
    }
}

struct NumberInputView: View {
    @ObservedObject var game: MathMazeGame
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Select a cell, then choose a number:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            #if os(macOS)
            // macOS layout - always use grid layout for better appearance
            let columns = game.size <= 5 ? game.size + 1 : (game.size + 1) / 2 + 1
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: 10), count: columns), spacing: 10) {
                clearButton
                ForEach(1...game.size, id: \.self) { number in
                    numberButton(for: number)
                }
            }
            #else
            // iOS layout - responsive based on size
            if game.size <= 5 {
                // Single row layout for smaller grids
                HStack(spacing: 12) {
                    clearButton
                    ForEach(1...game.size, id: \.self) { number in
                        numberButton(for: number)
                    }
                }
            } else {
                // Two row layout for larger grids (6x6, 7x7, 8x8, 9x9)
                VStack(spacing: 12) {
                    // First row: Clear button + half the numbers
                    HStack(spacing: 12) {
                        clearButton
                        ForEach(1...(game.size/2), id: \.self) { number in
                            numberButton(for: number)
                        }
                    }
                    // Second row: Remaining numbers
                    HStack(spacing: 12) {
                        ForEach((game.size/2 + 1)...game.size, id: \.self) { number in
                            numberButton(for: number)
                        }
                    }
                }
            }
            #endif
        }
        .padding(.horizontal)
    }
    
    private var clearButton: some View {
        Button(action: {
            if let selected = game.selectedPosition {
                game.setValue(nil, at: selected)
            }
        }) {
            Rectangle()
                .fill(Color.clear)
                #if os(macOS)
                .frame(width: 60, height: 60)
                #else
                .frame(width: 50, height: 50)
                #endif
                .background(game.selectedPosition != nil ? Color.red : Color.gray)
                .cornerRadius(8)
        }
        .disabled(game.selectedPosition == nil)
    }
    
    private func numberButton(for number: Int) -> some View {
        Button(action: {
            if let selected = game.selectedPosition {
                game.setValue(number, at: selected)
            }
        }) {
            Text("\(number)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                #if os(macOS)
                .frame(width: 60, height: 60)
                #else
                .frame(width: 50, height: 50)
                #endif
                .background(buttonColor(for: number))
                .cornerRadius(8)
        }
        .disabled(!canEnterNumber(number))
    }
    
    private func canEnterNumber(_ number: Int) -> Bool {
        guard let selected = game.selectedPosition else { return false }
        return game.isValidMove(number, at: selected)
    }
    
    private func buttonColor(for number: Int) -> Color {
        guard let selected = game.selectedPosition else { return Color.gray }
        
        if game.isValidMove(number, at: selected) {
            return Color.blue
        } else {
            return Color.gray
        }
    }
}

#Preview {
    MathMazeGameView(
        game: MathMazeGame(size: 4),
        onNewGame: { }
    )
}