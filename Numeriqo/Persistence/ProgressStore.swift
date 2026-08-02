//
//  ProgressStore.swift
//  Numeriqo
//
//  Everything persisted: settings, best times, stats, streaks, mastery, and the
//  in-progress game. UserDefaults + Codable behind versioned keys.
//
//  One key per domain rather than a single blob, so a schema break in one place
//  doesn't take the others down with it.
//

import Foundation
import Observation

@Observable @MainActor
final class ProgressStore {
    private let defaults: UserDefaults

    private enum Key {
        static let bestTimes = "numeriqo.bestTimes.v1"
        static let saveGame = "numeriqo.saveGame.v1"
        static let stats = "numeriqo.stats.v1"
        static let mastery = "numeriqo.mastery.v1"
        static let settings = "numeriqo.settings.v1"
        static let lastPlayed = "numeriqo.lastPlayed.v1"
        static let daily = "numeriqo.daily.v1"
        /// Written once, after legacy records are folded in.
        static let legacyMigrated = "numeriqo.legacyMigrated.v1"
    }

    /// Keys written by Numeriqo 2.x's `BestTimesManager`. Read once, never
    /// written — see `migrateLegacyBestTimes`.
    private enum LegacyKey {
        static let bestTimes = "NumeriqoBestTimes"
        static let bestTimesByDifficulty = "NumeriqoBestTimesByDifficulty"
    }

    struct GameChoice: Codable, Hashable, Sendable {
        let size: Int
        let difficulty: Difficulty
    }

    struct Settings: Codable, Equatable, Sendable {
        var autoNotes = false
        var hapticsEnabled = true
        /// Immediate error feedback, compared against the solution. Default on:
        /// see docs/TEACHING.md §6 — feedback latency is what makes a mistake
        /// attributable to the inference that caused it.
        var showErrors = true
        /// Cell-first input for players who prefer it. Number-first teaches
        /// scanning, so it is the default.
        var cellFirstInput = false
    }

    struct Stats: Codable, Equatable, Sendable {
        var puzzlesSolved = 0
        var totalPlayTime: TimeInterval = 0
        var solvedBySize: [Int: Int] = [:]
        var solvedByDifficulty: [Difficulty: Int] = [:]
        /// Hints taken per difficulty. The number that should go *down* — it is
        /// the evidence the teaching works, so it is worth surfacing.
        var hintsByDifficulty: [Difficulty: Int] = [:]
    }

    struct BestTimeKey: Hashable, Codable, Sendable {
        let size: Int
        let difficulty: Difficulty
    }

    struct DailyRecord: Codable, Equatable, Sendable {
        /// Days-since-epoch of the most recently completed daily.
        var lastCompletedDay: Int = -1
        var currentStreak = 0
        var bestStreak = 0
    }

    private(set) var bestTimes: [BestTimeKey: TimeInterval] = [:]
    private(set) var stats = Stats()
    private(set) var daily = DailyRecord()
    private(set) var lastPlayed: GameChoice?

    /// Mirrors the persisted save. Held as observable state rather than re-read
    /// on demand: a view body calling `defaults.object(forKey:)` never
    /// invalidates, so a Continue card would not appear until relaunch.
    private(set) var savedGame: GameSnapshot?

