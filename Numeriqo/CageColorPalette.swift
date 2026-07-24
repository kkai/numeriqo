//
//  CageColorPalette.swift
//  Numeriqo
//
//  Blue cage tints for the 2.0 "Icon Blue" design:
//  near-white ice blues in light mode, navy shades in dark mode.
//

import SwiftUI

enum CageColorID: Int, CaseIterable {
    case color1 = 0
    case color2
    case color3
    case color4
    case color5
    case color6
    case color7
    case color8
    case color9
    case color10
    case color11
    case color12
    case color13
    case color14
    case color15

    // Subtle brightness ladder so neighboring cages read as distinct
    // without breaking the overall blue wash.
    private var step: Double {
        // Spread the 15 cases over an interleaved ramp (0, 8, 1, 9, ...)
        // so consecutive indices land on visibly different steps.
        let interleaved = (rawValue % 2 == 0) ? rawValue / 2 : 7 + (rawValue + 1) / 2
        return Double(interleaved) / 14.0
    }

    var lightModeColor: Color {
        // Near-white ice blues: from #F7FBFF down to #DEEBFA
        let t = step
        return Color(
            red: (247 - 25 * t) / 255,
            green: (251 - 16 * t) / 255,
            blue: 255 / 255
        )
    }

    var darkModeColor: Color {
        // Navy shades: from #0E2A52 up to #1B4178
        let t = step
        return Color(
            red: (14 + 13 * t) / 255,
            green: (42 + 23 * t) / 255,
            blue: (82 + 38 * t) / 255
        )
    }

    var adaptiveColor: Color {
        ThemeColors.adaptive(light: lightModeColor, dark: darkModeColor)
    }

    // Get a color ID from an index, cycling through available colors
    static func fromIndex(_ index: Int) -> CageColorID {
        let allCases = CageColorID.allCases
        return allCases[index % allCases.count]
    }
}
