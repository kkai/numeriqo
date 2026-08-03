//
//  LessonView.swift
//  Numeriqo
//
//  A lesson: read the idea, then prove it on a board that needs it.
//

import SwiftUI

struct LessonView: View {
    /// nil is the rules lesson.
    let technique: Technique?
    /// So a lesson can push the next one without going back to the list.
    @Binding var path: [Route]
    var onFinishRules: (() -> Void)?

    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.dismiss) private var dismiss

    @State private var game: NumeriqoGame?
    @State private var usedHint = false
    @State private var hint: Hint?
    @State private var loading = false
    @State private var failedToGenerate = false
    @State private var hasReadToEnd = false
    /// Reaching Learned takes five unaided solves. Without advancing this it
    /// was the same memorised board five times.
    @State private var variant: UInt64 = 0

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            if let technique {
                techniqueLesson(technique)
            } else {
                RulesTutorialView(onFinish: onFinishRules)
            }
        }
        .navigationTitle(technique?.displayName ?? "How Numeriqo works")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func techniqueLesson(_ technique: Technique) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.Space.block) {
                Text(TechniqueContent.lesson(for: technique))
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(TechniqueContent.rule(for: technique))
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                if let game {
                    practiceBoard(game, technique: technique)
                } else if loading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, Layout.Space.section)
                } else if failedToGenerate {
                    VStack(spacing: Layout.Space.step) {
                        Text("That drill wouldn't come together. Try again for a different grid.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try again") {
                            failedToGenerate = false
                            Task { await loadDrill(technique) }
                        }
                        .buttonStyle(.secondary)
                    }
                } else {
                    startButton(technique)
                }

                nextLesson(after: technique)
            }
            .padding(Layout.Space.gutter)
        }
        // Reaching the bottom is what counts as having read it.
        //
        // This was a `Color.clear.onAppear` at the end of the stack, which does
        // not work: the stack is eager, not lazy, so the sentinel is created
        // (and fires) the instant the lesson opens, whether or not it is on
        // screen. Every lesson counted as read on arrival, which is exactly the
        // tap-through-three-lessons-in-six-seconds problem the comment below
        // claims was fixed. Scroll geometry is the only honest signal.
        //
        // A lesson shorter than the screen starts out satisfied, correctly:
        // there was nothing to scroll to.
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.containerSize.height
                >= geometry.contentSize.height - 24
        } action: { _, reachedBottom in
            if reachedBottom { hasReadToEnd = true }
        }
        // NOT on appear. Merely opening a lesson used to mark it complete and
        // unlock the next one, so tapping through three lessons in six seconds
        // advanced the curriculum. Completion is claimed by reading to the end.
        .onDisappear {
            if hasReadToEnd { mastery.recordLessonCompleted(technique) }
        }
    }

    /// The way onward.
    ///
    /// A lesson used to end at a paywalled drill button, and the only exit was
    /// Back to a list of seventeen rows. A ladder you have to climb down and
    /// re-find your place on is not a ladder.
    @ViewBuilder
    private func nextLesson(after technique: Technique) -> some View {
        if let next = Technique(rawValue: technique.rawValue + 1),
           FeatureGate.isLessonAvailable(next, unlocked: entitlements.isUnlocked) {
            Divider().padding(.vertical, Layout.Space.snug)
            Button {
                path.append(.lesson(next))
            } label: {
                HStack(spacing: Layout.Space.step) {
                    VStack(alignment: .leading, spacing: Layout.Space.tight) {
                        Text("Next").eyebrow()
                        Text(next.displayName)
                            .font(Theme.heading)
                            .foregroundStyle(Theme.ink)
                        Text(TechniqueContent.summary(for: next))
                            .font(Theme.caption)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSecondary)
                }
                .card()
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func startButton(_ technique: Technique) -> some View {
        let available = FeatureGate.areDrillsAvailable(unlocked: entitlements.isUnlocked)
        // Never `.disabled()`. This button was dead for free players — the
        // lesson is free, so you could read it, reach the drill, and find no
        // way to buy. A locked control has to sell what it is withholding.
        Button {
            if available {
                Task { await loadDrill(technique) }
            } else {
                paywall.present(.practiceDrills)
            }
        } label: {
            Label(available ? "Try a drill" : "Unlock practice drills",
                  systemImage: available ? "play.fill" : "lock.fill")
        }
        .buttonStyle(.primary)
    }

    @ViewBuilder
    private func practiceBoard(_ game: NumeriqoGame, technique: Technique) -> some View {
        VStack(spacing: Layout.Space.block) {
            BoardView(game: game, step: hint?.showsArgument == true ? hint?.step : nil)
            if game.phase == .won {
                Text("Solved. That's \(mastery.record(for: technique).unaidedUses) of \(MasteryTracker.learnedThreshold) unaided toward Learned.")
                    .font(Theme.steady(.footnote))
                    .foregroundStyle(Theme.accent)
            }
            NumberPadView(game: game)
        }
        .onChange(of: game.phase) { _, phase in
            guard phase == .won else { return }
            mastery.recordDrillCompleted(technique, unaided: !usedHint)
        }
    }

    private func loadDrill(_ technique: Technique) async {
        loading = true
        defer { loading = false }
        // Generation is nonisolated, so it runs off the main actor.
        let attempt = variant
        let puzzle = await Task.detached(priority: .userInitiated) {
            PracticeDrills.drill(for: technique, variant: attempt)
        }.value
        guard let puzzle else { failedToGenerate = true; return }
        game = NumeriqoGame(puzzle: puzzle, difficulty: .steady)
    }
}
