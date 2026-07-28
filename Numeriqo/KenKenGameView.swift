//
//  MathMazeGameView.swift
//  Numeriqo
//

import SwiftUI

struct MathMazeGameView: View {
    @ObservedObject var game: MathMazeGame
    let onNewGame: () -> Void
    @State private var showingCompletionAlert = false
    @State private var completionMessage = ""
    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    #endif

    var body: some View {
        Group {
            #if os(visionOS)
            // Vision Pro: Optimized layout with all controls on the right
            HStack(alignment: .center, spacing: 80) {
                // Left side: Just the game grid
                GameGridView(
                    game: game,
                    onCellTap: { position in
                        game.selectedPosition = position
                    }
                )
                .frame(width: 650, height: 650)  // Reduced to prevent bottom cutoff

                // Right side: All controls (New Game, Timer, Number input)
                VStack(spacing: 30) {
                    // New Game button at top
                    Button("New Game") {
                        onNewGame()
                    }
                    .buttonStyle(GradientPillButtonStyle(height: 55))
                    .frame(width: 240)

                    // Timer display
                    timerView
                        .padding(.bottom, 5)

                    Text("Select Number")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    VisionProNumberInputView(game: game)
                }
                .frame(width: 300)
            }
            .frame(maxWidth: 1300, maxHeight: 900)
            .padding(40)
            #else
            // Other platforms: Vertical layout
            VStack(spacing: 14) {
                timerView
                    .padding(.top, 4)

                // Game grid in a soft rounded container
                GameGridView(
                    game: game,
                    onCellTap: { position in
                        game.selectedPosition = position
                    }
                )
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(ThemeColors.gridContainerFill)
                        .shadow(color: ThemeColors.cardShadow, radius: 8, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(ThemeColors.gridContainerStroke, lineWidth: 2.5)
                )
                .padding(.horizontal, 12)

                Spacer(minLength: 0)

                // Number input buttons
                NumberInputView(game: game)

                // Controls
                Button("New Game") {
                    onNewGame()
                }
                .buttonStyle(GradientPillButtonStyle(height: 50))
                #if os(macOS)
                .frame(width: 260)
                #else
                .padding(.horizontal, 20)
                #endif
                .padding(.bottom, 8)
            }
            .frame(maxWidth: 620)
            #if os(macOS)
            .padding()
            #endif
            #endif
        }
        .onChange(of: game.isCompleted) { oldValue, newValue in
            if newValue {
                let time = game.elapsedTime
                let formattedTime = BestTimesManager.formatTime(time)
                let isNewRecord = BestTimesManager.shared.isNewBestTime(for: game.size, difficulty: game.difficulty, time: time)

                if isNewRecord {
                    completionMessage = "You solved the puzzle in \(formattedTime)!\n🎉 New Record!"
                } else if let bestTime = BestTimesManager.shared.getBestTime(for: game.size, difficulty: game.difficulty) {
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
        #if os(macOS)
        .modifier(KeyboardInputModifier(game: game))
        #endif
        #if os(iOS)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            switch newPhase {
            case .active:
                game.resumeTimer()
            case .inactive, .background:
                game.pauseTimer()
            @unknown default:
                break
            }
        }
        #endif
    }

    private var timerView: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
            Text(BestTimesManager.formatTime(game.elapsedTime))
                .monospacedDigit()
        }
        #if os(visionOS)
        .font(.system(size: 30, weight: .semibold, design: .rounded))
        #else
        .font(.system(size: 19, weight: .semibold, design: .rounded))
        #endif
        .foregroundColor(ThemeColors.cageLabel)
    }
}

struct GameGridView: View {
    @ObservedObject var game: MathMazeGame
    let onCellTap: (Position) -> Void

