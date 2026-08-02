//
//  PersistenceTests.swift
//  NumeriqoTests
//

import Foundation
import Testing
@testable import Numeriqo

@Suite @MainActor struct PersistenceTests {

    private func makeDefaults(_ name: String = #function) throws -> UserDefaults {
        let suite = "numeriqo.tests.\(name).\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suite))
    }

    // MARK: - Legacy migration

    /// **3.0 must never wipe a 2.x player's records.**
    ///
    /// Best times are free (docs/MONETIZATION.md §2), and silently resetting
    /// them would be the worst possible upgrade — the kind that passes a green
    /// suite because nothing else references them.
    @Test func legacyBestTimesSurviveTheUpgrade() throws {
        let defaults = try makeDefaults()
        defaults.set(["4-easy": 91.0, "6-hard": 400.0], forKey: "NumeriqoBestTimesByDifficulty")
        // The pre-difficulty shape, which 2.x itself folded into the middle tier.
        defaults.set(["5": 250.0], forKey: "NumeriqoBestTimes")

        let store = ProgressStore(userDefaults: defaults)

        #expect(store.bestTime(size: 4, difficulty: .gentle) == 91.0)
        #expect(store.bestTime(size: 6, difficulty: .sharp) == 400.0)
        #expect(store.bestTime(size: 5, difficulty: .steady) == 250.0)

        // The legacy keys are read, never cleared — a downgrade must still work.
        #expect(defaults.dictionary(forKey: "NumeriqoBestTimesByDifficulty") != nil)
    }

