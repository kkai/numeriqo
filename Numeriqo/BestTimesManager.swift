//
//  BestTimesManager.swift
//  Numeriqo
//
//  Created by kai on 27.07.25.
//

import Foundation

class BestTimesManager {
    static let shared = BestTimesManager()
    
    private let userDefaults = UserDefaults.standard
    
    private init() {}
    
    func getBestTime(for size: Int) -> TimeInterval? {
        let key = bestTimeKey(for: size)
        let time = userDefaults.double(forKey: key)
        return time > 0 ? time : nil
    }
    
    func updateBestTime(for size: Int, time: TimeInterval) {
        let key = bestTimeKey(for: size)
        
        if let currentBest = getBestTime(for: size) {
            if time < currentBest {
                userDefaults.set(time, forKey: key)
            }
        } else {
            userDefaults.set(time, forKey: key)
        }
    }
    
    func isNewBestTime(for size: Int, time: TimeInterval) -> Bool {
        guard let currentBest = getBestTime(for: size) else {
            return true
        }
        return time < currentBest
    }
    
    func resetBestTime(for size: Int) {
        let key = bestTimeKey(for: size)
        userDefaults.removeObject(forKey: key)
    }
    
    func resetAllBestTimes() {
        for size in 3...9 {
            resetBestTime(for: size)
        }
    }
    
    private func bestTimeKey(for size: Int) -> String {
        return "bestTime_\(size)x\(size)"
    }
    
    static func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}