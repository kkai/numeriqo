//
//  BestTimesMigrationTests.swift
//  NumeriqoTests
//

import Foundation
import Testing
@testable import Numeriqo

struct BestTimesMigrationTests {

    private func freshDefaults(_ name: String) -> UserDefaults {
        let suite = "NumeriqoTests.\(name)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func legacyRecordMovesToMediumTier() {
        let defaults = freshDefaults(#function)
        defaults.set(83.0, forKey: "bestTime_4x4")

        let manager = BestTimesManager(userDefaults: defaults)

        #expect(manager.getBestTime(for: 4, difficulty: .medium) == 83.0)
        #expect(manager.getBestTime(for: 4, difficulty: .easy) == nil)
        #expect(manager.getBestTime(for: 4, difficulty: .hard) == nil)
        #expect(defaults.object(forKey: "bestTime_4x4") == nil, "legacy key should be removed")
    }

    @Test func migrationIsIdempotent() {
        let defaults = freshDefaults(#function)
        defaults.set(60.0, forKey: "bestTime_5x5")

        _ = BestTimesManager(userDefaults: defaults)
        // A better time is recorded after migration...
        BestTimesManager(userDefaults: defaults).updateBestTime(for: 5, difficulty: .medium, time: 45.0)
        // ...and re-running migration (new instance) must not resurrect 60.
        let manager = BestTimesManager(userDefaults: defaults)
        #expect(manager.getBestTime(for: 5, difficulty: .medium) == 45.0)
    }

    @Test func migrationWithoutLegacyRecordsIsANoOp() {
        let defaults = freshDefaults(#function)
        let manager = BestTimesManager(userDefaults: defaults)
        for size in 3...9 {
            for difficulty in Difficulty.allCases {
                #expect(manager.getBestTime(for: size, difficulty: difficulty) == nil)
            }
        }
    }

    @Test func migrationDoesNotClobberExistingMediumRecord() {
        let defaults = freshDefaults(#function)
        defaults.set(90.0, forKey: "bestTime_4x4")
        defaults.set(50.0, forKey: "bestTime_4x4_medium")

        let manager = BestTimesManager(userDefaults: defaults)
        #expect(manager.getBestTime(for: 4, difficulty: .medium) == 50.0)
        #expect(defaults.object(forKey: "bestTime_4x4") == nil)
    }

    @Test func tiersKeepIndependentRecords() {
        let defaults = freshDefaults(#function)
        let manager = BestTimesManager(userDefaults: defaults)

        manager.updateBestTime(for: 4, difficulty: .easy, time: 30.0)
        manager.updateBestTime(for: 4, difficulty: .hard, time: 120.0)

        #expect(manager.getBestTime(for: 4, difficulty: .easy) == 30.0)
        #expect(manager.getBestTime(for: 4, difficulty: .hard) == 120.0)
        #expect(manager.getBestTime(for: 4, difficulty: .medium) == nil)

        // Slower time does not overwrite; faster does.
        manager.updateBestTime(for: 4, difficulty: .easy, time: 45.0)
        #expect(manager.getBestTime(for: 4, difficulty: .easy) == 30.0)
        manager.updateBestTime(for: 4, difficulty: .easy, time: 20.0)
        #expect(manager.getBestTime(for: 4, difficulty: .easy) == 20.0)
    }
}
