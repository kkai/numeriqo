//
//  MasteryTracker.swift
//  Numeriqo
//
//  How well the player knows each technique. Unaided applications advance
//  mastery; hints do not.
//
//  The stat that proves this app works is hints-taken trending down, so what
//  counts as "unaided" has to be honest. Everything awkward in this file exists
//  to keep "Learned" meaning something.
//

import Foundation
import Observation

@Observable @MainActor
final class MasteryTracker {

    enum MasteryState: String, Codable, Comparable, Sendable {
        case locked, introduced, practicing, learned

        private var order: Int {
            switch self {
            case .locked: 0
            case .introduced: 1
            case .practicing: 2
            case .learned: 3
            }
        }

        static func < (lhs: MasteryState, rhs: MasteryState) -> Bool { lhs.order < rhs.order }
    }

    struct Record: Codable, Equatable, Sendable {
        var state: MasteryState = .locked
        var unaidedUses = 0
        var hintedUses = 0
        var drillsCompleted = 0
        var lessonCompleted = false
    }

    /// Unaided applications needed to reach `.learned`.
    static let learnedThreshold = 5

    private(set) var records: [Technique: Record] = [:]
    private let store: ProgressStore?

    init(store: ProgressStore? = nil) {
        self.store = store
        if let saved = store?.loadMastery([Technique: Record].self), !saved.isEmpty {
            records = saved
        } else {
            // The first two techniques start available; the rest unlock in order.
            records[.freebieCage] = Record(state: .introduced)
            records[.divisibility] = Record(state: .introduced)
        }
    }

    func record(for technique: Technique) -> Record { records[technique] ?? Record() }
    func state(of technique: Technique) -> MasteryState { record(for: technique).state }

    // MARK: - Events

    /// The player asked for a hint.
    ///
    /// Only counts from `.highlight` up: a nudge that names nothing costs
    /// nothing. Callers must not invoke this for a *withheld* hint — see
    /// `HintEngine.hint(for:mastery:showErrors:policy:)`.
    func recordHint(technique: Technique, level: HintLevel) {
        var rec = record(for: technique)
        if rec.state == .locked { rec.state = .introduced }
        if level >= .highlight { rec.hintedUses += 1 }
        records[technique] = rec
        persist()
    }

    /// The player made an entry. If it matches the deduction the solver was
    /// about to make, that counts as applying the technique.
    ///
    /// `unaided` is the **caller's** to declare, not something this can infer: a
    /// digit placed by tapping Apply is indistinguishable here from one the
    /// player reasoned out. Passing it wrongly is exactly how a technique
    /// reaches "Learned" for somebody who never applied it.
    func recordEntry(cell: Cell, digit: Int, game: NumeriqoGame, unaided: Bool) {
        guard unaided else { return }
        guard game.puzzle.solutionValue(at: cell) == digit,
              let previous = game.boardBeforeLastMove,
              previous.entries[cell] == nil
        else { return }

        // Replay the solver forward from the *pre-move* board. Elimination steps
        // change no entries, so walk past them to the placement they enable,
        // remembering what they cost: the player who placed this digit had to do
        // every deduction in that chain.
        var board = previous
        var chain: [Technique] = []

        for _ in 0..<32 {
            guard let step = LogicalSolver.nextStep(puzzle: game.puzzle, board: board) else { return }
            chain.append(step.technique)

            if step.placements.contains(where: { $0.cell == cell && $0.digit == digit }) {
                // Credit the hardest link — the binding constraint — ranked by
                // *solving cost*, not curriculum position. `nakedSingle` is
                // taught late but is the trivial "one candidate left" step, so
                // ordering by rawValue would credit it over the elimination work
                // that actually earned the placement. This is also what lets
                // elimination-only techniques be learned through play at all.
                let hardest = chain.max {
                    DifficultyRater.weight(for: $0) < DifficultyRater.weight(for: $1)
                }
                advance(hardest ?? step.technique)
                return
            }

            // The next placement isn't the player's, so this was a guess or an
            // out-of-order entry. No credit.
            guard step.placements.isEmpty else { return }

            let before = board
            LogicalSolver.applyEliminations(step, to: &board, size: game.puzzle.size)
            if board == before { return }
        }
    }

    func recordLessonCompleted(_ technique: Technique) {
        var rec = record(for: technique)
        rec.lessonCompleted = true
        if rec.state < .practicing { rec.state = .practicing }
        records[technique] = rec
        unlockNext(after: technique)
        persist()
    }

    func recordDrillCompleted(_ technique: Technique, unaided: Bool) {
        var rec = record(for: technique)
        rec.drillsCompleted += 1
        if unaided { rec.unaidedUses += 1 }
        records[technique] = rec
        promoteIfEarned(technique)
        persist()
    }

    // MARK: - Progression

    private func advance(_ technique: Technique) {
        var rec = record(for: technique)
        rec.unaidedUses += 1
        if rec.state == .locked { rec.state = .introduced }
        records[technique] = rec
        promoteIfEarned(technique)
        persist()
    }

    private func promoteIfEarned(_ technique: Technique) {
        var rec = record(for: technique)
        guard rec.unaidedUses >= Self.learnedThreshold, rec.state < .learned else { return }
        rec.state = .learned
        records[technique] = rec
        unlockNext(after: technique)
    }

    /// Fires on both `.learned` and lesson completion, so the path can be
    /// advanced by playing or by reading.
    private func unlockNext(after technique: Technique) {
        guard let next = Technique(rawValue: technique.rawValue + 1) else { return }
        var rec = record(for: next)
        guard rec.state == .locked else { return }
        rec.state = .introduced
        records[next] = rec
    }

    private func persist() { store?.saveMastery(records) }
}