    var body: some View {
        GeometryReader { geometry in
            let cellSize = optimalCellSize(for: game.size, in: geometry.size)
            // Grid extent includes the 1pt spacing between cells; center cages,
            // labels, and cells with the same offsets so all layers stay aligned.
            let gridTotalSize = CGFloat(game.size) * cellSize + CGFloat(game.size - 1)
            let xOffset = (geometry.size.width - gridTotalSize) / 2
            let yOffset = (geometry.size.height - gridTotalSize) / 2

            ZStack {
                // Cage tiles
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
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
    }

    private func optimalCellSize(for boardSize: Int, in containerSize: CGSize) -> CGFloat {
        #if os(visionOS)
        // Vision Pro: Optimized sizes for maximum readability
        let maxSize = min(containerSize.width, containerSize.height) - 40 // reduced padding for larger cells
        let calculatedSize = (maxSize - CGFloat(boardSize - 1)) / CGFloat(boardSize)

        // Increased cell sizes for better visibility in visionOS
        switch boardSize {
        case 3:
            return min(calculatedSize, 200)  // Increased from 140
        case 4:
            return min(calculatedSize, 160)  // Increased from 120
        case 5:
            return min(calculatedSize, 130)  // Increased from 100
        case 6:
            return min(calculatedSize, 110)  // Increased from 85
        case 7:
            return min(calculatedSize, 95)   // Increased from 75
        case 8:
            return min(calculatedSize, 85)   // Increased from 65
        case 9:
            return min(calculatedSize, 75)   // Increased from 60
        default:
            return calculatedSize
        }
        #else
        // iOS/iPadOS/macOS: fill the container, leaving room for the
        // (boardSize - 1) points of inter-cell spacing
        return (min(containerSize.width, containerSize.height) - CGFloat(boardSize - 1)) / CGFloat(boardSize)
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
            #if os(visionOS) || os(macOS)
            Text(verbatim: "\(cage.target)\(cage.operation.rawValue)")
                .font(optimalLabelFont(for: cellSize))
                .fontWeight(.bold)
                .foregroundColor(ThemeColors.cageLabel)
                .position(
                    x: CGFloat(topLeft.col) * (cellSize + 1) + cellSize * 0.40 + xOffset,
                    y: CGFloat(topLeft.row) * (cellSize + 1) + cellSize * 0.15 + yOffset
                )
            #else
            Text(verbatim: "\(cage.target)\(cage.operation.rawValue)")
                .font(.system(size: min(14, cellSize * 0.26), weight: .bold, design: .rounded))
                .foregroundColor(ThemeColors.cageLabel)
                .position(
                    x: CGFloat(topLeft.col) * (cellSize + 1) + cellSize * 0.34,
                    y: CGFloat(topLeft.row) * (cellSize + 1) + cellSize * 0.20
                )
            #endif
        }
    }

    private func optimalLabelFont(for cellSize: CGFloat) -> Font {
        #if os(visionOS)
        // Vision Pro: Enhanced fonts for optimal readability
        if cellSize >= 150 {
            return .title3
        } else if cellSize >= 120 {
            return .title3
        } else if cellSize >= 100 {
            return .headline
        } else if cellSize >= 80 {
            return .body
        } else if cellSize >= 60 {
            return .callout
        } else {
            return .caption
        }
        #elseif os(macOS)
        // macOS: Scaled fonts for better readability
        if cellSize >= 120 {
            return .headline
        } else if cellSize >= 90 {
            return .subheadline
        } else if cellSize >= 70 {
            return .caption
        } else if cellSize >= 50 {
            return .caption2
        } else {
            return .caption2
        }
        #else
        // iOS/iPadOS: Use existing logic
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
                    .foregroundColor(
                        game.isValidMove(value, at: position) ? ThemeColors.primaryText : ThemeColors.errorText
                    )
            }

            // Selection highlight, concentric with the visible cage tile:
            // the tile outline is inset 2.5pt from the pitch lines and stroked
            // 1.8pt (CageBackgroundView), and the pitch slot extends 1pt past
            // the cell frame, so the tile center sits 0.5pt down-right of the
            // cell center. Leave a uniform 1pt gap to the tile stroke.
            if game.selectedPosition == position {
                let inset: CGFloat = 2.5 + 0.9 + 1 + 1  // tile inset + half tile stroke + gap + half own stroke
                let radius = max(3, min(10, cellSize * 0.18) - (inset - 2.5))
                RoundedRectangle(cornerRadius: radius)
                    .fill(ThemeColors.selectionHighlight)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .stroke(ThemeColors.selectionBorder, lineWidth: 2)
                    )
                    .shadow(color: ThemeColors.accentGlow, radius: 5)
                    .frame(width: cellSize + 1 - inset * 2, height: cellSize + 1 - inset * 2)
                    .offset(x: 0.5, y: 0.5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap(position)
        }
    }

