//
//  Route.swift
//  Numeriqo
//

import Foundation

/// Navigation destinations. Value-typed so the stack is `Codable`-friendly and
/// a screen can be pushed from anywhere without a reference to its view.
nonisolated enum Route: Hashable {
    case play(size: Int, difficulty: Difficulty)
    case daily(day: Int)
    case resume
    case learn
    /// nil is the rules lesson.
    case lesson(Technique?)
    case stats
    case settings
}
