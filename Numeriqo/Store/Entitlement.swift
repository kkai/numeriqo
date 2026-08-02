//
//  Entitlement.swift
//  Numeriqo
//
//  What the one-time unlock buys, and every gating decision in the app.
//

import Foundation

nonisolated enum PaidFeature: String, CaseIterable, Sendable, Identifiable {
    case advancedLessons
    case practiceDrills
    case teachingHints
    case largeGrids
    case stats

    var id: String { rawValue }

    var headline: String {
        switch self {
        case .advancedLessons: "The rest of the curriculum"
        case .practiceDrills: "Practice drills"
        case .teachingHints: "Hints that teach"
        case .largeGrids: "Large grids"
        case .stats: "Your progress"
        }
    }

    var pitch: String {
        switch self {
        case .advancedLessons:
            "Every technique past the basics: cage and line interaction, the Rule of N, spill-over arithmetic, odd and even, and X-Wing."
        case .practiceDrills:
            "Targeted drills for every technique. Mastery counts only the solves you managed unaided."
        case .teachingHints:
            "A hint that names the technique and draws the reasoning on the grid rather than filling in the cell for you."
        case .largeGrids:
            "6×6 through 9×9, the sizes where the deeper techniques start to matter."
        case .stats:
            "Solve counts, your mastery path across all 16 techniques, and how many hints you are taking as that number falls."
        }
    }
}

/// Every gating decision, as pure functions.
///
/// Free of StoreKit and of actor isolation so the rules can be tested
/// exhaustively without a store connection.
nonisolated enum FeatureGate {

    /// Free lessons run through the first three techniques — enough to learn the
    /// game and to feel what the hint engine would be doing for you.
    static let freeLessonCeiling: Technique = .minMaxBounds

    /// Largest grid a free player can open.
    ///
    /// Matches exactly what free Numeriqo 2.x offers today. **3.0 never removes
    /// something 2.x gave away.**
    static let freeSizeCeiling = 5

    static func isLessonAvailable(_ technique: Technique?, unlocked: Bool) -> Bool {
        guard !unlocked else { return true }
        guard let technique else { return true }   // the rules lesson
        return technique <= freeLessonCeiling
    }

    static func isSizeAvailable(_ size: Int, unlocked: Bool) -> Bool {
        unlocked || size <= freeSizeCeiling
    }

    /// Difficulty is never gated. A free player can play Severe on a 5×5 —
    /// gating it would punish exactly the players most likely to buy.
    static func isDifficultyAvailable(_ difficulty: Difficulty, unlocked: Bool) -> Bool { true }

    /// Drills are paid wholesale: mastery progress is itself a paid surface.
    static func areDrillsAvailable(unlocked: Bool) -> Bool { unlocked }

    /// The escalating hint ladder. A free player still gets the error hint —
    /// enough to feel what the ladder would do.
    static func hintPolicy(unlocked: Bool) -> HintPolicy { unlocked ? .full : .errorsOnly }

    /// Best times stay free; the richer stats do not. 2.x tracked best times,
    /// so taking them away would be a regression for existing players.
    static func areBestTimesAvailable(unlocked: Bool) -> Bool { true }
    static func areFullStatsAvailable(unlocked: Bool) -> Bool { unlocked }

    static func isAvailable(_ feature: PaidFeature, unlocked: Bool) -> Bool { unlocked }
}
