//
//  BestTimesManager.swift
//  Numeriqo
//
//  Created by kai on 27.07.25.
//

import Foundation

class BestTimesManager {
    static let shared = BestTimesManager(userDefaults: .standard)

    private let userDefaults: UserDefaults
    private static let migrationFlag = "bestTimesMigratedToDifficulty"

    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults
        migrateLegacyRecordsIfNeeded()
    }

    func getBestTime(for size: Int, difficulty: Difficulty) -> TimeInterval? {
        let time = userDefaults.double(forKey: bestTimeKey(for: size, difficulty: difficulty))
        return time > 0 ? time : nil
    }

    func updateBestTime(for size: Int, difficulty: Difficulty, time: TimeInterval) {
        let key = bestTimeKey(for: size, difficulty: difficulty)

        if let currentBest = getBestTime(for: size, difficulty: difficulty) {
            if time < currentBest {
                userDefaults.set(time, forKey: key)
            }
        } else {
            userDefaults.set(time, forKey: key)
        }
    }

    func isNewBestTime(for size: Int, difficulty: Difficulty, time: TimeInterval) -> Bool {
        guard let currentBest = getBestTime(for: size, difficulty: difficulty) else {
            return true
        }
        return time < currentBest
    }

    func resetBestTime(for size: Int, difficulty: Difficulty) {
        userDefaults.removeObject(forKey: bestTimeKey(for: size, difficulty: difficulty))
    }

    func resetAllBestTimes() {
        for size in 3...9 {
            for difficulty in Difficulty.allCases {
                resetBestTime(for: size, difficulty: difficulty)
            }
            userDefaults.removeObject(forKey: legacyKey(for: size))
        }
    }

    /// One-time move of pre-difficulty records to the medium tier — legacy
    /// puzzles came from natural generation, whose middle tertile is medium.
    private func migrateLegacyRecordsIfNeeded() {
        guard !userDefaults.bool(forKey: Self.migrationFlag) else { return }
        for size in 3...9 {
            let legacy = userDefaults.double(forKey: legacyKey(for: size))
            if legacy > 0 {
                let mediumKey = bestTimeKey(for: size, difficulty: .medium)
                if userDefaults.double(forKey: mediumKey) <= 0 {
                    userDefaults.set(legacy, forKey: mediumKey)
                }
                userDefaults.removeObject(forKey: legacyKey(for: size))
            }
        }
        userDefaults.set(true, forKey: Self.migrationFlag)
    }

    private func bestTimeKey(for size: Int, difficulty: Difficulty) -> String {
        return "bestTime_\(size)x\(size)_\(difficulty.rawValue)"
    }

    private func legacyKey(for size: Int) -> String {
        return "bestTime_\(size)x\(size)"
    }

    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
