//
//  ThemeColors.swift
//  Numeriqo
//
//  Numeriqo 2.0 "Icon Blue" design tokens.
//  Soft neumorphic blue palette matching the app icon:
//  pale ice-blue surfaces in light mode, deep navy in dark mode,
//  with a bright blue accent gradient.
//

import SwiftUI

struct ThemeColors {

    // MARK: - Adaptive color factory

    /// Trait-reactive color resolving to `light` or `dark` at render time.
    static func adaptive(light: Color, dark: Color) -> Color {
        #if os(macOS)
        Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        }))
        #else
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #endif
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }

    // MARK: - Core palette

    /// Bright accent blue (buttons, strokes, selected states)
    static let accent = rgb(47, 134, 246)
    static let accentLight = rgb(96, 169, 255)
    static let accentDeep = rgb(23, 104, 224)

    // MARK: - Background Colors

    static var primaryBackground: Color {
        adaptive(light: rgb(228, 240, 252), dark: rgb(8, 22, 44))
    }

    static var secondaryBackground: Color {
        adaptive(light: rgb(240, 247, 254), dark: rgb(13, 32, 60))
    }

    /// Full-screen vertical wash behind every screen
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                adaptive(light: rgb(238, 246, 254), dark: rgb(10, 28, 54)),
                adaptive(light: rgb(219, 235, 251), dark: rgb(5, 16, 34))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Text Colors

    static var primaryText: Color {
        adaptive(light: rgb(24, 60, 109), dark: rgb(214, 232, 255))
    }

    static var secondaryText: Color {
        adaptive(light: rgb(85, 122, 168), dark: rgb(128, 163, 210))
    }

    static var cageLabel: Color {
        adaptive(light: rgb(31, 106, 221), dark: rgb(118, 180, 255))
    }

    // MARK: - Grid Colors

    static var gridBorder: Color {
        adaptive(light: rgb(74, 148, 240), dark: rgb(62, 143, 255))
    }

    static var cageBorder: Color {
        adaptive(light: rgb(94, 160, 242), dark: rgb(56, 132, 240))
    }

    /// Fill inside the rounded grid container, behind the cages
    static var gridContainerFill: Color {
        adaptive(light: rgb(245, 250, 255).opacity(0.6), dark: rgb(10, 30, 58))
    }

    /// Border of the rounded grid container (prominent in dark mode)
    static var gridContainerStroke: Color {
        adaptive(light: rgb(74, 148, 240).opacity(0.30), dark: rgb(62, 143, 255).opacity(0.9))
    }

    // MARK: - Interactive Elements

    static var selectionHighlight: Color {
        adaptive(light: accent.opacity(0.22), dark: accentLight.opacity(0.30))
    }

    static var selectionBorder: Color {
        adaptive(light: accent, dark: accentLight)
    }

    static var errorText: Color {
        adaptive(light: rgb(217, 72, 64), dark: rgb(255, 118, 110))
    }

    // MARK: - Button Colors

    static var buttonBackground: Color {
        adaptive(light: rgb(240, 247, 254), dark: rgb(16, 38, 70))
    }

    static var buttonBackgroundSelected: Color {
        accent
    }

    static var buttonBackgroundDisabled: Color {
        adaptive(light: rgb(196, 214, 234), dark: rgb(26, 48, 80))
    }

    static var unselectedButtonBackground: Color {
        adaptive(light: rgb(240, 247, 254), dark: rgb(16, 38, 70))
    }

    // MARK: - Cards

    static var cardFill: Color {
        adaptive(light: rgb(242, 248, 255), dark: rgb(15, 37, 68))
    }

    static var cardStroke: Color {
        adaptive(light: rgb(255, 255, 255).opacity(0.9), dark: accentLight.opacity(0.35))
    }

    static var cardShadow: Color {
        adaptive(light: rgb(112, 150, 197).opacity(0.35), dark: Color.black.opacity(0.5))
    }

    // MARK: - Gradients

    /// Bright blue gradient for prominent buttons and selected cards
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentLight, accentDeep],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Gradient for the big "Numeriqo" title
    static var titleGradient: LinearGradient {
        LinearGradient(
            colors: [
                adaptive(light: rgb(96, 169, 255), dark: rgb(133, 190, 255)),
                adaptive(light: rgb(29, 106, 229), dark: rgb(56, 132, 240))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Soft outer glow around glowing accent elements (dark mode mainly)
    static var accentGlow: Color {
        adaptive(light: accent.opacity(0.35), dark: accentLight.opacity(0.55))
    }

    // MARK: - Embossed background glyphs

    static var embossGlyph: Color {
        adaptive(light: rgb(255, 255, 255).opacity(0.55), dark: rgb(56, 108, 180).opacity(0.28))
    }

    static var embossGlyphShadow: Color {
        adaptive(light: rgb(122, 160, 205).opacity(0.45), dark: Color.black.opacity(0.55))
    }
}
