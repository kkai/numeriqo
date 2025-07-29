//
//  KenKenGameView.swift
//  gengen
//
//  Created by kai on 27.07.25.
//

import SwiftUI

struct KenKenGameView: View {
    @ObservedObject var game: KenKenGame
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
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.blue)
            .cornerRadius(8)
            .padding(.horizontal)
        }
        .alert("Congratulations!", isPresented: $game.isCompleted) {
            Button("New Game", action: onNewGame)
            Button("OK") { }
        } message: {
            Text("You solved the puzzle!")
        }
    }
}

struct GameGridView: View {
    @ObservedObject var game: KenKenGame
    let onCellTap: (Position) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = min(geometry.size.width, geometry.size.height) / CGFloat(game.size)
            
            ZStack {
                // Cage backgrounds
                ForEach(game.cages) { cage in
                    CageBackgroundView(cage: cage, cellSize: cellSize, game: game)
                }
                
                // Grid lines and cells
                VStack(spacing: 1) {
                    ForEach(0..<game.size, id: \.self) { row in
                        HStack(spacing: 1) {
                            ForEach(0..<game.size, id: \.self) { col in
                                CellView(
                                    position: Position(row: row, col: col),
                                    game: game,
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

struct CageBackgroundView: View {
    let cage: Cage
    let cellSize: CGFloat
    @ObservedObject var game: KenKenGame
    
    var body: some View {
        ZStack {
            // Background color for cage
            ForEach(Array(cage.positions), id: \.self) { position in
                Rectangle()
                    .fill(cage.color)
                    .frame(width: cellSize, height: cellSize)
                    .position(
                        x: CGFloat(position.col) * cellSize + cellSize / 2,
                        y: CGFloat(position.row) * cellSize + cellSize / 2
                    )
            }
            
            // Cage label (operation and target)
            if let topLeft = cage.positions.min(by: { $0.row < $1.row || ($0.row == $1.row && $0.col < $1.col) }) {
                Text("\(cage.target)\(cage.operation.rawValue)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .position(
                        x: CGFloat(topLeft.col) * cellSize + 8,
                        y: CGFloat(topLeft.row) * cellSize + 8
                    )
            }
        }
    }
}

struct CellView: View {
    let position: Position
    @ObservedObject var game: KenKenGame
    let onTap: (Position) -> Void
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(
                            game.selectedPosition == position ? Color.blue : Color.black,
                            lineWidth: game.selectedPosition == position ? 3 : 1
                        )
                )
            
            if let value = game.getValue(at: position) {
                Text("\(value)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(
                        game.isValidMove(value, at: position) ? .primary : .red
                    )
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(position)
        }
    }
}

struct NumberInputView: View {
    @ObservedObject var game: KenKenGame
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Select a cell, then choose a number:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                // Clear button
                Button(action: {
                    if let selected = game.selectedPosition {
                        game.setValue(nil, at: selected)
                    }
                }) {
                    Text("Clear")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .background(game.selectedPosition != nil ? Color.red : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(game.selectedPosition == nil)
                
                // Number buttons
                ForEach(1...game.size, id: \.self) { number in
                    Button(action: {
                        if let selected = game.selectedPosition {
                            game.setValue(number, at: selected)
                        }
                    }) {
                        Text("\(number)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 50, height: 50)
                            .background(buttonColor(for: number))
                            .cornerRadius(8)
                    }
                    .disabled(!canEnterNumber(number))
                }
            }
        }
        .padding(.horizontal)
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
    KenKenGameView(
        game: KenKenGame(size: 4),
        onNewGame: { }
    )
}