//
//  BoardView.swift
//  Numeriqo
//
//  Ink on paper. Cages are drawn as strokes, never fills.
//
//  Every Calcudoku app on the store tints cages pastel, which spends the
//  strongest signal on screen — colour — on static structure the player has
//  memorised in ten seconds. Withholding it is what lets a hint's drawn argument
//  land. See docs/DESIGN.md §1.
//

import SwiftUI

struct BoardView: View {
    let game: NumeriqoGame
    /// The hint being shown, if any. Carried whole rather than as a set of
    /// cells: `focusCells` is ordered, and that order is what lets the argument
    /// light up as a sequence of steps rather than all at once.
    var step: TechniqueApplication?
    /// Cells to light for their own sake, with no technique behind them.
    ///
    /// Separate from `step` rather than a synthetic `TechniqueApplication`,
    /// because the tutorial points at cages before the player has met a single
    /// technique, and a fake one would name a deduction that isn't happening.
    var highlight: [Cell] = []
    var onTap: ((Cell) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    /// Digits the current hint rules out, per cell.
    private var eliminatedByCell: [Cell: Set<Int>] {
        guard let step else { return [:] }
        var out: [Cell: Set<Int>] = [:]
        for elimination in step.eliminations {
            out[elimination.cell, default: []].formUnion(DigitSet.digits(elimination.digits))
        }
        return out
    }

    private var argumentIndex: [Cell: Int] {
        // A hint's focus cells win when both are set; `highlight` is the
        // tutorial's channel and the two never appear together.
        let ordered = step?.focusCells ?? highlight
        guard !ordered.isEmpty else { return [:] }
        // `uniquingKeysWith` because a technique may legitimately list a cell
        // twice; the first mention is the one that orders the reveal.
        return Dictionary(
            ordered.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(size: game.puzzle.size, container: proxy.size)

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Theme.surface)
                    .frame(width: geo.boardLength, height: geo.boardLength)
                    .offset(x: geo.origin.x, y: geo.origin.y)

                cells(geo)
                cellRules(geo)
                cageOutlines(geo)
                clueLabels(geo)

                if let step {
                    ArgumentOverlay(
                        step: step,
                        puzzle: game.puzzle,
                        geometry: geo,
                        difficulty: game.difficulty
                    )
                    .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard let cell = geo.cell(at: location) else { return }
                (onTap ?? { game.tap($0) })(cell)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear { appeared = true }
    }

    // MARK: - Layers

    /// Divisions *inside* a cage, drawn dotted.
    ///
    /// Only between two cells of the same cage — a cage boundary is drawn solid
    /// by `cageOutlines` instead. Line style therefore encodes cage membership
    /// on its own, and no edge is ever drawn twice. Drawing a full grid *and*
    /// an inset cage outline gave every cage a doubled border, which is what
    /// made the board read as fussy rather than minimal.
    private func cellRules(_ geo: BoardGeometry) -> some View {
        Path { path in
            for row in 0..<geo.size {
                for col in 0..<geo.size {
                    let cell = Cell(row, col)
                    guard let cage = game.puzzle.cageIndex(containing: cell) else { continue }
                    let rect = geo.rect(for: cell)

                    // Right edge.
                    if col + 1 < geo.size,
                       game.puzzle.cageIndex(containing: Cell(row, col + 1)) == cage {
                        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                    // Bottom edge.
                    if row + 1 < geo.size,
                       game.puzzle.cageIndex(containing: Cell(row + 1, col)) == cage {
                        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                    }
                }
            }
        }
        .stroke(
            Theme.cellRule,
            style: StrokeStyle(lineWidth: 1, dash: [2, 3])
        )
    }

    private func cells(_ geo: BoardGeometry) -> some View {
        let index = argumentIndex
        let eliminated = eliminatedByCell
        return ForEach(game.puzzle.allCells, id: \.self) { cell in
            placedCell(
                cell, geo: geo,
                argumentIndex: index[cell],
                eliminated: eliminated[cell] ?? []
            )
        }
    }

    /// Split out from `cells` deliberately: inline, the modifier chain plus the
    /// two ternaries exceeds the type checker's budget and fails to compile.
    @ViewBuilder
    private func placedCell(
        _ cell: Cell,
        geo: BoardGeometry,
        argumentIndex: Int?,
        eliminated: Set<Int>
    ) -> some View {
        let rect = geo.rect(for: cell)
        let shown: Bool = appeared || reduceMotion
        let delay: Double = Double(cell.row + cell.col) * Motion.boardEntranceStagger

        CellView(
            game: game, cell: cell, geometry: geo,
            argumentIndex: argumentIndex, eliminated: eliminated
        )
            .frame(width: geo.cellSize, height: geo.cellSize)
            .opacity(shown ? 1 : 0)
            .offset(x: rect.minX, y: rect.minY + (shown ? 0 : 8))
            .animation(reduceMotion ? nil : Motion.boardEntrance.delay(delay), value: appeared)
    }

    /// Cage boundaries, drawn **on** the lattice with square corners.
    ///
    /// Not inset and not rounded. The inherited "soft rounded tile" look is what
    /// put three competing geometries on one board — square cells, rounded
    /// cages, square highlights — so a wash inside a rounded cage bled through
    /// its corners. One lattice, one corner treatment, no exceptions.
    private func cageOutlines(_ geo: BoardGeometry) -> some View {
        ForEach(Array(game.puzzle.cages.enumerated()), id: \.offset) { _, cage in
            let satisfied = game.isCageSatisfied(cage)
            CageOutline(cells: cage.cells, geometry: geo, inset: 0, cornerRadius: 0)
                .stroke(
                    satisfied ? Theme.tierAccent(game.difficulty) : Theme.cageRule,
                    style: StrokeStyle(lineWidth: 2, lineJoin: .miter)
                )
                .animation(reduceMotion ? nil : Motion.cageSatisfied, value: satisfied)
        }
    }

    /// Clue targets sit at the anchor cell's top-left. Never centred — the
    /// offset corner is part of the genre's grammar, and its asymmetry is what
    /// makes the grid read as a puzzle rather than a table.
    private func clueLabels(_ geo: BoardGeometry) -> some View {
        ForEach(Array(game.puzzle.cages.enumerated()), id: \.offset) { _, cage in
            Text(cage.clueText)
                .font(Theme.clueFont(size: geo.clueSize))
                .foregroundStyle(Theme.ink.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, geo.cellSize * 0.09)
                .frame(width: geo.cellSize, height: geo.clueGutter, alignment: .leading)
                .offset(x: geo.rect(for: cage.anchor).minX,
                        y: geo.rect(for: cage.anchor).minY + geo.cellSize * 0.04)
                .allowsHitTesting(false)
        }
    }
}
