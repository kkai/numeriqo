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
    @State private var showingCompletionAlert = false
    @State private var completionMessage = ""
    
    var body: some View {
        Group {
            #if os(visionOS)
            // Vision Pro: Optimized layout with timer repositioned
            VStack(spacing: 30) {
                // Top section: Timer and New Game button
                HStack {
                    // Timer display (moved to top left)
                    HStack {
                        Image(systemName: "timer")
                            .foregroundColor(.secondary)
                            .font(.title2)
                        Text(BestTimesManager.formatTime(game.elapsedTime))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    // New Game button (moved to top right for accessibility)
                    Button("New Game") {
                        onNewGame()
                    }
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(width: 180, height: 50)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 60)
                
                // Main content: Game grid and controls side by side
                HStack(alignment: .center, spacing: 60) {
                    // Left side: Game grid (centered and properly sized)
                    GameGridView(
                        game: game,
                        onCellTap: { position in
                            game.selectedPosition = position
                        }
                    )
                    .frame(width: 500, height: 500)
                    
                    // Right side: Number input controls (aligned with grid)
                    VStack(spacing: 25) {
                        Text("Select Number")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        VisionProNumberInputView(game: game)
                    }
                    .frame(width: 240)
                }
            }
            .frame(maxWidth: 1200, maxHeight: 800)
            .padding(40)
            #else
            // Other platforms: Vertical layout
            VStack(spacing: 20) {
                // Timer display
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.secondary)
                    Text(BestTimesManager.formatTime(game.elapsedTime))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .padding(.horizontal)
                
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
                #if os(macOS)
                .buttonStyle(.plain)
                #endif
            }
            #if os(macOS)
            .frame(maxWidth: 600)
            .padding()
            .background(Color.white)
            #endif
            #endif
        }
        .onChange(of: game.isCompleted) { oldValue, newValue in
            if newValue {
                let time = game.elapsedTime
                let formattedTime = BestTimesManager.formatTime(time)
                let isNewRecord = BestTimesManager.shared.isNewBestTime(for: game.size, time: time)
                
                if isNewRecord {
                    completionMessage = "You solved the puzzle in \(formattedTime)!\n🎉 New Record!"
                } else if let bestTime = BestTimesManager.shared.getBestTime(for: game.size) {
                    let formattedBest = BestTimesManager.formatTime(bestTime)
                    completionMessage = "You solved the puzzle in \(formattedTime)!\nBest time: \(formattedBest)"
                } else {
                    completionMessage = "You solved the puzzle in \(formattedTime)!"
                }
                showingCompletionAlert = true
            }
        }
        .alert("Congratulations!", isPresented: $showingCompletionAlert) {
            Button("New Game", action: onNewGame)
            Button("OK") { }
        } message: {
            Text(completionMessage)
        }
    }
}

struct GameGridView: View {
    @ObservedObject var game: MathMazeGame
    let onCellTap: (Position) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let cellSize = optimalCellSize(for: game.size, in: geometry.size)
            
            #if os(visionOS)
            // For visionOS, calculate centering offset
            let gridTotalSize = CGFloat(game.size) * cellSize + CGFloat(game.size - 1)
            let xOffset = (geometry.size.width - gridTotalSize) / 2
            let yOffset = (geometry.size.height - gridTotalSize) / 2
            
            ZStack {
                // Cage backgrounds
                ForEach(game.cages) { cage in
                    CageBackgroundView(cage: cage, cellSize: cellSize, game: game, xOffset: xOffset, yOffset: yOffset)
                }
                
                // Cage labels
                ForEach(game.cages) { cage in
                    CageLabelView(cage: cage, cellSize: cellSize, game: game, xOffset: xOffset, yOffset: yOffset)
                }
                
                // Grid cells - centered properly
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
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            #else
            // Other platforms - use existing layout
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
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }
    
    private func optimalCellSize(for boardSize: Int, in containerSize: CGSize) -> CGFloat {
        #if os(visionOS)
        // Vision Pro: Larger sizes for much better readability
        let maxSize = min(containerSize.width, containerSize.height) - 60 // padding
        let calculatedSize = maxSize / CGFloat(boardSize)
        
        switch boardSize {
        case 3:
            return min(calculatedSize, 140)
        case 4:
            return min(calculatedSize, 120)
        case 5:
            return min(calculatedSize, 100)
        case 6:
            return min(calculatedSize, 85)
        case 7:
            return min(calculatedSize, 75)
        case 8:
            return min(calculatedSize, 65)
        case 9:
            return min(calculatedSize, 60)
        default:
            return calculatedSize
        }
        #else
        // Other platforms: Use existing logic
        return min(containerSize.width, containerSize.height) / CGFloat(boardSize)
        #endif
    }
}

struct CageLabelView: View {
    let cage: Cage
    let cellSize: CGFloat
    @ObservedObject var game: MathMazeGame
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    
    var body: some View {
        // Cage label (operation and target)
        if let topLeft = cage.positions.min(by: { $0.row < $1.row || ($0.row == $1.row && $0.col < $1.col) }) {
            #if os(visionOS)
            Text("\(cage.target)\(cage.operation.rawValue)")
                .font(optimalLabelFont(for: cellSize))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .position(
                    x: CGFloat(topLeft.col) * (cellSize + 1) + cellSize * 0.35 + xOffset,
                    y: CGFloat(topLeft.row) * (cellSize + 1) + cellSize * 0.15 + yOffset
                )
            #else
            Text("\(cage.target)\(cage.operation.rawValue)")
                .font(optimalLabelFont(for: cellSize))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .position(
                    x: CGFloat(topLeft.col) * (cellSize + 1) + cellSize * 0.35,
                    y: CGFloat(topLeft.row) * (cellSize + 1) + cellSize * 0.15
                )
            #endif
        }
    }
    
