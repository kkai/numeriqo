//
//  Motion.swift
//  Numeriqo
//
//  Named motion tokens — views never write inline animation values.
//
//  Motion here has one job: make logic visible. Decorative motion is cut. See
//  docs/DESIGN.md §4.
//

import SwiftUI

/// `nonisolated` for the same reason as `Theme`: under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` these would be MainActor-isolated
/// statics read during off-main render passes. Nothing here escapes a closure to
/// UIKit, so it is not implicated in the crash `Theme` guards against — but every
/// member is a `Sendable` value type, so it costs nothing to keep the design
/// tokens uniformly safe to read from any isolation domain.
nonisolated enum Motion {

    // MARK: - Entry

    /// Digit placed: spring with a slight overshoot.
    static let digitEntry = Animation.spring(response: 0.28, dampingFraction: 0.68)
    /// Digit removed.
    static let digitExit = Animation.easeOut(duration: 0.18)
    /// Note toggles and other small flips.
    static let noteFlip = Animation.spring(response: 0.2, dampingFraction: 0.8)
    /// Selection movement.
    static let selection = Animation.spring(response: 0.26, dampingFraction: 0.85)

    // MARK: - Board

    /// Board entrance, staggered per cell along the diagonal.
    static let boardEntrance = Animation.spring(response: 0.5, dampingFraction: 0.85)
    static let boardEntranceStagger: TimeInterval = 0.012
    /// Line completion sweep.
    static let lineComplete = Animation.easeOut(duration: 0.4)
    static let lineCompleteStagger: TimeInterval = 0.04
    /// A cage's outline drawing once around itself when satisfied.
    static let cageSatisfied = Animation.easeInOut(duration: 0.5)

    // MARK: - The drawn argument

    /// The signature moment. Witness cells lift in sequence, then the logic is
    /// drawn between them. See docs/DESIGN.md §4 and HintArgumentView.
    static let argumentFocus = Animation.spring(response: 0.3, dampingFraction: 0.75)
    /// Per-witness stagger — this is what makes the argument read as a sequence
    /// of steps rather than a single highlight.
    static let argumentStagger: TimeInterval = 0.1
    /// The travelling stroke.
    static let argumentDraw = Animation.easeInOut(duration: 0.45)
    /// Eliminations striking through.
    static let argumentConclude = Animation.easeOut(duration: 0.22)

    // MARK: - Chrome

    static let overlay = Animation.spring(response: 0.35, dampingFraction: 0.9)
}