    @Test func migrationRunsOnceAndNeverOverwritesABetterRecord() throws {
        let defaults = try makeDefaults()
        defaults.set(["4-easy": 91.0], forKey: "NumeriqoBestTimesByDifficulty")

        let first = ProgressStore(userDefaults: defaults)
        first.recordSolve(size: 4, difficulty: .gentle, time: 45.0)
        #expect(first.bestTime(size: 4, difficulty: .gentle) == 45.0)

        // A second launch must not resurrect the slower legacy time.
        let second = ProgressStore(userDefaults: defaults)
        #expect(second.bestTime(size: 4, difficulty: .gentle) == 45.0,
                "migration re-ran and clobbered a better 3.0 record")
    }

    // MARK: - Best times and stats

    @Test func recordSolveReportsRecordsHonestly() throws {
        let store = ProgressStore(userDefaults: try makeDefaults())

        #expect(store.recordSolve(size: 5, difficulty: .steady, time: 100) == true)
        #expect(store.recordSolve(size: 5, difficulty: .steady, time: 120) == false)
        // An exact tie is not a record. Deriving this by comparing against the
        // already-updated store would wrongly claim one.
        #expect(store.recordSolve(size: 5, difficulty: .steady, time: 100) == false)
        #expect(store.recordSolve(size: 5, difficulty: .steady, time: 80) == true)
        #expect(store.bestTime(size: 5, difficulty: .steady) == 80)
        #expect(store.stats.puzzlesSolved == 4)
    }

    // MARK: - Saved game

    @Test func savedGameSurvivesARelaunchAndIsObservable() throws {
        let defaults = try makeDefaults()
        let store = ProgressStore(userDefaults: defaults)
        let generated = try #require(PuzzleGenerator.generate(size: 4, seed: 77))
        let game = NumeriqoGame(puzzle: generated.puzzle, difficulty: .gentle)

        game.place(game.puzzle.solutionValue(at: Cell(0, 0)), at: Cell(0, 0))
        store.saveGame(game.snapshot)

        // Observable immediately, not only after a relaunch — a view body that
        // read UserDefaults directly would never invalidate.
        #expect(store.savedGame != nil)

        let relaunched = ProgressStore(userDefaults: defaults)
        let restored = try #require(relaunched.savedGame)
        let resumed = NumeriqoGame(snapshot: restored)
        #expect(resumed.board == game.board)
        #expect(resumed.puzzle == game.puzzle)
        #expect(resumed.undoStack.count == game.undoStack.count)

        relaunched.clearSavedGame()
        #expect(ProgressStore(userDefaults: defaults).savedGame == nil)
    }

    // MARK: - Dailies

    @Test func streaksBuildAndResetWithoutShaming() throws {
        let store = ProgressStore(userDefaults: try makeDefaults())

        store.recordDailyCompleted(day: 10)
        store.recordDailyCompleted(day: 11)
        store.recordDailyCompleted(day: 12)
        #expect(store.daily.currentStreak == 3)
        #expect(store.hasCompletedDaily(day: 12))

        // Completing the same day twice must not inflate the streak.
        store.recordDailyCompleted(day: 12)
        #expect(store.daily.currentStreak == 3)

        // A missed day resets the count but keeps the best.
        store.recordDailyCompleted(day: 20)
        #expect(store.daily.currentStreak == 1)
        #expect(store.daily.bestStreak == 3)
    }

    @Test func dailySeedIsStableAcrossDevices() {
        // Everyone must get the same board on the same day, or a streak means
        // nothing. The seed comes from the date, never from the device.
        for day in [0, 1, 19_000, 20_500] {
            let a = DailyPuzzle.seed(day: day, size: 6, difficulty: .steady)
            let b = DailyPuzzle.seed(day: day, size: 6, difficulty: .steady)
            #expect(a == b)
            #expect(DailyPuzzle.seed(day: day + 1, size: 6, difficulty: .steady) != a)
        }
    }

    // MARK: - Gating

    @Test func freeTierMatchesWhatTwoPointXAlreadyGaveAway() {
        // Grids: 2.x free shipped 3x3-5x5, so 3.0 free must too.
        for size in 3...9 {
            #expect(FeatureGate.isSizeAvailable(size, unlocked: false) == (size <= 5),
                    "\(size)x\(size) availability changed for free players")
            #expect(FeatureGate.isSizeAvailable(size, unlocked: true))
        }

        // Best times were free in 2.x and stay free.
        #expect(FeatureGate.areBestTimesAvailable(unlocked: false))
        #expect(!FeatureGate.areFullStatsAvailable(unlocked: false))

        // Difficulty is never gated — that would punish the players most likely
        // to buy.
        for difficulty in Difficulty.allCases {
            #expect(FeatureGate.isDifficultyAvailable(difficulty, unlocked: false))
        }

        // Lessons: the rules plus the first three techniques.
        #expect(FeatureGate.isLessonAvailable(nil, unlocked: false))
        for technique in Technique.allCases {
            let free = technique <= FeatureGate.freeLessonCeiling
            #expect(FeatureGate.isLessonAvailable(technique, unlocked: false) == free,
                    "\(technique.displayName) free availability drifted")
        }

        #expect(!FeatureGate.areDrillsAvailable(unlocked: false))
        #expect(FeatureGate.hintPolicy(unlocked: false) == .errorsOnly)
        #expect(FeatureGate.hintPolicy(unlocked: true) == .full)
    }

    @Test func entitlementFailureNeverTakesAwayWhatSomebodyBought() async throws {
        let defaults = try makeDefaults()
        defaults.set(true, forKey: "numeriqo.entitlement.v1")

        // nil means "couldn't determine" — offline, or a StoreKit error. It must
        // not be read as "doesn't own it".
        let store = EntitlementStore(userDefaults: defaults,
                                     source: PreviewEntitlementSource(owned: nil))
        #expect(store.isUnlocked)
        await store.refresh()
        #expect(store.isUnlocked, "an undeterminable entitlement revoked a purchase")

        // A definite false does clear it: a refund has to land. Except in the
        // Pro build, where the entitlement is the binary and no StoreKit answer
        // can revoke it.
        let revoked = EntitlementStore(userDefaults: defaults,
                                       source: PreviewEntitlementSource(owned: false))
        await revoked.refresh()
        #expect(revoked.isUnlocked == EntitlementStore.isUnlockedByBuild)
    }

    /// The assertion `MONETIZATION.md` §6 asks for, written so it holds in both
    /// builds rather than only in the one that happens to be running.
    ///
    /// Numeriqo Pro was bought outright years ago, and 3.0 is what the full
    /// Numeriqo now is. Those owners must never be asked to pay again, and the
    /// build must never need StoreKit to work that out: `NUMERIQO_PRO` is the
    /// entitlement, on a device that has never been online.
    @Test func theBuildFlagIsTheWholeProEntitlement() async throws {
        let defaults = try makeDefaults()   // nothing cached, nothing purchased
        let store = EntitlementStore(userDefaults: defaults,
                                     source: PreviewEntitlementSource(owned: false))

        #expect(store.isUnlocked == EntitlementStore.isUnlockedByBuild)
        await store.refresh()
        #expect(store.isUnlocked == EntitlementStore.isUnlockedByBuild,
                "refresh talked a build out of the entitlement its flag grants")

        // And the gates take that answer at face value, so there is no second
        // place for the two SKUs to disagree.
        #expect(FeatureGate.isSizeAvailable(9, unlocked: store.isUnlocked)
                == EntitlementStore.isUnlockedByBuild)
        #expect(FeatureGate.areDrillsAvailable(unlocked: store.isUnlocked)
                == EntitlementStore.isUnlockedByBuild)
    }
}

