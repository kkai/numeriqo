//
//  CellView.swift
//  Numeriqo
//

import SwiftUI

struct CellView: View {
    let game: NumeriqoGame
    let cell: Cell
    let geometry: BoardGeometry
    /// Position in the current hint's witness sequence, if this cell is in it.
    var argumentIndex: Int?
    /// Candidates the current hint rules out here. Struck through in place, so
    /// the player sees *which* possibilities the argument removed.
    var eliminated: Set<Int> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var entryScale: CGFloat = 1

    private var entry: Int? { game.board.entries[cell] }
    private var isClueAnchor: Bool { game.puzzle.cage(containing: cell)?.anchor == cell }
    private var isSelected: Bool { game.selected == cell }
    private var isWrong: Bool { entry != nil && game.incorrectCells.contains(cell) }
    private var isPeerOfSelection: Bool {
        guard let selected = game.selected, selected != cell else { return false }
        return selected.row == cell.row || selected.col == cell.col
    }
    /// Number-first: the armed digit lights every instance of itself. That
    /// highlight is a scanning lesson, not decoration.
    private var matchesActiveDigit: Bool {
        guard let digit = game.activeDigit else { return false }
        return entry == digit
    }

    // Split into small pieces on purpose: as one expression the ZStack, the
    // state ternaries and the modifier chain exceed the type checker's budget.
    var body: some View {
        ZStack {
            background
            content
        }
        .frame(width: geometry.cellSize, height: geometry.cellSize)
        .overlay { selectionBorder }
        .animation(reduceMotion ? nil : Motion.selection, value: isSelected)
        .animation(reduceMotion ? nil : Motion.noteFlip, value: isWrong)
        // Witnesses light in the order the solver found them, which is what
        // makes the argument read as a sequence of steps.
        .animation(
            reduceMotion
                ? nil
                : Motion.argumentFocus.delay(Double(argumentIndex ?? 0) * Motion.argumentStagger),
            value: argumentIndex
        )
        .onChange(of: entry) { old, new in
            guard new != nil, old != new, !reduceMotion else { return }
            entryScale = 1.15
            withAnimation(Motion.digitEntry) { entryScale = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityActions { cageActions }
    }

    /// Moving between cells of the same cage.
    ///
    /// Cage membership is exactly what the drawn outline conveys and speech
    /// cannot: a VoiceOver user swiping cell by cell gets reading order, which
    /// says nothing about which cells share a target. These actions make the
    /// cage traversable directly.
    @ViewBuilder
    private var cageActions: some View {
        if let cage = game.puzzle.cage(containing: cell), cage.cells.count > 1 {
            let others = cage.cells.filter { $0 != cell }
            ForEach(Array(others.enumerated()), id: \.offset) { _, other in
                Button("Go to row \(other.row + 1), column \(other.col + 1) in this cage") {
                    game.selected = other
                    AccessibilityNotification.Announcement(
                        "Row \(other.row + 1), column \(other.col + 1)"
                    ).post()
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let entry {
            Text("\(entry)")
                .font(Theme.digitFont(size: geometry.digitSize))
                .foregroundStyle(isWrong ? Theme.error : Theme.ink)
                .scaleEffect(entryScale)
                .offset(y: isClueAnchor ? geometry.clueGutter * 0.34 : 0)
        } else {
            NotesView(
                notes: game.board.notes(at: cell),
                eliminated: eliminated,
                size: game.puzzle.size,
                geometry: geometry,
                accent: Theme.tierAccent(game.difficulty),
                // An anchor cell already carries its clue in the top-left, so
                // the notes start below it rather than printing through it.
                topInset: isClueAnchor ? geometry.clueGutter : 0
            )
        }
    }

    @ViewBuilder
    private var selectionBorder: some View {
        if isSelected {
            Rectangle().strokeBorder(Theme.tierAccent(game.difficulty), lineWidth: 2)
        }
    }

    /// Ordered precedence — the most specific state wins.
    @ViewBuilder
    private var background: some View {
        if argumentIndex != nil {
            Theme.tierWash(game.difficulty, strength: 2.0)
        } else if isWrong {
            Theme.error.opacity(0.12)
        } else if isSelected {
            Theme.tierWash(game.difficulty, strength: 1.6)
        } else if matchesActiveDigit {
            Theme.tierWash(game.difficulty, strength: 1.4)
        } else if isPeerOfSelection {
            Theme.tierWash(game.difficulty, strength: 0.5)
        } else {
            Color.clear
        }
    }

    /// Cage membership is exactly what the visual outline encodes and speech
    /// cannot, so it has to be spoken explicitly.
    private var accessibilityLabel: String {
        var parts = ["Row \(cell.row + 1), column \(cell.col + 1)"]

        if let entry {
            parts.append("\(entry)")
            if isWrong { parts.append("incorrect") }
        } else {
            let notes = game.board.notes(at: cell).sorted()
            parts.append(notes.isEmpty ? "empty" : "notes \(notes.map(String.init).joined(separator: ", "))")
        }

        if let cage = game.puzzle.cage(containing: cell) {
            let operation = cage.isFreebie ? "free cell" : spoken(cage.operation)
            parts.append(cage.isFreebie
                ? "\(operation) \(cage.target)"
                : "cage \(cage.target) \(operation), \(cage.cells.count) cells")
        }
        return parts.joined(separator: ", ")
    }

    private func spoken(_ operation: Operation) -> String {
        switch operation {
        case .none: "free"
        case .add: "plus"
        case .subtract: "minus"
        case .multiply: "times"
        case .divide: "divided by"
        }
    }
}

// MARK: - Notes

/// Pencil marks as a micro-grid.
///
/// Unlike Sudoku this cannot assume 3×3 — a 6×6 Calcudoku uses 1–6, a 4×4 uses
/// 1–4. Absent digits still occupy their slot so the marks never reflow as they
/// are added and removed.
struct NotesView: View {
    let notes: Set<Int>
    var eliminated: Set<Int> = []
    let size: Int
    let geometry: BoardGeometry
    /// `Theme.accent`, never `.accentColor`. Always overridden at the one call
    /// site today, but a live default reaching the asset catalogue is how a
    /// future caller silently renders the system blue on an ink board.
    var accent: Color = Theme.accent
    var topInset: CGFloat = 0

    private var columns: Int { size <= 4 ? 2 : 3 }
    private var rows: Int { Int(ceil(Double(size) / Double(columns))) }

    var body: some View {
        if !notes.isEmpty {
            VStack(spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<columns, id: \.self) { column in
                            note(row * columns + column + 1)
                        }
                    }
                }
            }
            .padding(geometry.cellSize * 0.07)
            .padding(.top, topInset)
        }
    }

    @ViewBuilder
    private func note(_ digit: Int) -> some View {
        let present = digit <= size && notes.contains(digit)
        let struck = present && eliminated.contains(digit)

        // A space holds the slot when a digit is absent, so marks never reflow
        // as they are added and removed.
        Text(present ? "\(digit)" : " ")
            .font(Theme.noteFont(size: geometry.noteSize))
            .foregroundStyle(struck ? accent : Theme.inkSecondary)
            .overlay {
                if struck {
                    Capsule()
                        .fill(accent)
                        .frame(height: 1.2)
                        .frame(maxWidth: geometry.noteSize * 0.9)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
