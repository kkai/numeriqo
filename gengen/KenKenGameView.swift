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
    
    @State private var showingNumberPicker = false
    @State private var pickerPosition: Position?
    
    var body: some View {
        VStack(spacing: 20) {
            // Game grid
            GameGridView(
                game: game,
                onCellTap: { position in
                    game.selectedPosition = position
                    pickerPosition = position
                    showingNumberPicker = true
                }
            )
            
            // Controls
            HStack {
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
                
                Button("Clear") {
                    if let selected = game.selectedPosition {
                        game.setValue(nil, at: selected)
                    }
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.red)
                .cornerRadius(8)
            }
            .padding(.horizontal)
        }
        .alert("Congratulations!", isPresented: $game.isCompleted) {
            Button("New Game", action: onNewGame)
            Button("OK") { }
        } message: {
            Text("You solved the puzzle!")
        }
        .sheet(isPresented: $showingNumberPicker) {
            if let position = pickerPosition {
                NumberPickerView(
                    game: game,
                    position: position,
                    onDismiss: { showingNumberPicker = false }
                )
            }
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

struct NumberPickerView: View {
    @ObservedObject var game: KenKenGame
    let position: Position
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Choose a number")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
                    ForEach(1...game.size, id: \.self) { number in
                        Button(action: {
                            game.setValue(number, at: position)
                            onDismiss()
                        }) {
                            Text("\(number)")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(
                                    game.isValidMove(number, at: position) ? Color.blue : Color.gray
                                )
                                .cornerRadius(8)
                        }
                        .disabled(!game.isValidMove(number, at: position))
                    }
                }
                .padding()
                
                Button("Clear") {
                    game.setValue(nil, at: position)
                    onDismiss()
                }
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.red)
                .cornerRadius(8)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    KenKenGameView(
        game: KenKenGame(size: 4),
        onNewGame: { }
    )
}