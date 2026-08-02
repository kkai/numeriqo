//
//  HintEngine.swift
//  Numeriqo
//
//  The four-level ladder. See docs/TEACHING.md §3.
//
//  Level 3 is the destination — the player sees the whole argument drawn and
//  still makes the placement themselves. Level 4 exists without shame but should
//  feel like a small surrender.
//

import Foundation

nonisolated enum HintLevel: Int, Comparable, Sendable, Codable {
    case nudge, technique, highlight, resolution

    static func < (lhs: HintLevel, rhs: HintLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    var next: HintLevel { HintLevel(rawValue: rawValue + 1) ?? .resolution }
}

nonisolated struct Hint: Sendable, Equatable {
    let level: HintLevel
    let step: TechniqueApplication?
    let text: String
    /// Cells to spotlight. Empty below `.highlight` — naming a region is the
    /// whole point of the early rungs, and marking cells gives it away.
    let focusCells: [Cell]
    /// Pointing at a mistake rather than teaching. Errors take priority.
    var isError = false
    /// Withheld behind the unlock.
    var isLocked = false

    /// Whether the drawn argument should run. Gated so level 1 stays a nudge.
    var showsArgument: Bool { level >= .highlight && !isError && !isLocked }
}

nonisolated enum HintPolicy: Sendable { case errorsOnly, full }

@MainActor
struct HintEngine {

    /// The first rung. Errors beat teaching: building on a wrong digit wastes
    /// everything that follows.
    func hint(
        for game: NumeriqoGame,
        mastery: MasteryTracker? = nil,
        showErrors: Bool = true,
        policy: HintPolicy = .full
    ) -> Hint {
        if showErrors, let error = errorHint(for: game, level: .nudge) { return error }

        guard let step = game.nextStep() else {
            return Hint(level: .nudge, step: nil,
                        text: TechniqueContent.nothingToFind, focusCells: [])
        }

        guard policy == .full else {
            // Deliberately without recordHint: penalising mastery for a hint the
            // player never saw would silently damage their progress path the
            // moment they later pay.
            return Hint(level: .nudge, step: step,
                        text: TechniqueContent.withheld, focusCells: [], isLocked: true)
        }

        mastery?.recordHint(technique: step.technique, level: .nudge)
        return Hint(level: .nudge, step: step,
                    text: TechniqueContent.nudge(for: step, puzzle: game.puzzle),
                    focusCells: [])
    }

    /// The next rung.
    ///
    /// Stateless recomputation from the stored step rather than a cursor, so a
    /// hint can be re-rendered at any level without re-running the solver.
    func escalate(
        _ hint: Hint,
        for game: NumeriqoGame,
        mastery: MasteryTracker? = nil,
        policy: HintPolicy = .full
    ) -> Hint {
        guard policy == .full, !hint.isLocked else { return hint }
        guard hint.level < .resolution else { return hint }

        let level = hint.level.next

        if hint.isError { return errorHint(for: game, level: level) ?? hint }
        guard let step = hint.step else { return hint }

        mastery?.recordHint(technique: step.technique, level: level)

        let text: String
        switch level {
        case .nudge: text = hint.text
        case .technique: text = TechniqueContent.rule(for: step.technique)
        case .highlight: text = TechniqueContent.detail(for: step, puzzle: game.puzzle)
        case .resolution: text = TechniqueContent.resolution(for: step, puzzle: game.puzzle)
        }

        return Hint(level: level, step: step, text: text,
                    focusCells: level >= .highlight ? step.focusCells : [])
    }

    // MARK: - Errors

    /// Narrows from "something is wrong" to the exact cell.
    private func errorHint(for game: NumeriqoGame, level: HintLevel) -> Hint? {
        let wrong = game.incorrectCells.sorted()
        guard !wrong.isEmpty else { return nil }

        return Hint(
            level: level,
            step: nil,
            text: TechniqueContent.wrongDigit(count: wrong.count),
            focusCells: level >= .highlight ? Array(wrong.prefix(level >= .resolution ? 1 : wrong.count)) : [],
            isError: true
        )
    }
}
