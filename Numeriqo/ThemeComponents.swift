//
//  ThemeComponents.swift
//  Numeriqo
//
//  Reusable views and button styles for the 2.0 "Icon Blue" design.
//

import SwiftUI

// MARK: - Gradient title

/// The big glossy "Numeriqo" wordmark.
struct GradientTitleView: View {
    let text: String
    var fontSize: CGFloat = 44

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(
                ThemeColors.titleGradient
                    .shadow(.inner(color: .white.opacity(0.6), radius: 1, x: 0, y: 1))
            )
            .shadow(color: ThemeColors.accentGlow.opacity(0.6), radius: 10, x: 0, y: 2)
            .shadow(color: ThemeColors.cardShadow.opacity(0.5), radius: 2, x: 0, y: 2)
    }
}

// MARK: - Embossed glyph background

/// Large translucent math glyphs scattered like on the app icon.
/// Positions are in unit space relative to the view's bounds.
struct EmbossedGlyphBackground: View {
    private struct Glyph: Identifiable {
        let id = UUID()
        let symbol: String
        let x: Double      // unit position
        let y: Double
        let scale: Double  // relative glyph size
    }

    private let glyphs: [Glyph] = [
        Glyph(symbol: "+", x: 0.13, y: 0.08, scale: 0.85),
        Glyph(symbol: "3", x: 0.42, y: 0.06, scale: 0.95),
        Glyph(symbol: "6", x: 0.68, y: 0.16, scale: 1.35),
        Glyph(symbol: "1", x: 0.90, y: 0.05, scale: 0.90),
        Glyph(symbol: "0", x: 0.08, y: 0.28, scale: 1.0),
        Glyph(symbol: "8", x: 0.30, y: 0.24, scale: 1.05),
        Glyph(symbol: "0", x: 0.93, y: 0.28, scale: 0.95),
        Glyph(symbol: "4", x: 0.58, y: 0.42, scale: 1.15),
        Glyph(symbol: "÷", x: 0.88, y: 0.47, scale: 0.80),
        Glyph(symbol: "2", x: 0.12, y: 0.52, scale: 1.10),
        Glyph(symbol: "5", x: 0.38, y: 0.58, scale: 1.05),
        Glyph(symbol: "×", x: 0.94, y: 0.63, scale: 0.70),
        Glyph(symbol: "=", x: 0.66, y: 0.66, scale: 0.85)
    ]

    private var glyphStyle: AnyShapeStyle {
        #if os(macOS)
        // macOS composites inner shadows over translucent fills as a dark
        // wash, so use the plain emboss color there.
        return AnyShapeStyle(ThemeColors.embossGlyph)
        #else
        let highlight = ShadowStyle.inner(color: .white.opacity(0.7), radius: 1.5, x: 0, y: 1.5)
        let lowlight = ShadowStyle.inner(color: ThemeColors.embossGlyphShadow.opacity(0.5), radius: 2, x: 0, y: -1.5)
        return AnyShapeStyle(ThemeColors.embossGlyph.shadow(highlight).shadow(lowlight))
        #endif
    }

    var body: some View {
        GeometryReader { geometry in
            let base = min(geometry.size.width, geometry.size.height) * 0.30
            ZStack {
                ForEach(glyphs) { glyph in
                    Text(glyph.symbol)
                        .font(.system(size: base * glyph.scale, weight: .semibold, design: .rounded))
                        .foregroundStyle(glyphStyle)
                        .shadow(color: ThemeColors.embossGlyphShadow, radius: 5, x: 2, y: 4)
                        .position(
                            x: geometry.size.width * glyph.x,
                            y: geometry.size.height * glyph.y
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Size selection card

struct SizeCardView: View {
    let size: Int
    let isSelected: Bool
    let bestTime: TimeInterval?
    let action: () -> Void

    private var cornerRadius: CGFloat { 22 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text("\(size)×\(size)")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? .white : ThemeColors.cageLabel)

                recordView
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .background(cardBackground)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(NoEffectButtonStyle())
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    ThemeColors.accentGradient
                        .shadow(.inner(color: .white.opacity(0.45), radius: 1, x: 0, y: 1))
                )
                .shadow(color: ThemeColors.accentGlow, radius: 10, x: 0, y: 4)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ThemeColors.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(ThemeColors.cardStroke, lineWidth: 1)
                )
                .shadow(color: ThemeColors.cardShadow, radius: 6, x: 0, y: 4)
        }
    }

    @ViewBuilder
    private var recordView: some View {
        if let bestTime {
            HStack(spacing: 3) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .yellow : ThemeColors.accent)
                Text(BestTimesManager.formatTime(bestTime))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .white : ThemeColors.secondaryText)
            }
        } else {
            Text("No record")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(isSelected ? .white.opacity(0.85) : ThemeColors.secondaryText)
        }
    }
}