    var settings = Settings() {
        didSet { save(settings, key: Key.settings) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        bestTimes = load([BestTimeKey: TimeInterval].self, key: Key.bestTimes) ?? [:]
        stats = load(Stats.self, key: Key.stats) ?? Stats()
        settings = load(Settings.self, key: Key.settings) ?? Settings()
        daily = load(DailyRecord.self, key: Key.daily) ?? DailyRecord()
        savedGame = load(GameSnapshot.self, key: Key.saveGame)
        lastPlayed = load(GameChoice.self, key: Key.lastPlayed)
        migrateLegacyBestTimes()
    }

    // MARK: - Legacy migration

    /// Folds Numeriqo 2.x best times into the 3.0 store.
    ///
    /// **3.0 never removes something 2.x gave away.** Best times are free
    /// (docs/MONETIZATION.md §2), and silently resetting every existing
    /// player's records would be the worst possible upgrade — so this reads the
    /// old keys and leaves them in place.
    ///
    /// 2.x stored two shapes: a pre-difficulty `[String: Double]` keyed by grid
    /// size, and a later `[String: Double]` keyed `"<size>-<difficulty>"`. The
    /// older one was itself migrated into the medium tier by `BestTimesManager`,
    /// so it is folded in the same way here.
    private func migrateLegacyBestTimes() {
        guard !defaults.bool(forKey: Key.legacyMigrated) else { return }
        defer { defaults.set(true, forKey: Key.legacyMigrated) }

        func keep(_ key: BestTimeKey, _ time: TimeInterval) {
            guard time > 0 else { return }
            // Never overwrite a better 3.0 record with a legacy one.
            if let existing = bestTimes[key], existing <= time { return }
            bestTimes[key] = time
        }

        if let byDifficulty = defaults.dictionary(forKey: LegacyKey.bestTimesByDifficulty)
            as? [String: Double] {
            for (raw, time) in byDifficulty {
                let parts = raw.split(separator: "-")
                guard parts.count == 2,
                      let size = Int(parts[0]),
                      let difficulty = legacyDifficulty(String(parts[1]))
                else { continue }
                keep(BestTimeKey(size: size, difficulty: difficulty), time)
            }
        }

        if let bySize = defaults.dictionary(forKey: LegacyKey.bestTimes) as? [String: Double] {
            for (raw, time) in bySize {
                guard let size = Int(raw) else { continue }
                // Pre-difficulty records land in the middle tier, matching what
                // 2.x's own one-time migration did.
                keep(BestTimeKey(size: size, difficulty: .steady), time)
            }
        }

        if !bestTimes.isEmpty { save(bestTimes, key: Key.bestTimes) }
    }

    /// 2.x had three tiers; 3.0 has five. Map onto the nearest.
    private func legacyDifficulty(_ raw: String) -> Difficulty? {
        switch raw.lowercased() {
        case "easy": .gentle
        case "medium": .steady
        case "hard": .sharp
        default: Difficulty(rawValue: raw.lowercased())
        }
    }

    // MARK: - Best times and stats

    func bestTime(size: Int, difficulty: Difficulty) -> TimeInterval? {
        bestTimes[BestTimeKey(size: size, difficulty: difficulty)]
    }

    /// Records a solve. Returns true when it is a new best.
    ///
    /// The caller should use this return value rather than re-deriving it by
    /// comparing against a store that has already been updated — on an exact
    /// tie that comparison claims a record that was never written.
    @discardableResult
    func recordSolve(size: Int, difficulty: Difficulty, time: TimeInterval) -> Bool {
        stats.puzzlesSolved += 1
        stats.totalPlayTime += time
        stats.solvedBySize[size, default: 0] += 1
        stats.solvedByDifficulty[difficulty, default: 0] += 1
        save(stats, key: Key.stats)

        let key = BestTimeKey(size: size, difficulty: difficulty)
        let isRecord = bestTimes[key].map { time < $0 } ?? true
        if isRecord {
            bestTimes[key] = time
            save(bestTimes, key: Key.bestTimes)
        }
        return isRecord
    }

    func recordHintTaken(difficulty: Difficulty) {
        stats.hintsByDifficulty[difficulty, default: 0] += 1
        save(stats, key: Key.stats)
    }

    func recordLastPlayed(size: Int, difficulty: Difficulty) {
        let choice = GameChoice(size: size, difficulty: difficulty)
        guard choice != lastPlayed else { return }
        lastPlayed = choice
        save(choice, key: Key.lastPlayed)
    }

    // MARK: - Dailies

    /// Records today's daily as solved and updates the streak.
    ///
    /// A missed day resets the count but keeps the best — the streak dims, it
    /// does not shame.
    func recordDailyCompleted(day: Int) {
        guard day != daily.lastCompletedDay else { return }
        daily.currentStreak = (day == daily.lastCompletedDay + 1) ? daily.currentStreak + 1 : 1
        daily.bestStreak = max(daily.bestStreak, daily.currentStreak)
        daily.lastCompletedDay = day
        save(daily, key: Key.daily)
    }

    func hasCompletedDaily(day: Int) -> Bool { daily.lastCompletedDay == day }

    // MARK: - Saved game

    func saveGame(_ snapshot: GameSnapshot) {
        savedGame = snapshot
        save(snapshot, key: Key.saveGame)
    }

    func clearSavedGame() {
        savedGame = nil
        defaults.removeObject(forKey: Key.saveGame)
    }

    // MARK: - Mastery
    // Type-erased so this file has no dependency on MasteryTracker.

    func loadMastery<T: Decodable>(_ type: T.Type) -> T? { load(type, key: Key.mastery) }
    func saveMastery(_ value: some Encodable) { save(value, key: Key.mastery) }

    // MARK: - Codable plumbing

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save(_ value: some Encodable, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }
}

// MARK: - Snapshot

/// A game in progress, small enough to persist on every board change.
nonisolated struct GameSnapshot: Codable, Sendable, Equatable {
    let puzzle: Puzzle
    let board: BoardState
    let undoStack: [Move]
    let difficulty: Difficulty
    let elapsed: TimeInterval
    /// Optional so saves written before this field existed still decode.
    var isDaily: Bool?
}
