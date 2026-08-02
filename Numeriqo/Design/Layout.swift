//
//  Layout.swift
//  Numeriqo
//
//  Spacing, radii, and the button vocabulary.
//
//  The board is precise: one lattice, one corner treatment, one line system.
//  The chrome around it was not — five corner radii in use and a different
//  button treatment on every screen. A minimal design has nowhere to hide
//  sloppiness, so this file exists to give the chrome the same discipline.
//

import SwiftUI

nonisolated enum Layout {

    // MARK: - Radii
    //
    // Three values, each meaning something. A control, a card, a sheet. The
    // board itself is square and takes none of them.

    enum Radius {
        static let control: CGFloat = 12
        static let card: CGFloat = 16
        // No `sheet`. There was one, at 22, with zero call sites: SwiftUI owns
        // a sheet's corner and the app never draws its own.
    }

    // MARK: - Spacing
    //
    // A 4pt base. `gutter` is the screen margin and should be the only
    // horizontal padding any screen applies.

    enum Space {
        static let tight: CGFloat = 4
        static let snug: CGFloat = 8
        static let step: CGFloat = 12
        static let block: CGFloat = 20
        static let section: CGFloat = 28
        static let gutter: CGFloat = 20
    }

    /// Minimum tappable size. Below this the accessibility audit reports
    /// "hit area is too small", and it is right to.
    static let minimumTarget: CGFloat = 44
}

// MARK: - Buttons

/// The one loud control on a screen.
///
/// `fills: false` hugs its label instead of spanning the width, for a primary
/// that sits inline beside other controls. That case used to be a hand-rolled
/// capsule in `HintBanner` with a different corner and a different height, so
/// the app had two primary shapes.
struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.ink
    var fills = true
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, fills ? 0 : Layout.Space.block)
            .frame(maxWidth: fills ? .infinity : nil,
                   minHeight: Layout.minimumTarget + 8)
            .background(
                RoundedRectangle(cornerRadius: Layout.Radius.control, style: .continuous)
                    .fill(tint)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Motion.noteFlip, value: configuration.isPressed)
    }
}

/// Everything that sits beside or beneath the primary action.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: Layout.minimumTarget)
            .background(
                RoundedRectangle(cornerRadius: Layout.Radius.control, style: .continuous)
                    .fill(Theme.surface)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : Motion.noteFlip, value: configuration.isPressed)
    }
}

/// Text-only, for a tertiary action that should not compete.
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.ink)
            // A 44pt target without a 44pt-looking control.
            .frame(minHeight: Layout.minimumTarget)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.6 : 1) : 0.45)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(tint: Color = Theme.ink, fills: Bool = true) -> PrimaryButtonStyle {
        PrimaryButtonStyle(tint: tint, fills: fills)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}

// MARK: - Card

extension View {
    /// The standard raised surface: cards, banners, grouped rows.
    func card(padding: CGFloat = Layout.Space.block) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: Layout.Radius.card, style: .continuous)
                    .fill(Theme.surface)
            )
    }

    /// A small-caps label above a control.
    ///
    /// One modifier because there were three treatments: three different sizes,
    /// two different uppercasing mechanisms, and tracking on one of the three.
    /// Uppercase without positive tracking is the classic legibility failure,
    /// so it is applied here rather than left to each call site to remember.
    ///
    /// `.textCase`, never `String.uppercased()`: the latter is wrong in Turkish.
    func eyebrow(_ colour: Color = Theme.inkSecondary) -> some View {
        self
            .font(Theme.eyebrow)
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(colour)
    }

    /// The app's surface. Paper was previously painted three different ways,
    /// including "not at all, but a parent happens to cover it".
    func paperScreen() -> some View {
        self.background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Close

/// The dismiss control on a sheet or a banner.
///
/// One component because there were two: the same glyph in the same 44pt hit
/// area, written twice at two sizes, one with `Layout.minimumTarget` and one
/// with a literal 44.
struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(Theme.secondary.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                // A 44pt target, without a 44pt glyph.
                .frame(width: Layout.minimumTarget, height: Layout.minimumTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}