    private func optimalNumberFont(for cellSize: CGFloat) -> Font {
        #if os(visionOS)
        // Vision Pro: Optimized number fonts for maximum clarity
        if cellSize >= 180 {
            return .system(size: 72, weight: .bold, design: .rounded)
        } else if cellSize >= 150 {
            return .system(size: 60, weight: .bold, design: .rounded)
        } else if cellSize >= 120 {
            return .system(size: 52, weight: .bold, design: .rounded)
        } else if cellSize >= 100 {
            return .system(size: 44, weight: .semibold, design: .rounded)
        } else if cellSize >= 80 {
            return .system(size: 36, weight: .semibold, design: .rounded)
        } else if cellSize >= 60 {
            return .system(size: 28, weight: .semibold, design: .rounded)
        } else {
            return .system(size: 24, weight: .semibold, design: .rounded)
        }
        #elseif os(macOS)
        // macOS: Scaled number fonts for better readability
        if cellSize >= 140 {
            return .system(size: 48, weight: .semibold, design: .rounded)
        } else if cellSize >= 110 {
            return .system(size: 40, weight: .semibold, design: .rounded)
        } else if cellSize >= 90 {
            return .system(size: 32, weight: .semibold, design: .rounded)
        } else if cellSize >= 70 {
            return .system(size: 26, weight: .semibold, design: .rounded)
        } else if cellSize >= 50 {
            return .system(size: 20, weight: .semibold, design: .rounded)
        } else {
            return .system(size: 18, weight: .semibold, design: .rounded)
        }
        #else
        // iOS/iPadOS
        return .system(size: min(30, cellSize * 0.42), weight: .semibold, design: .rounded)
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
        let shape = CageShape(
            positions: cage.positions,
            cellSize: cellSize,
            xOffset: xOffset,
            yOffset: yOffset,
            inset: 2.5,
            cornerRadius: min(10, cellSize * 0.18)
        )

        ZStack {
            shape
                .fill(cage.color)
            shape
                .stroke(ThemeColors.cageBorder, lineWidth: 1.8)
                .shadow(color: ThemeColors.accentGlow.opacity(0.35), radius: 3)
        }
    }
}

struct NumberInputView: View {
    @ObservedObject var game: MathMazeGame

    #if os(macOS)
    private let buttonSize: CGFloat = 64
    #elseif os(visionOS)
    private let buttonSize: CGFloat = 76
    #else
    private let buttonSize: CGFloat = 52
    #endif

    var body: some View {
        VStack(spacing: 14) {
            #if os(macOS)
            Text("Select a cell, then click a number or type on your keyboard (arrows move, ⌫ clears):")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(ThemeColors.secondaryText)
            #else
            Text("Select a cell, then choose a number:")
                #if os(visionOS)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                #else
                .font(.system(size: 13, weight: .medium, design: .rounded))
                #endif
                .foregroundColor(ThemeColors.secondaryText)
            #endif

            #if os(macOS) || os(visionOS)
            // Grid layout for better appearance on large screens
            let columns = game.size <= 5 ? game.size + 1 : (game.size + 1) / 2 + 1
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(buttonSize), spacing: 12), count: columns), spacing: 12) {
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
            RoundedRectangle(cornerRadius: buttonSize * 0.28)
                .fill(ThemeColors.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: buttonSize * 0.28)
                        .stroke(ThemeColors.cardStroke, lineWidth: 1)
                )
                .shadow(color: ThemeColors.cardShadow, radius: 4, x: 0, y: 2)
                .frame(width: buttonSize, height: buttonSize)
                .opacity(game.selectedPosition != nil ? 1 : 0.55)
        }
        .buttonStyle(NoEffectButtonStyle())
        .disabled(game.selectedPosition == nil)
    }

    private func numberButton(for number: Int) -> some View {
        // With no cell selected the pad stays bright (taps are no-ops);
        // once a cell is selected, invalid digits dim out.
        NumberPadButton(
            label: "\(number)",
            isEnabled: game.selectedPosition == nil || canEnterNumber(number),
            size: buttonSize
        ) {
            if let selected = game.selectedPosition {
                game.setValue(number, at: selected)
            }
        }
    }

    private func canEnterNumber(_ number: Int) -> Bool {
        guard let selected = game.selectedPosition else { return false }
        return game.isValidMove(number, at: selected)
    }
}