// MARK: - Gradient pill button (Start Game / New Game)

struct GradientPillButtonStyle: ButtonStyle {
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 21, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                Capsule()
                    .fill(
                        ThemeColors.accentGradient
                            .shadow(.inner(color: .white.opacity(0.5), radius: 1, x: 0, y: 1.5))
                    )
                    .shadow(color: ThemeColors.accentGlow, radius: 9, x: 0, y: 5)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Difficulty capsule selector

struct DifficultyCapsulePicker: View {
    @Binding var selection: Difficulty

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Difficulty.allCases) { difficulty in
                Button {
                    selection = difficulty
                } label: {
                    Text(difficulty.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(selection == difficulty ? .white : ThemeColors.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            Group {
                                if selection == difficulty {
                                    Capsule()
                                        .fill(ThemeColors.accentGradient)
                                        .shadow(color: ThemeColors.accentGlow.opacity(0.8), radius: 5, x: 0, y: 2)
                                }
                            }
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(NoEffectButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(ThemeColors.cardFill)
                .overlay(Capsule().stroke(ThemeColors.cardStroke, lineWidth: 1))
                .shadow(color: ThemeColors.cardShadow, radius: 5, x: 0, y: 3)
        )
    }
}

// MARK: - Number pad button

struct NumberPadButton: View {
    let label: String?
    let isEnabled: Bool
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let label {
                    Text(label)
                        .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Color.clear
                }
            }
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28)
                    .fill(
                        isEnabled
                            ? AnyShapeStyle(
                                ThemeColors.accentGradient
                                    .shadow(.inner(color: .white.opacity(0.45), radius: 1, x: 0, y: 1))
                              )
                            : AnyShapeStyle(ThemeColors.buttonBackgroundDisabled)
                    )
                    .shadow(
                        color: isEnabled ? ThemeColors.accentGlow.opacity(0.7) : ThemeColors.cardShadow.opacity(0.5),
                        radius: isEnabled ? 6 : 3,
                        x: 0,
                        y: 3
                    )
            )
        }
        .buttonStyle(NoEffectButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Previews

#Preview("Components – Light") {
    ZStack {
        ThemeColors.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 24) {
            GradientTitleView(text: "Numeriqo")
            HStack(spacing: 14) {
                SizeCardView(size: 3, isSelected: false, bestTime: nil) {}
                SizeCardView(size: 4, isSelected: true, bestTime: 46) {}
                SizeCardView(size: 5, isSelected: false, bestTime: nil) {}
            }
            Button("Start Game") {}
                .buttonStyle(GradientPillButtonStyle())
            HStack(spacing: 12) {
                NumberPadButton(label: nil, isEnabled: false, size: 52) {}
                ForEach(1..<5) { n in
                    NumberPadButton(label: "\(n)", isEnabled: true, size: 52) {}
                }
            }
        }
        .padding(24)
    }
    .preferredColorScheme(.light)
}

#Preview("Components – Dark") {
    ZStack {
        ThemeColors.backgroundGradient.ignoresSafeArea()
        VStack(spacing: 24) {
            GradientTitleView(text: "Numeriqo")
            EmbossedGlyphBackground()
                .frame(height: 220)
        }
        .padding(24)
    }
    .preferredColorScheme(.dark)
}
