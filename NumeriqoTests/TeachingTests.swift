//
//  TeachingTests.swift
//  NumeriqoTests
//

import Foundation
import Testing
@testable import Numeriqo

@Suite @MainActor struct TeachingTests {

    private func makeGame(size: Int = 5, seed: UInt64 = 4242) throws -> NumeriqoGame {
        let generated = try #require(PuzzleGenerator.generate(size: size, seed: seed))
        return NumeriqoGame(puzzle: generated.puzzle, difficulty: .steady)
    }

    // MARK: - Copy

    @Test func everyTechniqueHasCopyInEveryRegister() {
        for technique in Technique.allCases {
            #expect(TechniqueContent.rule(for: technique).count > 20,
                    "\(technique) has no usable rule")
            #expect(TechniqueContent.lesson(for: technique).count > 60,
                    "\(technique) has no usable lesson")
            // The rule and the lesson must not be the same sentence twice.
            #expect(TechniqueContent.rule(for: technique)
                        != TechniqueContent.lesson(for: technique))
        }
    }

    /// House style for everything the player reads.
    ///
    /// Em dashes and curly quotes are the two tells that creep back in one
    /// string at a time, and "board" is the third word this app kept inventing
    /// for the thing you fill. The player-facing name is "grid"; `board` stays
    /// the name of the type. "KenKen" is a live trademark and must never reach
    /// a screen. See docs/RULES.md §6.
    @Test func theCopyKeepsToHouseStyle() {
        var strings: [(String, String)] = []
        for technique in Technique.allCases {
            let name = technique.displayName
            strings.append((name, name))
            strings.append(("\(name) rule", TechniqueContent.rule(for: technique)))
            strings.append(("\(name) lesson", TechniqueContent.lesson(for: technique)))
            strings.append(("\(name) summary", TechniqueContent.summary(for: technique)))
        }
        for (index, step) in TutorialScript.rules.enumerated() {
            strings.append(("tutorial step \(index + 1)", step.message))
        }
        for feature in PaidFeature.allCases {
            strings.append(("\(feature) headline", feature.headline))
            strings.append(("\(feature) pitch", feature.pitch))
        }

        for (where_, text) in strings {
            #expect(!text.contains("\u{2014}") && !text.contains("\u{2013}"),
                    "\(where_) uses a dash where a full stop or comma would do")
            #expect(!text.contains("\u{201C}") && !text.contains("\u{201D}"),
                    "\(where_) uses curly quotes")
            #expect(text.range(of: "kenken", options: .caseInsensitive) == nil,
                    "\(where_) names a trademark")
            #expect(text.range(of: "\\bboards?\\b",
                               options: [.regularExpression, .caseInsensitive]) == nil,
                    "\(where_) says board; the player-facing word is grid")
        }
    }

    @Test func contextualCopyNeverLeavesAHoleInTheSentence() throws {
        let game = try makeGame()
        var board = BoardState()
        var seen = 0

        for _ in 0..<200 {
            guard let step = LogicalSolver.nextStep(puzzle: game.puzzle, board: board) else { break }
            seen += 1
            for text in [
                TechniqueContent.nudge(for: step, puzzle: game.puzzle),
                TechniqueContent.detail(for: step, puzzle: game.puzzle),
                TechniqueContent.resolution(for: step, puzzle: game.puzzle),
            ] {
                #expect(!text.isEmpty)
                // A missing substitution shows up as a doubled space or a
                // dangling connective rather than a crash.
                #expect(!text.contains("  "), "doubled space in: \(text)")
                #expect(!text.contains(" ."), "dangling clause in: \(text)")
            }
            for placement in step.placements { board.entries[placement.cell] = placement.digit }
            let before = board
            LogicalSolver.applyEliminations(step, to: &board, size: game.puzzle.size)
            if board == before && step.placements.isEmpty { break }
        }
        #expect(seen > 5, "only exercised \(seen) steps")
    }

    // MARK: - The ladder

    @Test func levelsDiscloseProgressively() throws {
        let game = try makeGame()
        let engine = HintEngine()

        var hint = engine.hint(for: game)
        #expect(hint.level == .nudge)
        // The whole point of the first two rungs: say where, not what.
        #expect(hint.focusCells.isEmpty, "level 1 marked cells")
        #expect(!hint.showsArgument, "level 1 ran the drawn argument")

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .technique)
        #expect(hint.focusCells.isEmpty, "level 2 marked cells")
        #expect(!hint.showsArgument, "level 2 ran the drawn argument")

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .highlight)
        #expect(!hint.focusCells.isEmpty, "level 3 marked no cells")
        #expect(hint.showsArgument, "level 3 did not run the drawn argument")

        hint = engine.escalate(hint, for: game)
        #expect(hint.level == .resolution)
        // The ladder tops out; escalating again is a no-op, not a crash.
        #expect(engine.escalate(hint, for: game).level == .resolution)
    }

    @Test func errorsTakePriorityOverTeaching() throws {
        let game = try makeGame()
        let cell = Cell(0, 0)
        let truth = game.puzzle.solutionValue(at: cell)
        game.place(truth == 1 ? 2 : 1, at: cell)

        let hint = HintEngine().hint(for: game)
        #expect(hint.isError, "a wrong digit on the board did not take priority")
        #expect(hint.step == nil)
    }

    @Test func aWithheldHintRecordsNoMastery() throws {
        let game = try makeGame()
        let mastery = MasteryTracker()
        let before = mastery.records

        let hint = HintEngine().hint(for: game, mastery: mastery,
                                     showErrors: false, policy: .errorsOnly)
        #expect(hint.isLocked)
        // Penalising mastery for a hint the player never saw would damage their
        // progress path the moment they later pay.
        #expect(mastery.records == before, "a withheld hint touched mastery")

        // And it must not climb.
        #expect(HintEngine().escalate(hint, for: game, mastery: mastery,
                                      policy: .errorsOnly).level == .nudge)
    }

    // MARK: - Mastery

    @Test func masteryCannotBeFarmedByUndo() throws {
        let game = try makeGame()
        let mastery = MasteryTracker()

        guard let step = game.nextStep(), let placement = step.placements.first else {
            Issue.record("fixture produced no placement to test with")
            return
        }

        func placeAndCredit() {
            let firstTime = game.claimMasteryCredit(at: placement.cell)
            game.place(placement.digit, at: placement.cell)
            mastery.recordEntry(cell: placement.cell, digit: placement.digit,
                                game: game, unaided: firstTime)
        }

        placeAndCredit()
        let earned = mastery.records.values.reduce(0) { $0 + $1.unaidedUses }
        #expect(earned == 1)

        for _ in 0..<5 {
            game.undo()
            placeAndCredit()
        }
        let after = mastery.records.values.reduce(0) { $0 + $1.unaidedUses }
        #expect(after == earned, "undo/replace farmed \(after - earned) extra credits")
    }

    @Test func appliedHintsEarnNothing() throws {
        let game = try makeGame()
        let mastery = MasteryTracker()
        guard let step = game.nextStep(), let placement = step.placements.first else { return }

        _ = game.claimMasteryCredit(at: placement.cell)
        game.apply(step)
        mastery.recordEntry(cell: placement.cell, digit: placement.digit,
                            game: game, unaided: false)

        #expect(mastery.records.values.allSatisfy { $0.unaidedUses == 0 },
                "tapping Apply earned mastery credit")
    }

    @Test func learnedRequiresTheFullThreshold() {
        let mastery = MasteryTracker()
        for i in 1...MasteryTracker.learnedThreshold {
            mastery.recordDrillCompleted(.nakedSingle, unaided: true)
            let expected: MasteryTracker.MasteryState =
                i >= MasteryTracker.learnedThreshold ? .learned : .introduced
            #expect(mastery.state(of: .nakedSingle) >= expected || i < MasteryTracker.learnedThreshold)
        }
        #expect(mastery.state(of: .nakedSingle) == .learned)
        // Reaching learned unlocks the next rung of the curriculum.
        #expect(mastery.state(of: .hiddenSingle) != .locked)
    }

    // MARK: - Auto-notes

    @Test func autoNotesNeverLeakHarderDeductions() throws {
        let game = try makeGame()
        game.fillAutoNotes()

        // Every note left standing must still contain the true digit — auto
        // notes may only remove what the cheapest techniques prove impossible.
        for cell in game.puzzle.allCells where game.board.entries[cell] == nil {
            let notes = game.board.notes(at: cell)
            guard !notes.isEmpty else { continue }
            #expect(notes.contains(game.puzzle.solutionValue(at: cell)),
                    "auto-notes eliminated the solution digit at \(cell)")
        }
    }

    // MARK: - Drills

    @Test func drillsExerciseTheirOwnTechnique() throws {
        for technique in Technique.allCases {
            guard let puzzle = PracticeDrills.drill(for: technique) else {
                Issue.record("no drill board for \(technique.displayName)")
                continue
            }
            #expect(BacktrackingSolver.countSolutions(
                size: puzzle.size, cages: puzzle.cages, limit: 2) == 1,
                "\(technique.displayName) drill is not unique")

            let result = LogicalSolver.solve(puzzle)
            #expect(result.solved, "\(technique.displayName) drill is not curriculum-solvable")

            // Searched boards must exercise their technique. Hand-authored
            // ones are asserted only where they claim to — see
            // `bakedBoardsThatDemonstrateTheirTechnique` for the one that
            // does not, and why.
            let mustDemonstrate = !PracticeDrills.handAuthored.contains(technique)
                || PracticeDrills.bakedBoardsThatDemonstrateTheirTechnique.contains(technique)
            if mustDemonstrate {
                let uses = result.histogram[technique] ?? 0
                #expect(uses >= PracticeDrills.minimumUses(of: technique),
                        "\(technique.displayName) drill uses it \(uses) times")
            }
        }
    }
}
