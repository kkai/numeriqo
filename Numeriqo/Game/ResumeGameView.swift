//
//  ResumeGameView.swift
//  Numeriqo
//

import SwiftUI

/// Resumes the saved game.
///
/// The snapshot is resolved **once**, on appear, into local state. Reading
/// `progress.savedGame` inline would mean winning — which clears the save —
/// invalidates this destination and swaps the live game out mid-celebration.
/// Resolve navigation input at entry; never re-derive a screen's existence from
/// state it will itself mutate.
struct ResumeGameView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var snapshot: GameSnapshot?
    @State private var resolved = false

    var body: some View {
        Group {
            if let snapshot {
                GameView(resuming: snapshot)
            } else if resolved {
                ContentUnavailableView("No game to resume", systemImage: "square.grid.3x3")
            } else {
                Color.clear
            }
        }
        .onAppear {
            guard !resolved else { return }
            snapshot = progress.savedGame
            resolved = true
        }
    }
}
