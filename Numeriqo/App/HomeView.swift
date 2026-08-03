//
//  HomeView.swift
//  Numeriqo
//
//  A game's front door, not a settings form.
//
//  The previous version opened with two segmented pickers, which read as
//  configuration and told a new player nothing about what the app was for.
//  A first-time player now gets the rules first; everyone else gets the
//  fastest route back to a board.
//

import SwiftUI

struct HomeView: View {
    @Binding var path: [Route]

    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var size = 5
    @State private var difficulty: Difficulty = .steady
    @State private var pendingGame: PendingGame?

    /// Nothing solved and nothing learned. Lead with the rules rather than the
    /// pickers — they are meaningless before you know what a cage is.
    private var isFirstRun: Bool {
        progress.stats.puzzlesSolved == 0
            && progress.savedGame == nil
            && mastery.records.values.allSatisfy { !$0.lessonCompleted && $0.unaidedUses == 0 }
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Layout.Space.block) {
                    wordmark

                    if isFirstRun {
                        firstRun
                    } else {
                        returning
                    }

                    utilities
                }
                .padding(.horizontal, Layout.Space.gutter)
                .padding(.bottom, Layout.Space.section)
            }
        }
        .onAppear {
            if let last = progress.lastPlayed {
                size = last.size
                difficulty = last.difficulty
            }
        }
        .alert("Start a new game?", isPresented: Binding(
            get: { pendingGame != nil },
            set: { if !$0 { pendingGame = nil } }
        ), presenting: pendingGame) { game in
            Button("Start new game", role: .destructive) {
                pendingGame = nil
                startPlaying(size: game.size, difficulty: game.difficulty)
            }
            Button("Keep playing mine", role: .cancel) {
                pendingGame = nil
                path.append(.resume)
            }
        } message: { game in
            Text("Your unfinished game will be replaced by a new \(game.size)×\(game.size) on \(game.difficulty.displayName).")
        }
    }

    // MARK: - Header

    private var wordmark: some View {
        VStack(spacing: Layout.Space.tight) {
            Text(AppIdentity.name)
                .font(Theme.title)
                .foregroundStyle(Theme.ink)
                // "Numeriqo Pro" is twelve monospaced characters at largeTitle,
                // which overflows a narrow phone. Scale rather than truncate: a
                // wordmark reading "Numeriqo P..." is worse than a small one.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Arithmetic puzzles, and how to solve them")
                .font(Theme.secondary)
                .foregroundStyle(Theme.inkSecondary)
        }
        .padding(.top, Layout.Space.section)
        .padding(.bottom, Layout.Space.snug)
        .accessibilityElement(children: .combine)
    }

    // MARK: - First run

    private var firstRun: some View {
        VStack(spacing: Layout.Space.step) {
            VStack(alignment: .leading, spacing: Layout.Space.snug) {
                Text("New to this?")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                Text("Fill the grid so no row or column repeats a digit, and every outlined cage hits its target. The tutorial fills the first few cells with you.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            Button("Show me how") { path.append(.lesson(nil)) }
                .buttonStyle(.primary(tint: Theme.tierAccent(.gentle)))

            Button("Skip, I know Calcudoku") { startPlaying(size: 4, difficulty: .gentle) }
                .buttonStyle(.quiet)
        }
    }

    // MARK: - Returning

    private var returning: some View {
        VStack(spacing: Layout.Space.step) {
            dailyCard

            if progress.savedGame != nil {
                Button { path.append(.resume) } label: {
                    row(title: "Continue", subtitle: "Your game is where you left it",
                        systemImage: "play.circle")
                }
                .buttonStyle(.plain)
            }

            // Both setup controls wear the same card as Continue and Today's
            // puzzle, and carry their label inside it. An eyebrow above one and
            // a label inside the other read as two different kinds of control.
            VStack(alignment: .leading, spacing: Layout.Space.step) {
                gridPicker
                VStack(alignment: .leading, spacing: Layout.Space.snug) {
                    Text("Difficulty")
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
            .padding(.top, Layout.Space.tight)

            playButton
        }
    }

    /// Grid size, in the same card and the same control as Difficulty.
    ///
    /// The segments carry the bare number rather than "3×3", because the label
    /// above already says Grid. Seven segments of "3×3" gave each about 48pt
    /// and was most of what made this screen feel crammed; seven single digits
    /// fit comfortably.
    private var gridPicker: some View {
        VStack(alignment: .leading, spacing: Layout.Space.snug) {
            Text("Grid")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Picker("Grid", selection: $size) {
                ForEach(Array(3...9), id: \.self) { value in
                    Text("\(value)").font(Theme.numeral(.subheadline)).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Grid size")
            .accessibilityValue("\(size) by \(size)")

            // A segmented control renders a Text or an Image, never both, so a
            // padlock cannot sit on the locked segments. Said in words instead,
            // and inside the card with the control it describes.
            if !entitlements.isUnlocked {
                Text("Up to \(FeatureGate.freeSizeCeiling)×\(FeatureGate.freeSizeCeiling) is free. Bigger grids come with the full game.")
                    .font(Theme.steady(.caption))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var playButton: some View {
        let allowed = FeatureGate.isSizeAvailable(size, unlocked: entitlements.isUnlocked)
        return Button {
            if allowed {
                requestStart(size: size, difficulty: difficulty)
            } else {
                paywall.present(.largeGrids)
            }
        } label: {
            Label(allowed ? "Play" : "Unlock \(size)×\(size)",
                  systemImage: allowed ? "play.fill" : "lock.fill")
        }
        .buttonStyle(.primary(tint: allowed ? Theme.tierAccent(difficulty) : Theme.inkSecondary))
        .animation(reduceMotion ? nil : Motion.noteFlip, value: allowed)
    }

    /// A new game the player has been asked to confirm, because starting it
    /// would discard the one under "Continue".
    private struct PendingGame: Identifiable {
        let size: Int
        let difficulty: Difficulty
        var id: String { "\(size)-\(difficulty.rawValue)" }
    }

    /// There is one save slot. Starting a new game silently overwrote it, so a
    /// half-finished 9×9 could be destroyed by tapping Play to see what a 4×4
    /// looked like — with no warning and no undo.
    private func requestStart(size: Int, difficulty: Difficulty) {
        if progress.savedGame != nil {
            pendingGame = PendingGame(size: size, difficulty: difficulty)
        } else {
            startPlaying(size: size, difficulty: difficulty)
        }
    }

    private func startPlaying(size: Int, difficulty: Difficulty) {
        progress.recordLastPlayed(size: size, difficulty: difficulty)
        path.append(.play(size: size, difficulty: difficulty))
    }

    // MARK: - Daily

    private var dailyCard: some View {
        let day = DailyPuzzle.today
        let done = progress.hasCompletedDaily(day: day)
        let streak = progress.daily.currentStreak

        return Button {
            if !done { path.append(.daily(day: day)) }
        } label: {
            row(title: done ? "Today's puzzle, solved" : "Today's puzzle",
                subtitle: streakLine(streak: streak, done: done),
                systemImage: done ? "checkmark.circle.fill" : "calendar",
                showsChevron: !done,
                tint: done ? Theme.accent : Theme.ink)
        }
        .buttonStyle(.plain)
        .disabled(done)
        .accessibilityLabel(done ? "Today's puzzle, solved" : "Today's puzzle")
        .accessibilityValue(streakLine(streak: streak, done: done))
    }

    /// A missed day dims the count. It never scolds.
    private func streakLine(streak: Int, done: Bool) -> String {
        if streak == 0 {
            return done ? "Come back tomorrow to start a streak" : "The same grid for everyone"
        }
        let days = "\(streak) day\(streak == 1 ? "" : "s")"
        return done ? "\(days) in a row" : "\(days) in a row. Keep it going."
    }

    // MARK: - Utilities

    private var utilities: some View {
        HStack(spacing: Layout.Space.snug) {
            utility("Learn", systemImage: "book") { path.append(.learn) }
            utility("Progress", systemImage: "chart.bar") { path.append(.stats) }
            utility("Settings", systemImage: "gearshape") { path.append(.settings) }
        }
        .padding(.top, Layout.Space.snug)
    }

    private func utility(_ title: String, systemImage: String,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Layout.Space.tight) {
                Image(systemName: systemImage).font(Theme.heading)
                // `fixedSize` vertically because the audit reports "Text
                // clipped" otherwise: inside a fixed-height tile the caption
                // gets a box exactly one line high, which crops the descender
                // of "Progress". Wrapping to two lines covers the same word at
                // the largest Dynamic Type sizes, where a third of the screen
                // is not wide enough for it on one.
                Text(title)
                    .font(Theme.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Layout.Space.snug)
        }
        .buttonStyle(.secondary)
        .accessibilityLabel(title)
    }

    // MARK: - Pieces

    private func row(title: String, subtitle: String, systemImage: String,
                     showsChevron: Bool = true, tint: Color = Theme.ink) -> some View {
        HStack(spacing: Layout.Space.step) {
            Image(systemName: systemImage)
                .font(Theme.heading)
                .foregroundStyle(tint)
                .frame(minWidth: 24)
            VStack(alignment: .leading, spacing: Layout.Space.tight) {
                Text(title)
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(Theme.caption)
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .card()
        .contentShape(Rectangle())
    }

}
