//
//  ContentView.swift
//  Numeriqo
//

import SwiftUI

struct NoEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

struct ContentView: View {
    @State private var gameState: GameState = .sizeSelection
    @State private var selectedSize: Int = 4
    @State private var selectedDifficulty: Difficulty = .medium
    @State private var mathMazeGame: MathMazeGame?

    private var appTitle: String {
        #if NUMERIQO_PRO
        "Numeriqo Pro"
        #else
        "Numeriqo"
        #endif
    }

    var body: some View {
        #if os(macOS)
        // macOS-specific layout
        ZStack {
            ThemeColors.backgroundGradient.ignoresSafeArea()

            if gameState == .sizeSelection {
                EmbossedGlyphBackground()
                    .frame(maxHeight: 500)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }

            VStack {
                GradientTitleView(text: appTitle, fontSize: 40)
                    .padding(.top)

                Group {
                    switch gameState {
                    case .sizeSelection:
                        SizeSelectionView(
                            selectedSize: $selectedSize,
                            selectedDifficulty: $selectedDifficulty,
                            onStartGame: startGame
                        )
                    case .playing:
                        if let game = mathMazeGame {
                            MathMazeGameView(
                                game: game,
                                onNewGame: { gameState = .sizeSelection }
                            )
                        }
                    }
                }
                .frame(maxWidth: 1000)
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, minHeight: 900)
        #else
        // iOS/iPadOS/visionOS layout
        ZStack {
            ThemeColors.backgroundGradient.ignoresSafeArea()

            if gameState == .sizeSelection {
                GeometryReader { geometry in
                    EmbossedGlyphBackground()
                        .frame(height: geometry.size.height * 0.52)
                        .padding(.top, geometry.size.height * 0.10)
                }
                .ignoresSafeArea(edges: .bottom)
            }

            VStack(spacing: 0) {
                GradientTitleView(
                    text: appTitle,
                    fontSize: gameState == .sizeSelection ? 46 : 34
                )
                .padding(.top, gameState == .sizeSelection ? 12 : 0)

                Group {
                    switch gameState {
                    case .sizeSelection:
                        SizeSelectionView(
                            selectedSize: $selectedSize,
                            selectedDifficulty: $selectedDifficulty,
                            onStartGame: startGame
                        )
                    case .playing:
                        if let game = mathMazeGame {
                            MathMazeGameView(
                                game: game,
                                onNewGame: { gameState = .sizeSelection }
                            )
                        }
                    }
                }
            }
        }
        #endif
    }

    private func startGame() {
        mathMazeGame = MathMazeGame(size: selectedSize, difficulty: selectedDifficulty)
        gameState = .playing
    }
}

enum GameState {
    case sizeSelection
    case playing
}

struct SizeSelectionView: View {
    @Binding var selectedSize: Int
    @Binding var selectedDifficulty: Difficulty
    let onStartGame: () -> Void

    #if NUMERIQO_PRO
    private let availableSizes = [3, 4, 5, 6, 7, 8, 9]
    #else
    private let availableSizes = [3, 4, 5]
    #endif

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            Text("Choose Puzzle Size")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(ThemeColors.primaryText)

            sizeSelectionGrid

            DifficultyCapsulePicker(selection: $selectedDifficulty)
                .padding(.horizontal, 40)

            startGameButton
                .padding(.top, 6)
        }
        .padding()
        #if os(visionOS)
        .padding(.bottom)
        #endif
    }

    private var sizeSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            ForEach(availableSizes, id: \.self) { size in
                SizeCardView(
                    size: size,
                    isSelected: selectedSize == size,
                    bestTime: BestTimesManager.shared.getBestTime(for: size, difficulty: selectedDifficulty),
                    action: { selectedSize = size }
                )
            }
        }
        .padding(.horizontal, 4)
    }

    private var startGameButton: some View {
        Button("Start Game") {
            onStartGame()
        }
        .buttonStyle(GradientPillButtonStyle())
        .padding(.horizontal, 8)
    }
}

#Preview {
    ContentView()
}