// Vision Pro specific number input view (vertical layout)
struct VisionProNumberInputView: View {
    @ObservedObject var game: MathMazeGame

    var body: some View {
        VStack(spacing: 20) {
            // Clear button at top: themed empty tile
            Button(action: {
                if let selected = game.selectedPosition {
                    game.setValue(nil, at: selected)
                }
            }) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(ThemeColors.cardFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(ThemeColors.cardStroke, lineWidth: 1)
                    )
                    .shadow(color: ThemeColors.cardShadow, radius: 4, x: 0, y: 2)
                    .frame(width: 180, height: 60)
                    .opacity(game.selectedPosition != nil ? 1 : 0.55)
            }
            .buttonStyle(NoEffectButtonStyle())
            .disabled(game.selectedPosition == nil)

            // Number buttons in optimized grid layout with larger sizes
            LazyVGrid(columns: [
                GridItem(.fixed(85)),
                GridItem(.fixed(85)),
                GridItem(.fixed(85))
            ], spacing: 20) {
                ForEach(1...game.size, id: \.self) { number in
                    NumberPadButton(
                        label: "\(number)",
                        isEnabled: game.selectedPosition == nil || canEnterNumber(number),
                        size: 85
                    ) {
                        if let selected = game.selectedPosition {
                            game.setValue(number, at: selected)
                        }
                    }
                }
            }
        }
    }

    private func canEnterNumber(_ number: Int) -> Bool {
        guard let selected = game.selectedPosition else { return false }
        return game.isValidMove(number, at: selected)
    }
}

#if os(macOS)
import AppKit

/// Adds physical-keyboard control to the macOS game view:
/// digits 1…N enter a value into the selected cell, Delete/Backspace clears it,
/// and the arrow keys move the selection around the grid.
///
/// Uses a window-level `NSEvent` key monitor rather than SwiftUI's `.onKeyPress`,
/// because the focusable number-pad buttons would otherwise intercept the arrow
/// keys and leave keyboard entry working only intermittently.
struct KeyboardInputModifier: ViewModifier {
    @ObservedObject var game: MathMazeGame
    @State private var monitor: Any?

    func body(content: Content) -> some View {
        content
            .onAppear { installMonitor() }
            .onDisappear { removeMonitor() }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Return nil to swallow keys we act on; return the event otherwise
            // so system shortcuts and text fields keep working.
            handle(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    /// Returns true when the key was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        // Leave command-based shortcuts (⌘Q, ⌘W, …) alone.
        if event.modifierFlags.contains(.command) { return false }

        switch event.keyCode {
        case 126: move(rowDelta: -1, colDelta: 0); return true   // up arrow
        case 125: move(rowDelta: 1, colDelta: 0);  return true   // down arrow
        case 123: move(rowDelta: 0, colDelta: -1); return true   // left arrow
        case 124: move(rowDelta: 0, colDelta: 1);  return true   // right arrow
        case 51, 117:                                            // delete / forward delete
            if let selected = game.selectedPosition {
                game.setValue(nil, at: selected)
            }
            return true
        default:
            break
        }

        // Digit entry (1…N for an N×N grid).
        if let character = event.charactersIgnoringModifiers?.first,
           let digit = character.wholeNumberValue,
           digit >= 1, digit <= game.size {
            if let selected = game.selectedPosition, game.isValidMove(digit, at: selected) {
                game.setValue(digit, at: selected)
            }
            return true
        }

        return false
    }

    private func move(rowDelta: Int, colDelta: Int) {
        // First arrow press with nothing selected drops into the top-left cell.
        guard let current = game.selectedPosition else {
            game.selectedPosition = Position(row: 0, col: 0)
            return
        }
        let newRow = min(max(current.row + rowDelta, 0), game.size - 1)
        let newCol = min(max(current.col + colDelta, 0), game.size - 1)
        game.selectedPosition = Position(row: newRow, col: newCol)
    }
}
#endif

#Preview {
    MathMazeGameView(
        game: MathMazeGame(size: 4),
        onNewGame: { }
    )
}