    private func optimalLabelFont(for cellSize: CGFloat) -> Font {
        #if os(visionOS)
        // Vision Pro: Larger fonts for much better readability
        if cellSize >= 100 {
            return .body
        } else if cellSize >= 80 {
            return .callout
        } else if cellSize >= 60 {
            return .caption
        } else {
            return .caption2
        }
        #else
        // Other platforms: Use existing logic
        return .caption2
        #endif
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
                    .font(optimalNumberFont(for: cellSize))
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
    
    private func optimalNumberFont(for cellSize: CGFloat) -> Font {
        #if os(visionOS)
        // Vision Pro: Much larger number fonts for better readability
        if cellSize >= 120 {
            return .system(size: 48, weight: .semibold)
        } else if cellSize >= 100 {
            return .system(size: 40, weight: .semibold)
        } else if cellSize >= 80 {
            return .system(size: 32, weight: .semibold)
        } else if cellSize >= 60 {
            return .system(size: 24, weight: .semibold)
        } else {
            return .system(size: 20, weight: .semibold)
        }
        #else
        // Other platforms: Use existing logic
        return .title2
        #endif
    }
}

struct CageBackgroundView: View {
    let cage: Cage
    let cellSize: CGFloat
    @ObservedObject var game: MathMazeGame
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background fill for entire cage as a single shape
            Path { path in
                for position in cage.positions {
                    #if os(visionOS)
                    let x = CGFloat(position.col) * (cellSize + 1) - 0.5 + xOffset
                    let y = CGFloat(position.row) * (cellSize + 1) - 0.5 + yOffset
                    #else
                    let x = CGFloat(position.col) * (cellSize + 1) - 0.5
                    let y = CGFloat(position.row) * (cellSize + 1) - 0.5
                    #endif
                    path.addRect(CGRect(x: x, y: y, width: cellSize + 2, height: cellSize + 2))
                }
            }
            .fill(cage.color)
            
            // Single border around the entire cage
            CageOutlineView(cage: cage, cellSize: cellSize, xOffset: xOffset, yOffset: yOffset)
        }
    }
}

struct CageOutlineView: View {
    let cage: Cage
    let cellSize: CGFloat
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    
    var body: some View {
        Path { path in
            // Draw border segments around the cage perimeter
            for position in cage.positions {
                #if os(visionOS)
                let x = CGFloat(position.col) * (cellSize + 1) + xOffset
                let y = CGFloat(position.row) * (cellSize + 1) + yOffset
                #else
                let x = CGFloat(position.col) * (cellSize + 1)
                let y = CGFloat(position.row) * (cellSize + 1)
                #endif
                
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
                #if os(visionOS)
                .font(.headline)
                #else
                .font(.caption)
                #endif
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
            #elseif os(visionOS)
            // visionOS layout - use grid layout with larger buttons
            let columns = game.size <= 5 ? game.size + 1 : (game.size + 1) / 2 + 1
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(80), spacing: 15), count: columns), spacing: 15) {
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
                #elseif os(visionOS)
                .frame(width: 80, height: 80)
                #else
                .frame(width: 50, height: 50)
                #endif
                .background(game.selectedPosition != nil ? Color.red : Color.gray)
                #if os(visionOS)
                .cornerRadius(40)
                #else
                .cornerRadius(8)
                #endif
        }
        .disabled(game.selectedPosition == nil)
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
    }
    
    private func numberButton(for number: Int) -> some View {
        Button(action: {
            if let selected = game.selectedPosition {
                game.setValue(number, at: selected)
            }
        }) {
            Text("\(number)")
                #if os(visionOS)
                .font(.title)
                #else
                .font(.title2)
                #endif
                .fontWeight(.semibold)
                .foregroundColor(.white)
                #if os(macOS)
                .frame(width: 60, height: 60)
                #elseif os(visionOS)
                .frame(width: 80, height: 80)
                #else
                .frame(width: 50, height: 50)
                #endif
                .background(buttonColor(for: number))
                #if os(visionOS)
                .cornerRadius(40)
                #else
                .cornerRadius(8)
                #endif
        }
        .disabled(!canEnterNumber(number))
        #if os(macOS)
        .buttonStyle(.plain)
        #endif
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

// Vision Pro specific number input view (vertical layout)
struct VisionProNumberInputView: View {
    @ObservedObject var game: MathMazeGame
    
    var body: some View {
        VStack(spacing: 20) {
            // Clear button at top
            Button(action: {
                if let selected = game.selectedPosition {
                    game.setValue(nil, at: selected)
                }
            }) {
                Text("Clear")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .frame(width: 140, height: 50)
            .buttonStyle(.borderedProminent)
            .disabled(game.selectedPosition == nil)
            .tint(.red)
            
            // Number buttons in optimized grid layout
            LazyVGrid(columns: [
                GridItem(.fixed(70)),
                GridItem(.fixed(70)),
                GridItem(.fixed(70))
            ], spacing: 18) {
                ForEach(1...game.size, id: \.self) { number in
                    Button(action: {
                        if let selected = game.selectedPosition {
                            game.setValue(number, at: selected)
                        }
                    }) {
                        Text("\(number)")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    .frame(width: 70, height: 70)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canEnterNumber(number))
                    .tint(canEnterNumber(number) ? .blue : .gray)
                }
            }
        }
    }
    
    private func canEnterNumber(_ number: Int) -> Bool {
        guard let selected = game.selectedPosition else { return false }
        return game.isValidMove(number, at: selected)
    }
}

#Preview {
    MathMazeGameView(
        game: MathMazeGame(size: 4),
        onNewGame: { }
    )
}