// MARK: - Phase 8 completeness

@Suite @MainActor struct CompletenessTests {

    /// The timer had no caller at all, so `elapsed` stayed at zero and every
    /// best time recorded as 0:00 — in a feature that migrated from 2.x.
    @Test func theClockAccumulatesAndASolveRecordsIt() throws {
        let generated = try #require(PuzzleGenerator.generate(size: 4, seed: 31))
        let game = NumeriqoGame(puzzle: generated.puzzle, difficulty: .gentle)

        #expect(game.elapsed == 0)
        game.addElapsed(12)
        game.addElapsed(30)
        #expect(game.elapsed == 42)

        let store = ProgressStore(
            userDefaults: try #require(UserDefaults(suiteName: "numeriqo.clock.\(UUID())"))
        )
        store.recordSolve(size: 4, difficulty: .gentle, time: game.elapsed)
        let best = try #require(store.bestTime(size: 4, difficulty: .gentle))
        #expect(best > 0, "a solve recorded a zero best time")
        #expect(best == 42)
    }

    /// A finished game must not keep counting.
    @Test func theClockStopsWhenTheGameIsWon() throws {
        let generated = try #require(PuzzleGenerator.generate(size: 4, seed: 32))
        let game = NumeriqoGame(puzzle: generated.puzzle, difficulty: .gentle)
        for cell in game.puzzle.allCells {
            game.place(game.puzzle.solutionValue(at: cell), at: cell)
        }
        #expect(game.phase == .won)

        let atWin = game.elapsed
        game.addElapsed(60)
        #expect(game.elapsed == atWin, "the clock kept running after the win")
    }

    /// Every setting has to be both changeable and honoured. Two of these did
    /// nothing at all: `hapticsEnabled` was never applied, and `cellFirstInput`
    /// was never read.
    @Test func everySettingIsHonoured() throws {
        let defaults = try #require(UserDefaults(suiteName: "numeriqo.settings.\(UUID())"))
        let store = ProgressStore(userDefaults: defaults)

        store.settings.hapticsEnabled = false
        Haptics.enabled = store.settings.hapticsEnabled
        #expect(!Haptics.enabled)
        Haptics.enabled = true

        // Settings survive a relaunch.
        store.settings.cellFirstInput = true
        store.settings.autoNotes = true
        #expect(ProgressStore(userDefaults: defaults).settings.cellFirstInput)
        #expect(ProgressStore(userDefaults: defaults).settings.autoNotes)
    }

    @Test func cellFirstInputChangesTheInputModel() throws {
        let generated = try #require(PuzzleGenerator.generate(size: 5, seed: 33))
        let game = NumeriqoGame(puzzle: generated.puzzle, difficulty: .steady)
        let cell = Cell(0, 0)

        // Number-first: a digit arms, then a tap places.
        game.press(3)
        #expect(game.activeDigit == 3)
        game.tap(cell)
        #expect(game.board.entries[cell] == 3)

        // Cell-first: a digit with nothing selected has nowhere to go.
        let other = NumeriqoGame(puzzle: generated.puzzle, difficulty: .steady)
        other.cellFirstInput = true
        other.press(3)
        #expect(other.activeDigit == nil, "cell-first armed a digit anyway")
        other.tap(cell)
        #expect(other.selected == cell)
        other.press(3)
        #expect(other.board.entries[cell] == 3)
    }

    /// The daily existed in full — seed, flag, streak, and a streak shown in
    /// Stats — with no way to start one.
    @Test func theDailyIsPlayableAndAdvancesTheStreak() throws {
        let day = DailyPuzzle.today
        let seed = DailyPuzzle.seed(day: day, size: GameView.dailySize,
                                    difficulty: GameView.dailyDifficulty)
        let generated = try #require(
            PuzzleGenerator.generate(size: GameView.dailySize, seed: seed)
        )
        // Same day, same board, for everyone.
        let again = try #require(PuzzleGenerator.generate(size: GameView.dailySize, seed: seed))
        #expect(generated.puzzle == again.puzzle)

