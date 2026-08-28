//
//  GameView.swift
//  Numeriqo
//

import SwiftUI

struct GameView: View {
    private enum Source: Equatable {
        case fresh(size: Int, difficulty: Difficulty)
        case daily(day: Int)
        case resume(GameSnapshot)
    }

    /// Today's daily is a fixed size and tier so everyone solves the same board.
    static let dailySize = 6
    static let dailyDifficulty: Difficulty = .steady

    private let source: Source

    init(size: Int, difficulty: Difficulty) {
        source = .fresh(size: size, difficulty: difficulty)
    }

    init(resuming snapshot: GameSnapshot) {
        source = .resume(snapshot)
    }

    init(daily day: Int) {
        source = .daily(day: day)
    }

    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var game: NumeriqoGame?
    @State private var hint: Hint?
    /// Set for exactly one board change, so a digit placed by Apply is not
    /// credited as the player's own deduction.
    @State private var appliedHint = false
    @State private var newBestTime = false
    @State private var failedToGenerate = false
    /// Wall-clock anchor for the play timer.
    ///
    /// Reset whenever the scene leaves and re-enters the foreground. Without
    /// that, the first tick after returning folds the entire background
    /// interval into `elapsed` — an overnight background adds hours of "play
    /// time" and can poison a first best.
    @State private var lastTick = Date()

    private let engine = HintEngine()

    private var size: Int {
        switch source {
        case .fresh(let size, _): size
        case .daily: Self.dailySize
        case .resume(let snapshot): snapshot.puzzle.size
        }
    }

    private var isDaily: Bool {
        if case .daily = source { return true }
        return false
    }

