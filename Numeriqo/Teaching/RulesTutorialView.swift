//
//  RulesTutorialView.swift
//  Numeriqo
//
//  The first-run tutorial. All of the teaching lives in TutorialScript; this
//  file is the shell that renders a step and forwards input to the engine.
//
//  It never touches the game directly — `engine.displayGame` is read to draw
//  the board, and every tap and digit goes through `engine`. See the note at
//  the top of TutorialScript.swift for why that separation is load-bearing.
//

import SwiftUI

struct RulesTutorialView: View {
    /// What to do when the player finishes. Popping merely returned them to the
    /// Learn list — a button labelled "Start playing" that landed on a list of
    /// padlocks.
    var onFinish: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var engine = TutorialEngine()

    var body: some View {
        // The middle scrolls, the footer does not.
        //
        // This screen had no ScrollView and was pinned to the top, so on a small
        // phone or at large Dynamic Type the instruction card, the board and the
        // pad pushed the button off the bottom with no way to reach it — which
        // made the tutorial unfinishable, on the one screen a new player cannot
        // skip. The footer stays outside the ScrollView because "Next" is the
        // only way forward and must never need scrolling to.
        VStack(spacing: Layout.Space.step) {
            header
            ScrollView {
                VStack(spacing: Layout.Space.step) {
                    instruction
                    board
                    if engine.showsPad {
                        NumberPadView(
                            game: engine.displayGame,
                            onDigit: { engine.handleDigit($0) },
                            onUndo: { engine.handleUndo() },
                            onErase: { engine.handleErase() },
                            showsNotes: false
                        )
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .padding(Layout.Space.gutter)
        .animation(reduceMotion ? nil : Motion.noteFlip, value: engine.index)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            if !engine.isFirstStep {
                // Not "Back": the navigation bar already has one, and that one
                // leaves the tutorial. Two controls a thumb's width apart doing
                // opposite things is a trap.
                Button("Previous step") { engine.goBack() }.buttonStyle(.quiet)
            }
            Spacer()
            Text("Step \(engine.stepNumber) of \(engine.stepCount)")
                .font(Theme.steady(.caption))
                .foregroundStyle(Theme.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Instruction

    /// The one thing the player is meant to read right now, plus whatever the
    /// engine said about their last input. Both live in the same card so a
    /// rejection appears where the player is already looking.
    private var instruction: some View {
        VStack(alignment: .leading, spacing: Layout.Space.snug) {
            Text(engine.step.message)
                .font(Theme.body)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if let feedback = engine.feedback {
                Text(feedback)
                    .font(Theme.secondary.weight(.medium))
                    .foregroundStyle(Theme.error)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        // Announced rather than merely drawn: on VoiceOver a step that changes
        // silently reads as the board having ignored the input.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Board

    private var board: some View {
        BoardView(
            game: engine.displayGame,
            highlight: engine.highlight,
            onTap: { engine.handleTap($0) }
        )
        // A definite height, not a maximum. `BoardView` is a GeometryReader,
        // which has no ideal size, so inside a ScrollView's unbounded vertical
        // proposal a `maxHeight` leaves it to collapse.
        .frame(height: 300)
        // The shake is the whole reply to a refused tap on a locked board.
        // Without it the tutorial looks broken rather than strict.
        .modifier(ShakeEffect(travel: CGFloat(engine.rejections)))
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.5),
                   value: engine.rejections)
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        if engine.isFinished {
            Button("Start playing") {
                if let onFinish { onFinish() } else { dismiss() }
            }
            .buttonStyle(.primary(tint: Theme.tierAccent(.gentle)))
        } else if engine.canAdvance {
            Button("Next") { engine.advance() }
                .buttonStyle(.primary(tint: Theme.tierAccent(.gentle)))
        } else {
            // No Next on an interactive step: the step advances itself when the
            // player does the thing, and a skip button would make the doing
            // optional — which is how the last tutorial ended up teaching
            // nothing.
            Text("Your turn")
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .frame(maxWidth: .infinity, minHeight: Layout.minimumTarget + 8)
        }
    }
}

/// A horizontal shake, driven by a counter rather than a bool so that two
/// refusals in a row each get their own shake.
private struct ShakeEffect: GeometryEffect {
    var travel: CGFloat

    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: 6 * sin(travel * .pi * 2), y: 0)
        )
    }
}
