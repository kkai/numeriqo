//
//  ContentView.swift
//  gengen
//
//  Created by kai on 27.07.25.
//

import SwiftUI

struct ContentView: View {
    @State private var gameState: GameState = .sizeSelection
    @State private var selectedSize: Int = 4
    @State private var mathMazeGame: MathMazeGame?
    
    var body: some View {
        #if os(macOS)
        // macOS-specific layout without NavigationView
        VStack {
            Text("Numeriqo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            
            Group {
                switch gameState {
                case .sizeSelection:
                    SizeSelectionView(
                        selectedSize: $selectedSize,
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
            .frame(maxWidth: 800)
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 700)
        .background(Color.white)
        #else
        // iOS/iPadOS layout with NavigationView
        NavigationView {
            Group {
                switch gameState {
                case .sizeSelection:
                    SizeSelectionView(
                        selectedSize: $selectedSize,
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
            .navigationTitle("Numeriqo")
        }
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private func startGame() {
        mathMazeGame = MathMazeGame(size: selectedSize)
        gameState = .playing
    }
}

enum GameState {
    case sizeSelection
    case playing
}

struct SizeSelectionView: View {
    @Binding var selectedSize: Int
    let onStartGame: () -> Void
    
    private let availableSizes = [3, 4, 5, 6, 7, 8, 9]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose Puzzle Size")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
                ForEach(availableSizes, id: \.self) { size in
                    Button(action: {
                        selectedSize = size
                    }) {
                        VStack(spacing: 4) {
                            Text("\(size)×\(size)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(difficultyText(for: size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Best time display
                            if let bestTime = BestTimesManager.shared.getBestTime(for: size) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trophy.fill")
                                        .font(.caption2)
                                        .foregroundColor(selectedSize == size ? .yellow : .orange)
                                    Text(BestTimesManager.formatTime(bestTime))
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedSize == size ? .white : .primary)
                                }
                            } else {
                                Text("No record")
                                    .font(.caption2)
                                    .foregroundColor(selectedSize == size ? .white.opacity(0.7) : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(selectedSize == size ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(selectedSize == size ? .white : .primary)
                        .cornerRadius(12)
                    }
                    #if os(macOS)
                    .buttonStyle(.plain)
                    #endif
                }
            }
            .padding(.horizontal)
            
            Button("Start Game") {
                onStartGame()
            }
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .cornerRadius(12)
            .padding(.horizontal)
            #if os(macOS)
            .buttonStyle(.plain)
            #endif
        }
        .padding()
    }
    
    private func difficultyText(for size: Int) -> String {
        switch size {
        case 3: return "Easy"
        case 4: return "Medium"
        case 5: return "Hard"
        case 6: return "Expert"
        case 7: return "Master"
        case 8: return "Grand Master"
        case 9: return "Legend"
        default: return ""
        }
    }
}

#Preview {
    ContentView()
}