    private var difficulty: Difficulty {
        switch source {
        case .fresh(_, let difficulty): difficulty
        case .daily: Self.dailyDifficulty
        case .resume(let snapshot): snapshot.difficulty
        }
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let game {
                content(game)
            } else {
                PuzzleLoadingView(size: size, failed: failedToGenerate) {
                    failedToGenerate = false
                    Task { await load() }
                }
            }
        }
        .navigationTitle(isDaily ? "Today's puzzle" : "\(size)×\(size) · \(difficulty.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .swipeBackDisabled()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let game {
                    Text(Self.clock(game.elapsed))
                        .font(Theme.numeral(.footnote))
                        .foregroundStyle(Theme.inkSecondary)
                        .accessibilityLabel("Elapsed time")
                        .accessibilityValue(Self.spokenClock(game.elapsed))
                }
            }
        }
        .task { await load() }
        .onChange(of: scenePhase) { _, phase in
            lastTick = Date()
            if phase != .active { persist() }
        }
        .onDisappear { persist() }
    }

    @ViewBuilder
    private func content(_ game: NumeriqoGame) -> some View {
        // The board is sized from the width and nothing else.
        //
        // It used to be an `aspectRatio(1, .fit)` with no cap in a VStack, so it
        // absorbed whatever height was left. Removing the pad on a win therefore
        // *grew* the grid at the exact moment the player wants to look at it,
        // and the win banner, floating in an `.overlay`, then covered the bottom
        // row of the puzzle they had just finished. DESIGN.md §7 already asked
        // for this: the board never moves when what sits under it changes.
        GeometryReader { proxy in
            // The exact drawn size, not the space available. `BoardGeometry`
            // caps a cell at 72pt, so a 4x4 is 288pt wide however wide the
            // phone is; framing it to the full width reserved 60-odd points of
            // nothing on either side and left the grid looking adrift.
            //
            // Constrained by height as well as width, because iPad landscape is
            // wide and short. Sizing from width alone gave a 9x9 the full 648pt
            // at the cell cap, which together with the pad beneath it exceeded
            // the height of an iPad mini on its side and pushed the number pad
            // off the bottom of the screen. On a phone the width still binds, so
            // this changes nothing there.
            // Landscape on a tablet is wide and short, so stacking wastes the
            // width and starves the height. Side by side uses both.
            let sideBySide = proxy.size.width > proxy.size.height * 1.2
            let column = sideBySide ? proxy.size.width * 0.55 : proxy.size.width
            let byWidth = column - Layout.Space.gutter * 2
            let byHeight = proxy.size.height * (sideBySide ? 0.86 : 0.62)
            let available = min(byWidth, byHeight)
            let cell = min((available / CGFloat(game.puzzle.size)).rounded(.down), 72)
            let side = cell * CGFloat(game.puzzle.size)

            let board = BoardView(game: game, step: hint?.showsArgument == true ? hint?.step : nil)
                .frame(width: side, height: side)

            if sideBySide {
                HStack(spacing: Layout.Space.block) {
                    board
                        .frame(maxWidth: .infinity)
                    footer(game)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, Layout.Space.gutter)
                .frame(width: proxy.size.width, height: proxy.size.height)
            } else {
                VStack(spacing: Layout.Space.block) {
                    board
                        .padding(.top, Layout.Space.block)

                    // The gap belongs here on purpose: it is where a hint banner
                    // appears, so reserving it means asking for a hint does not
                    // shove the board upward mid-thought.
                    Spacer(minLength: 0)

                    footer(game)
                        .padding(.horizontal, Layout.Space.gutter)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .padding(.bottom, Layout.Space.step)
        .task(id: game.phase) {
            // Drives the play clock. Nothing called `addElapsed` before this,
            // so `elapsed` was always zero and every best time recorded 0:00.
            guard game.phase == .playing else { return }
            lastTick = Date()
            while !Task.isCancelled, game.phase == .playing {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let now = Date()
                game.addElapsed(now.timeIntervalSince(lastTick))
                lastTick = now
            }
        }
        .onChange(of: game.board) { old, new in
            creditMastery(old: old, new: new, game: game)
            // Any board change invalidates the argument on screen.
            hint = nil
            persist()
        }
        .onChange(of: game.phase) { _, phase in
            guard phase == .won else { return }
            progress.clearSavedGame()
            // Taken from recordSolve rather than re-derived against a store
            // that has already been updated: on an exact tie that comparison
            // claims a record which was never written.
            newBestTime = progress.recordSolve(
                size: game.puzzle.size, difficulty: game.difficulty, time: game.elapsed
            )
            if game.isDaily { progress.recordDailyCompleted(day: DailyPuzzle.today) }
            AccessibilityNotification.Announcement(winMessage).post()
        }
        // VoiceOver has no way to notice a banner appearing at the bottom of
        // the screen, so say it.
        .onChange(of: hint?.text) { _, text in
            guard let text else { return }
            AccessibilityNotification.Announcement(text).post()
        }
    }

    /// Everything below the board, in one slot.
    ///
    /// One slot rather than three stacked conditionals, because each of these
    /// replaces the others: you are either playing, reading a hint, or finished.
    /// The win banner lives here instead of in an `.overlay` so it sits *below*
    /// the completed grid rather than on top of it.
    @ViewBuilder
    private func footer(_ game: NumeriqoGame) -> some View {
        VStack(spacing: Layout.Space.block) {
            if let hint {
                HintBanner(
                    hint: hint,
                    onMore: { escalate(game) },
                    onApply: { apply(hint, to: game) },
                    onDismiss: { self.hint = nil },
                    onUnlock: { paywall.present(.teachingHints) }
                )
            } else if game.phase == .playing {
                hintButton(game)
            }

            // The pad is hidden once won. It stayed on screen at full opacity
            // while every key silently swallowed taps, because `press`/`tap`/
            // `undo` all guard on `phase == .playing`.
            if game.phase == .playing {
                NumberPadView(game: game)
            } else {
                winBanner
            }
        }
    }

    /// The best moment in the app, so it must not dead-end. Before this the
    /// only way on was Back and re-pick.
    @ViewBuilder
    private var winBanner: some View {
        VStack(spacing: Layout.Space.step) {
            Text(winMessage)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)

            // The daily used to end here with no button at all — a dead end at
            // the best moment in the app, on the screen whose whole job is
            // making you come back tomorrow.
            HStack(spacing: Layout.Space.snug) {
                if case .daily = source {
                    Button("Play another") { startAnother() }
                        .buttonStyle(.secondary)
                } else {
                    Button("New puzzle") { startAnother() }
                        .buttonStyle(.primary(tint: Theme.tierAccent(difficulty)))
                }
                Button("Done") { dismiss() }
                    .buttonStyle(.secondary)
            }
        }
        .card()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(winMessage)
    }

    private var winMessage: String {
        let time = Self.spokenClock(game?.elapsed ?? 0)
        if case .daily = source { return "Today's puzzle, solved in \(time)." }
        return newBestTime ? "Solved in \(time). Your best yet." : "Solved in \(time)."
    }

    private func startAnother() {
        hint = nil
        newBestTime = false
        game = nil
        Task { await load() }
    }

    // MARK: - Clock

    static func clock(_ time: TimeInterval) -> String {
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Spoken form. VoiceOver reads "3:07" as "three colon zero seven".
    static func spokenClock(_ time: TimeInterval) -> String {
        let total = Int(time)
        let minutes = total / 60, seconds = total % 60
        if minutes == 0 { return "\(seconds) second\(seconds == 1 ? "" : "s")" }
        return "\(minutes) minute\(minutes == 1 ? "" : "s") \(seconds) second\(seconds == 1 ? "" : "s")"
    }

    private func hintButton(_ game: NumeriqoGame) -> some View {
        Button {
            let policy = FeatureGate.hintPolicy(unlocked: entitlements.isUnlocked)
            let produced = engine.hint(for: game, mastery: mastery,
                                       showErrors: progress.settings.showErrors, policy: policy)
            hint = produced
            // Only a hint the player actually received counts. A paywall pitch
            // or "nothing to find" used to inflate the very number the stats
            // screen sells as proof the teaching works.
            if !produced.isLocked, produced.step != nil || produced.isError {
                progress.recordHintTaken(difficulty: game.difficulty)
            }
            Haptics.hint()
        } label: {
            Label("Hint", systemImage: "lightbulb")
        }
        .buttonStyle(.quiet)
        .disabled(game.phase != .playing)
        .accessibilityLabel("Hint")
        .accessibilityHint("Names the region first. Ask again for more.")
    }

    // MARK: - Actions

    private func escalate(_ game: NumeriqoGame) {
        guard let current = hint else { return }
        let policy = FeatureGate.hintPolicy(unlocked: entitlements.isUnlocked)
        hint = engine.escalate(current, for: game, mastery: mastery, policy: policy)
        Haptics.hint()
    }

    private func apply(_ hint: Hint, to game: NumeriqoGame) {
        guard let step = hint.step else { self.hint = nil; return }
        // Marks the next board change as assisted, so mastery is not credited.
        appliedHint = true
        game.apply(step)
        self.hint = nil
    }

    private func creditMastery(old: BoardState, new: BoardState, game: NumeriqoGame) {
        let wasApplied = appliedHint
        appliedHint = false

        guard new.entries.count == old.entries.count + 1,
              let added = new.entries.first(where: { old.entries[$0.key] == nil })
        else { return }

        // Two guards: the player didn't tap Apply, and this cell hasn't already
        // paid out. The second is what stops a technique being farmed to
        // Learned by placing, undoing, and placing again.
        let firstTime = game.claimMasteryCredit(at: added.key)
        mastery.recordEntry(cell: added.key, digit: added.value, game: game,
                            unaided: !wasApplied && firstTime)
    }

    /// Persists unless the game is finished — a won board clears its save and
    /// must not resurrect it on the way out.
    private func persist() {
        guard let game, game.phase != .won else { return }
        progress.saveGame(game.snapshot)
    }

    private func load() async {
        guard game == nil else { return }

        switch source {
        case .resume(let snapshot):
            let resumed = NumeriqoGame(snapshot: snapshot)
            resumed.cellFirstInput = progress.settings.cellFirstInput
            game = resumed

        case .fresh(let size, let difficulty):
            // Generation is nonisolated, so it runs off the main actor.
            let generated = await Task.detached(priority: .userInitiated) {
                PuzzleGenerator.generate(matching: difficulty, size: size,
                                         seed: UInt64.random(in: 0..<UInt64.max))
            }.value
            guard let generated else { failedToGenerate = true; return }
            let fresh = NumeriqoGame(puzzle: generated.puzzle, difficulty: difficulty)
            fresh.cellFirstInput = progress.settings.cellFirstInput
            if progress.settings.autoNotes { fresh.fillAutoNotes() }
            game = fresh

        case .daily(let day):
            // Seeded from the date, so every player gets the same board and a
            // streak means something.
            let seed = DailyPuzzle.seed(day: day, size: Self.dailySize,
                                        difficulty: Self.dailyDifficulty)
            let size = Self.dailySize
            let tier = Self.dailyDifficulty
            let generated = await Task.detached(priority: .userInitiated) {
                DailyPuzzle.generate(seed: seed, size: size, difficulty: tier)
            }.value
            guard let generated else { failedToGenerate = true; return }
            let fresh = NumeriqoGame(puzzle: generated.puzzle,
                                     difficulty: Self.dailyDifficulty, isDaily: true)
            fresh.cellFirstInput = progress.settings.cellFirstInput
            if progress.settings.autoNotes { fresh.fillAutoNotes() }
            game = fresh
        }

        if let game { Self.solveForUITestsIfAsked(game) }
    }

    /// Fills everything but the last cell when a UI test asks for it.
    ///
    /// The win screen was otherwise untestable and un-screenshottable: a UI test
    /// cannot know the solution, and the whole point of the board is that the
    /// app does not hand it over. This leaves one cell empty so the test still
    /// reaches the win through a real placement rather than by being told it
    /// won. Debug-only, and inert without the launch argument.
    private static func solveForUITestsIfAsked(_ game: NumeriqoGame) {
        #if DEBUG
        guard CommandLine.arguments.contains("-uiTestSolveBoard") else { return }
        let cells = game.puzzle.allCells
        for cell in cells.dropLast() {
            game.place(game.puzzle.solutionValue(at: cell), at: cell)
        }
        #endif
    }
}

/// The daily puzzle's identity.
///
/// Everyone gets the same board on the same day, which is what makes a streak
/// mean anything — so the seed comes from the date, never from the device.
nonisolated enum DailyPuzzle {
    /// Days since the epoch in the player's **own** calendar.
    ///
    /// Dividing `timeIntervalSince1970` by 86,400 counts UTC days, so the
    /// "daily" rolled over at 01:00 in Germany and mid-afternoon across the US,
    /// and streaks broke for reasons nobody could see.
    static var today: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: Date(timeIntervalSince1970: 0),
                                       to: start).day ?? 0
    }

    static func seed(day: Int, size: Int, difficulty: Difficulty) -> UInt64 {
        UInt64(bitPattern: Int64(day &* 2_654_435_761 &+ size &* 40_503 &+ difficulty.order &* 97))
    }

    /// A seed that fails to generate would fail identically for every player
    /// on that date, bricking that daily worldwide. Salt deterministically per
    /// round instead: round 0 is the unsalted seed, so every date that
    /// generates first try keeps the exact board it always had, and a stuck
    /// date self-heals to the same replacement board for everyone.
    static func generate(seed: UInt64, size: Int, difficulty: Difficulty) -> PuzzleGenerator.Result? {
        for round in 0..<8 {
            if let result = PuzzleGenerator.generate(
                matching: difficulty, size: size,
                seed: seed &+ UInt64(round) &* 0x9E37_79B9_7F4A_7C15) {
                return result
            }
        }
        return nil
    }
}
