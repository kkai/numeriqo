//
//  ContentView.swift
//  gengen
//
//  Created by kai on 27.07.25.
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
    @State private var mathMazeGame: MathMazeGame?
    
    var body: some View {
        #if os(macOS)
        // macOS-specific layout without NavigationView
        VStack {
            #if NUMERIQO_PRO
            Text("Numeriqo Pro")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            #else
            Text("Numeriqo")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top)
            #endif
            
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
            .frame(maxWidth: 1000)
            .frame(maxHeight: .infinity)
        }
        .frame(minWidth: 800, minHeight: 900)
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
            #if NUMERIQO_PRO
            .navigationTitle("Numeriqo Pro")
            #else
            .navigationTitle("Numeriqo")
            #endif
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
    
    #if NUMERIQO_PRO
    private let availableSizes = [3, 4, 5, 6, 7, 8, 9]
    #else
    private let availableSizes = [3, 4, 5, 6]
    #endif
    
    var body: some View {
        VStack(spacing: 20) {
            titleView
            sizeSelectionGrid
            startGameButton
        }
        .padding()
        #if os(visionOS)
        .padding(.bottom)
        #endif
    }
    
    private var titleView: some View {
        Text("Choose Puzzle Size")
            #if os(visionOS)
            .font(.system(size: 48, weight: .bold))
            #else
            .font(.largeTitle)
            #endif
            .fontWeight(.bold)
    }
    
    private var sizeSelectionGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 15) {
            ForEach(availableSizes, id: \.self) { size in
                sizeButton(for: size)
            }
        }
        .padding(.horizontal)
    }
    
    private func sizeButton(for size: Int) -> some View {
        Button(action: {
            selectedSize = size
        }) {
            VStack(spacing: 4) {
                Text("\(size)×\(size)")
                    #if os(visionOS)
                    .font(.title)
                    #else
                    .font(.title2)
                    #endif
                    .fontWeight(.semibold)
                Text(difficultyText(for: size))
                    #if os(visionOS)
                    .font(.headline)
                    #else
                    .font(.caption)
                    #endif
                    .foregroundColor(.secondary)
                
                bestTimeView(for: size)
            }
            .frame(maxWidth: .infinity)
            #if os(visionOS)
            .frame(height: 110)
            #else
            .frame(height: 100)
            #endif
            .background(selectedSize == size ? Color.blue : Color.gray.opacity(0.2))
            .foregroundColor(selectedSize == size ? .white : .primary)
            #if os(visionOS)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .contentShape(RoundedRectangle(cornerRadius: 20))
            #else
            .cornerRadius(12)
            #endif
        }
        #if os(macOS)
        .buttonStyle(.plain)
        #elseif os(visionOS)
        .buttonStyle(NoEffectButtonStyle())
        #endif
    }
    
    private func bestTimeView(for size: Int) -> some View {
        Group {
            if let bestTime = BestTimesManager.shared.getBestTime(for: size) {
                HStack(spacing: 4) {
                    Image(systemName: "trophy.fill")
                        #if os(visionOS)
                        .font(.headline)
                        #else
                        .font(.caption2)
                        #endif
                        .foregroundColor(selectedSize == size ? .yellow : .orange)
                    Text(BestTimesManager.formatTime(bestTime))
                        #if os(visionOS)
                        .font(.headline)
                        #else
                        .font(.caption2)
                        #endif
                        .fontWeight(.medium)
                        .foregroundColor(selectedSize == size ? .white : .primary)
                }
            } else {
                Text("No record")
                    #if os(visionOS)
                    .font(.headline)
                    #else
                    .font(.caption2)
                    #endif
                    .foregroundColor(selectedSize == size ? .white.opacity(0.7) : .secondary)
            }
        }
    }
    
    private var startGameButton: some View {
        Button("Start Game") {
            onStartGame()
        }
        #if os(visionOS)
        .font(.title)
        #else
        .font(.title2)
        #endif
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        #if os(visionOS)
        .frame(height: 70)
        #else
        .frame(height: 50)
        #endif
        .background(Color.blue)
        #if os(visionOS)
        .cornerRadius(35)
        #else
        .cornerRadius(12)
        #endif
        .padding(.horizontal)
        #if os(macOS) || os(visionOS)
        .buttonStyle(.plain)
        #endif
    }
    
    private func difficultyText(for size: Int) -> String {
        switch size {
        case 3: return "Easy"
        case 4: return "Medium"
        case 5: return "Hard"
        case 6: 
            #if NUMERIQO_PRO
            return "Expert"
            #else
            return "Expert"
            #endif
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
