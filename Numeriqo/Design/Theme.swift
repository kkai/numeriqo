//
//  Theme.swift
//  Numeriqo
//
//  Ink on paper. See docs/DESIGN.md.
//
//  The board is monochrome and cages are drawn as strokes, never fills — so
//  colour is spent entirely on *meaning*: the active digit, a hint's argument,
//  an error, a satisfied cage. Every competing Calcudoku app spends its
//  strongest signal on static cage tinting the player memorises in ten seconds.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A light/dark colour value held as plain components rather than a `UIColor`.
///
/// This is what lets the provider closure in `Theme.dynamic(light:dark:)` stay
/// `@Sendable`: it captures only these, so whether a given SDK declares
/// `UIColor` `Sendable` stops mattering. See the note on `Theme`.
nonisolated struct ThemeRGBA: Sendable {
    let red, green, blue, alpha: CGFloat

    init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    func opacity(_ value: CGFloat) -> ThemeRGBA {
        ThemeRGBA(red, green, blue, value)
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(_ c: ThemeRGBA) {
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#endif

/// Semantic colour and type tokens.
///
/// `nonisolated` is load-bearing, not tidiness. The project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it `Theme` — and the
/// provider closure in `dynamic(light:dark:)` — is implicitly `@MainActor`.
/// UIKit imports `-initWithDynamicProvider:` without `NS_SWIFT_SENDABLE`, so the
/// closure inherits that isolation and Swift 6 emits an executor assertion in its
/// prologue. UIKit resolves dynamic colours from SwiftUI's
/// `com.apple.SwiftUI.AsyncRenderer` thread, which trips the assertion and traps
/// (EXC_BREAKPOINT). It shipped this way in Just Kakuro and fired
/// intermittently — anywhere, including an idle Home screen — because whether a
/// given resolve lands off-main is a race.
///
/// Guarded three ways by `ThemeIsolationTests`.
nonisolated enum Theme {

    // MARK: - Surfaces

    /// Paper. Deliberately cool and near-neutral rather than warm cream —
    /// warm cream with a serif is the house style of every generated design
    /// this year, and the ink here should read as graphite, not parchment.
    static let paper = dynamic(light: ThemeRGBA(0.969, 0.965, 0.957),
                               dark: ThemeRGBA(0.071, 0.075, 0.082))
    /// Cell fill. Sits just above `paper` so the grid reads as laid *on* it.
    static let surface = dynamic(light: ThemeRGBA(1.0, 1.0, 1.0),
                                 dark: ThemeRGBA(0.114, 0.122, 0.133))

    // MARK: - Ink

    static let ink = dynamic(light: ThemeRGBA(0.102, 0.102, 0.118),
                             dark: ThemeRGBA(0.949, 0.941, 0.925))
    /// Clue targets and pencil notes: present, but receding until relevant.
    ///
    /// Raised from 0.55 to 0.78 after `performAccessibilityAudit` reported
    /// "contrast failed" and "nearly passed" against grouped-list backgrounds.
    /// Secondary text still reads as secondary at this weight, and now clears
    /// the threshold on every surface the app uses.
    static let inkSecondary = dynamic(light: ThemeRGBA(0.102, 0.102, 0.118, 0.78),
                                      dark: ThemeRGBA(0.949, 0.941, 0.925, 0.76))
    /// Cell boundaries *inside* a cage. Drawn dotted, and only between cells of
    /// the same cage — so line style itself encodes cage membership and the
    /// board needs no second boundary to explain itself.
    static let cellRule = dynamic(light: ThemeRGBA(0.102, 0.102, 0.118, 0.22),
                                  dark: ThemeRGBA(0.949, 0.941, 0.925, 0.26))
    /// The cage boundary. Solid, and the heaviest line on the board.
    static let cageRule = dynamic(light: ThemeRGBA(0.102, 0.102, 0.118, 0.82),
                                  dark: ThemeRGBA(0.949, 0.941, 0.925, 0.80))

    // MARK: - Meaning

    /// The single accent. Shifts by difficulty tier (see `accent(for:)`), so the
    /// app changes temperature as the player climbs.
    static let accent = tierAccent(.steady)
    /// Desaturated rust, never a pure red — this marks a wrong digit, not a
    /// disaster.
    static let error = dynamic(light: ThemeRGBA(0.706, 0.275, 0.184),
                               dark: ThemeRGBA(0.878, 0.443, 0.310))
    /// Success is the accent, never green. Green would be a second hue spent on
    /// something the accent already says.
    static let success = dynamic(light: ThemeRGBA(0.306, 0.541, 0.435),
                                 dark: ThemeRGBA(0.463, 0.702, 0.588))

    /// The wash behind a selected cell and its row/column mates.
    ///
    /// Derived from the tier accent rather than fixed: a blue wash under a green
    /// selection border is the kind of mismatch that makes a board look
    /// assembled rather than designed.
    static func tierWash(_ difficulty: Difficulty, strength: Double = 1) -> Color {
        tierAccent(difficulty).opacity(0.10 * strength)
    }

    /// Per-tier accent. One hue rotation across the curriculum, so difficulty is
    /// legible before a word is read.
    static func tierAccent(_ difficulty: Difficulty) -> Color {
        switch difficulty {
        case .gentle: dynamic(light: ThemeRGBA(0.243, 0.486, 0.694),
                              dark: ThemeRGBA(0.400, 0.635, 0.827))
        case .steady: dynamic(light: ThemeRGBA(0.306, 0.541, 0.435),
                              dark: ThemeRGBA(0.463, 0.702, 0.588))
        case .sharp: dynamic(light: ThemeRGBA(0.722, 0.525, 0.231),
                             dark: ThemeRGBA(0.851, 0.671, 0.373))
        case .deep: dynamic(light: ThemeRGBA(0.659, 0.329, 0.220),
                            dark: ThemeRGBA(0.812, 0.482, 0.361))
        case .severe: dynamic(light: ThemeRGBA(0.486, 0.294, 0.490),
                              dark: ThemeRGBA(0.647, 0.451, 0.651))
        }
    }

    // MARK: - Type

    /// Every figure on the board is monospaced. Non-tabular digits make a
    /// numeric grid shimmer as values change — the columns visibly breathe.
    ///
    /// Not `.rounded`: soft terminals read as a friendly consumer app and fight
    /// both the ink surface and the arithmetic. The default grotesque is
    /// quieter and lets the accent stroke be the only expressive mark.
    static func digitFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular).monospacedDigit()
    }

    /// Clues are set small and tight. They must be legible without competing
    /// with the digit that will eventually sit beside them.
    static func clueFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold).monospacedDigit()
    }

    static func noteFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular).monospacedDigit()
    }

    /// The number pad. A semantic style so it scales with Dynamic Type — the
    /// board's digits cannot (they are sized to their cell), but the pad has no
    /// such constraint and the audit was right to flag it.
    static let padDigitFont = Font.system(.title2, design: .default).monospacedDigit()

    static let title = Font.system(.largeTitle, design: .default).weight(.light)
    static let heading = Font.system(.title3, design: .default).weight(.medium)

    // MARK: - Dynamic provider

    /// The closure is *also* explicitly `@Sendable`. That is redundant while
    /// `Theme` is `nonisolated` — a `@Sendable` closure never inherits actor
    /// isolation — and deliberately so: either annotation alone prevents the
    /// executor-assertion prologue, so losing one does not silently bring the
    /// trap back. `dynamicProvider:` is spelled out rather than used as a
    /// trailing closure so the dangerous API stays greppable.
    private static func dynamic(light: ThemeRGBA, dark: ThemeRGBA) -> Color {
        #if canImport(UIKit)
        Color(UIColor(dynamicProvider: { @Sendable trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        }))
        #else
        Color(red: light.red, green: light.green, blue: light.blue).opacity(light.alpha)
        #endif
    }
}
