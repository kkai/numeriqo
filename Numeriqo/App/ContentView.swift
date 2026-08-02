//
//  ContentView.swift
//  Numeriqo
//

import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { destination(for: $0) }
        }
        .tint(Theme.ink)
        .sheet(item: Binding(get: { paywall.context }, set: { if $0 == nil { paywall.dismiss() } })) {
            PaywallView(context: $0)
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .play(let size, let difficulty):
            GameView(size: size, difficulty: difficulty)
        case .resume:
            ResumeGameView()
        case .learn:
            LearnMenuView(path: $path)
        case .lesson(let technique):
            LessonView(technique: technique) {
                // "Start playing" now starts playing, on a board sized for
                // somebody who has just learned the rules.
                path = [.play(size: 4, difficulty: .gentle)]
            }
        case .daily(let day):
            GameView(daily: day)
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}