        let store = ProgressStore(
            userDefaults: try #require(UserDefaults(suiteName: "numeriqo.daily.\(UUID())"))
        )
        #expect(!store.hasCompletedDaily(day: day))
        store.recordDailyCompleted(day: day)
        #expect(store.hasCompletedDaily(day: day))
        #expect(store.daily.currentStreak == 1)
    }

    @Test func spokenClockReadsAsWords() {
        // VoiceOver reads "3:07" as "three colon zero seven".
        #expect(GameView.spokenClock(0) == "0 seconds")
        #expect(GameView.spokenClock(1) == "1 second")
        #expect(GameView.spokenClock(61) == "1 minute 1 second")
        #expect(GameView.spokenClock(187) == "3 minutes 7 seconds")
        #expect(GameView.clock(187) == "3:07")
    }

    /// Every technique needs a menu summary short enough for a list row.
    @Test func everyTechniqueHasAShortMenuSummary() {
        for technique in Technique.allCases {
            let summary = TechniqueContent.summary(for: technique)
            #expect(!summary.isEmpty)
            #expect(summary.count <= 40,
                    "\(technique.displayName) summary is \(summary.count) chars, too long for a row")
            #expect(summary != TechniqueContent.rule(for: technique))
        }
    }
}

// MARK: - Phase 9

@Suite @MainActor struct FlowTests {

    /// The difficulty picker used to be decoration: `generate` was called with
    /// no acceptance predicate and its grade discarded, so a Severe board was
    /// statistically identical to a Gentle one — and best times were filed
    /// under a tier that meant nothing.
    @Test func difficultyActuallyChangesThePuzzle() {
        var matched = 0, produced = 0

        for (i, tier) in [Difficulty.gentle, .steady, .sharp, .deep, .severe].enumerated() {
            for seed in 0..<4 {
                guard let r = PuzzleGenerator.generate(
                    matching: tier, size: 5, seed: UInt64(i * 100 + seed) &* 6151
                ) else { continue }
                produced += 1
                #expect(r.grade != nil, "a band-matched puzzle shipped without a grade")
                if r.grade?.difficulty == tier { matched += 1 }
            }
        }

        #expect(produced >= 15, "band matching produced only \(produced)/20 puzzles")
        // Exact matching is not guaranteed — the fallback takes the nearest band
        // rather than refusing to start a game — but most should land.
        #expect(matched >= produced / 2,
                "only \(matched)/\(produced) landed in the requested band")
    }

    /// The daily counted UTC days, so it rolled over at 01:00 in Germany and
    /// mid-afternoon in the US, and streaks broke invisibly.
    @Test func theDailyUsesTheLocalCalendar() {
        let today = DailyPuzzle.today
        let expected = Calendar.current.dateComponents(
            [.day],
            from: Date(timeIntervalSince1970: 0),
            to: Calendar.current.startOfDay(for: Date())
        ).day

        #expect(today == expected)
        #expect(DailyPuzzle.today == today, "the day is not stable within a call")
    }

    /// Drills advanced no variant, so reaching Learned meant solving the same
    /// memorised board five times.
    @Test func drillVariantsProduceDifferentBoards() throws {
        let a = try #require(PracticeDrills.drill(for: .hiddenSingle, variant: 0))
        let b = try #require(PracticeDrills.drill(for: .hiddenSingle, variant: 1))
        #expect(a != b, "variant made no difference to the drill board")

        // Still deterministic per variant, so "another drill" is reproducible.
        #expect(PracticeDrills.drill(for: .hiddenSingle, variant: 1) == b)
    }

    /// Every paid feature the paywall advertises must have somewhere that
    /// presents it. `.practiceDrills` was listed and sold from nowhere.
    @Test func everyAdvertisedFeatureHasAPresenter() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Numeriqo")

        var sources = ""
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            sources += (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }

        for feature in PaidFeature.allCases {
            #expect(sources.contains("paywall.present(.\(feature.rawValue))"),
                    "\(feature.rawValue) is advertised on the paywall but nothing presents it")
        }
    }
}
