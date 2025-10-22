//
//  ThemeColors.swift
//  Numeriqo
//
//  Created for dark mode support
//

import SwiftUI

struct ThemeColors {
    // MARK: - Background Colors
    static var primaryBackground: Color {
        #if os(macOS)
        Color(NSColor.windowBackgroundColor)
        #else
        Color(UIColor.systemBackground)
        #endif
    }

    static var secondaryBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.secondarySystemBackground)
        #endif
    }

    // MARK: - Text Colors
    static var primaryText: Color {
        #if os(macOS)
        Color(NSColor.labelColor)
        #else
        Color(UIColor.label)
        #endif
    }

    static var secondaryText: Color {
        #if os(macOS)
        Color(NSColor.secondaryLabelColor)
        #else
        Color(UIColor.secondaryLabel)
        #endif
    }

    static var cageLabel: Color {
        #if os(macOS)
        Color(NSColor.labelColor).opacity(0.95)
        #else
        Color(UIColor.label).opacity(0.95)
        #endif
    }

    // MARK: - Grid Colors
    static var gridBorder: Color {
        #if os(macOS)
        Color(NSColor.labelColor).opacity(0.85)
        #else
        Color(UIColor.label).opacity(0.85)
        #endif
    }

    static var cageBorder: Color {
        #if os(macOS)
        Color(NSColor.labelColor).opacity(0.7)
        #else
        Color(UIColor.label).opacity(0.7)
        #endif
    }

    // MARK: - Interactive Elements
    static var selectionHighlight: Color {
        Color.blue.opacity(0.2)
    }

    static var selectionBorder: Color {
        Color.blue
    }

    static var errorText: Color {
        Color.red
    }

    // MARK: - Button Colors
    static var buttonBackground: Color {
        #if os(macOS)
        Color(NSColor.controlColor)
        #else
        Color(UIColor.tertiarySystemFill)
        #endif
    }

    static var buttonBackgroundSelected: Color {
        Color.blue
    }

    static var buttonBackgroundDisabled: Color {
        Color.gray
    }

    static var unselectedButtonBackground: Color {
        #if os(macOS)
        Color(NSColor.controlBackgroundColor)
        #else
        Color(UIColor.secondarySystemFill)
        #endif
    }
}