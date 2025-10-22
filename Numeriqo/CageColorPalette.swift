//
//  CageColorPalette.swift
//  Numeriqo
//
//  Created for distinct cage colors in light and dark modes
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

    var lightModeColor: Color {
        switch self {
        case .color1:
            return Color(red: 0.95, green: 0.95, blue: 0.95)  // Very light grey
        case .color2:
            return Color(red: 0.93, green: 0.93, blue: 0.93)  // Light grey
        case .color3:
            return Color(red: 0.91, green: 0.91, blue: 0.91)  // Light-medium grey
        case .color4:
            return Color(red: 0.89, green: 0.89, blue: 0.89)  // Medium-light grey
        case .color5:
            return Color(red: 0.87, green: 0.87, blue: 0.87)  // Medium grey
        case .color6:
            return Color(red: 0.85, green: 0.85, blue: 0.85)  // Medium-dark grey
        case .color7:
            return Color(red: 0.94, green: 0.94, blue: 0.94)  // Very light grey 2
        case .color8:
            return Color(red: 0.92, green: 0.92, blue: 0.92)  // Light grey 2
        case .color9:
            return Color(red: 0.90, green: 0.90, blue: 0.90)  // Light-medium grey 2
        case .color10:
            return Color(red: 0.88, green: 0.88, blue: 0.88)  // Medium-light grey 2
        case .color11:
            return Color(red: 0.86, green: 0.86, blue: 0.86)  // Medium grey 2
        case .color12:
            return Color(red: 0.84, green: 0.84, blue: 0.84)  // Medium-dark grey 2
        case .color13:
            return Color(red: 0.96, green: 0.96, blue: 0.96)  // Ultra light grey
        case .color14:
            return Color(red: 0.83, green: 0.83, blue: 0.83)  // Darker grey
        case .color15:
            return Color(red: 0.82, green: 0.82, blue: 0.82)  // Darkest light mode grey
        }
    }

    var darkModeColor: Color {
        switch self {
        case .color1:
            return Color(red: 0.15, green: 0.15, blue: 0.15)  // Very dark grey
        case .color2:
            return Color(red: 0.18, green: 0.18, blue: 0.18)  // Dark grey
        case .color3:
            return Color(red: 0.21, green: 0.21, blue: 0.21)  // Dark-medium grey
        case .color4:
            return Color(red: 0.24, green: 0.24, blue: 0.24)  // Medium-dark grey
        case .color5:
            return Color(red: 0.27, green: 0.27, blue: 0.27)  // Medium grey
        case .color6:
            return Color(red: 0.30, green: 0.30, blue: 0.30)  // Medium-light grey
        case .color7:
            return Color(red: 0.16, green: 0.16, blue: 0.16)  // Very dark grey 2
        case .color8:
            return Color(red: 0.19, green: 0.19, blue: 0.19)  // Dark grey 2
        case .color9:
            return Color(red: 0.22, green: 0.22, blue: 0.22)  // Dark-medium grey 2
        case .color10:
            return Color(red: 0.25, green: 0.25, blue: 0.25)  // Medium-dark grey 2
        case .color11:
            return Color(red: 0.28, green: 0.28, blue: 0.28)  // Medium grey 2
        case .color12:
            return Color(red: 0.31, green: 0.31, blue: 0.31)  // Medium-light grey 2
        case .color13:
            return Color(red: 0.14, green: 0.14, blue: 0.14)  // Ultra dark grey
        case .color14:
            return Color(red: 0.32, green: 0.32, blue: 0.32)  // Lighter grey
        case .color15:
            return Color(red: 0.35, green: 0.35, blue: 0.35)  // Lightest dark mode grey
        }
    }

    var adaptiveColor: Color {
        #if os(macOS)
        return Color(NSColor(name: nil, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(self.darkModeColor) : NSColor(self.lightModeColor)
        }))
        #else
        return Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark ?
                UIColor(self.darkModeColor) : UIColor(self.lightModeColor)
        })
        #endif
    }

    // Get a color ID from an index, cycling through available colors
    static func fromIndex(_ index: Int) -> CageColorID {
        let allCases = CageColorID.allCases
        return allCases[index % allCases.count]
    }
}