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
    @State private var kenkenGame: KenKenGame?
    
    var body: some View {
        NavigationView {
            Group {
                switch gameState {
                case .sizeSelection:
                    SizeSelectionView(
                        selectedSize: $selectedSize,
                        onStartGame: startGame
                    )
                case .playing:
                    if let game = kenkenGame {
                        KenKenGameView(
                            game: game,
                            onNewGame: { gameState = .sizeSelection }
                        )
                    }
                }
            }
            .navigationTitle("KenKen")
        }
    }
    
    private func startGame() {
        kenkenGame = KenKenGame(size: selectedSize)
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
    
    private let availableSizes = [3, 4, 5, 6]
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Choose Puzzle Size")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                ForEach(availableSizes, id: \.self) { size in
                    Button(action: {
                        selectedSize = size
                    }) {
                        VStack {
                            Text("\(size)×\(size)")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(difficultyText(for: size))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .background(selectedSize == size ? Color.accentColor : Color.gray.opacity(0.2))
                        .foregroundColor(selectedSize == size ? .white : .primary)
                        .cornerRadius(12)
                    }
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
            .background(Color.accentColor)
            .cornerRadius(12)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func difficultyText(for size: Int) -> String {
        switch size {
        case 3: return "Easy"
        case 4: return "Medium"
        case 5: return "Hard"
        case 6: return "Expert"
        default: return ""
        }
    }
}

#Preview {
    ContentView()
}
