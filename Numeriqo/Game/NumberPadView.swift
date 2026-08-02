//
//  NumberPadView.swift
//  Numeriqo
//
//  Number-first input by default.
//
//  Tapping a digit arms it and lights every instance of it on the board — which
//  teaches scanning, and makes the player think in digits and regions rather
//  than in cells. Tapping a cell first switches to cell-first for that entry.
//  See docs/TEACHING.md §5.
//

import SwiftUI

struct NumberPadView: View {
    let game: NumeriqoGame

    /// Input hooks, for callers that have to vet a press before it reaches the
    /// board. The tutorial supplies all three; ordinary play supplies none and
    /// the keys talk to `game` directly.
    var onDigit: ((Int) -> Void)?
    var onUndo: (() -> Void)?
    var onErase: (() -> Void)?
    /// Notes are a technique, not a rule, so the tutorial hides the key rather
    /// than trusting itself to keep the mode off. A board left in notes mode
    /// cannot be completed, and a beginner has no way to work out why.
    var showsNotes = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Balanced rows rather than a hard column cap.
    ///
    /// A flat `min(size, 5)` leaves a 6×6's lone "6" stranded on its own row,
    /// which reads as a layout bug. Splitting into the fewest rows that fit five
    /// per row, then dividing evenly, gives 6 → 3+3 and 9 → 5+4.
    private var columnCount: Int {
        let size = game.puzzle.size
        let rows = Int(ceil(Double(size) / 5.0))
        return Int(ceil(Double(size) / Double(max(rows, 1))))
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount)
    }

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(1...game.puzzle.size, id: \.self) { digit in
                    digitKey(digit)
                }
            }
            controls
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        let isArmed = game.activeDigit == digit
        // Only the Latin constraint, never the solver: dimming from full
        // propagation would leak the unique solution.
        let blocked = game.selected.map { game.isBlocked(digit: digit, at: $0) } ?? false

        return Button {
            if let onDigit { onDigit(digit) } else { game.press(digit) }
        } label: {
            Text("\(digit)")
                .font(Theme.padDigitFont)
                .foregroundStyle(isArmed ? Theme.paper : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    RoundedRectangle(cornerRadius: Layout.Radius.control, style: .continuous)
                        .fill(isArmed ? Theme.tierAccent(game.difficulty) : Theme.surface)
                )
                .opacity(blocked ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : Motion.noteFlip, value: isArmed)
        .accessibilityLabel("Digit \(digit)")
        .accessibilityHint(game.selected == nil
                           ? "Highlights this digit on the grid"
                           : "Places this digit in the selected cell")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            if showsNotes {
                controlKey(
                    symbol: game.notesMode ? "pencil.circle.fill" : "pencil.circle",
                    label: "Notes",
                    active: game.notesMode
                ) {
                    game.notesMode.toggle()
                    Haptics.note()
                }
            }

            controlKey(symbol: "arrow.uturn.backward", label: "Undo", enabled: game.canUndo) {
                if let onUndo { onUndo() } else { game.undo() }
            }

            controlKey(symbol: "delete.left", label: "Erase",
                       enabled: game.selected != nil) {
                if let onErase {
                    onErase()
                } else if let cell = game.selected {
                    game.clear(at: cell)
                }
            }
        }
    }

    private func controlKey(
        symbol: String,
        label: String,
        active: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(Theme.heading)
                .foregroundStyle(active ? Theme.paper : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Layout.Radius.control, style: .continuous)
                        .fill(active ? Theme.tierAccent(game.difficulty) : Theme.surface)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}
