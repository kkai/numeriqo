//
//  ArgumentOverlay.swift
//  Numeriqo
//
//  The signature moment: the hint's reasoning, drawn.
//
//  No competitor animates the *argument*. A stroke travelling from the two cells
//  of a locked cage along the row it constrains, ending on the cell it
//  eliminates, is the entire product thesis expressed in half a second. It is
//  only legible because the board around it is quiet — see docs/DESIGN.md §1.
//
//  Everything here is driven by data the solver already emits. A
//  `TechniqueApplication` carries `focusCells`, `involvedCages` and
//  `ExplanationData.line`; nothing extra is asked of the engine.
//

import SwiftUI

struct ArgumentOverlay: View {
    let step: TechniqueApplication
    let puzzle: Puzzle
    let geometry: BoardGeometry
    let difficulty: Difficulty

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: CGFloat = 0

    /// The connector is drawn only after the witnesses have lit, so the
    /// sequence reads as "look here… and here… therefore this".
    private var drawDelay: Double {
        Double(step.focusCells.count) * Motion.argumentStagger
    }

    var body: some View {
        ZStack {
            connector
                .trim(from: 0, to: drawn)
                .stroke(
                    Theme.tierAccent(difficulty),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
                .opacity(0.9)

        }
        .allowsHitTesting(false)
        .onAppear(perform: play)
        .onChange(of: step) { _, _ in
            drawn = 0
            play()
        }
    }

    private func play() {
        guard !reduceMotion else {
            // Reduce Motion must still show the whole argument — it may soften
            // how it arrives, never remove information.
            drawn = 1
            return
        }
        withAnimation(Motion.argumentDraw.delay(drawDelay)) { drawn = 1 }
    }

    // MARK: - The connector

    /// Three shapes of argument, in order of specificity.
    private var connector: Path {
        // 1. A cage-scoped deduction traces the cage itself. Because the
        //    outline's walk starts at the lexicographically smallest lattice
        //    point — the top-left of the anchor cell — the stroke always begins
        //    at the clue and travels around it.
        if let index = step.involvedCages.first, index < puzzle.cages.count {
            let cage = puzzle.cages[index]
            // Square, matching every other line on the board, and inset just
            // enough to read as a highlight *inside* the cage border rather
            // than redrawing it.
            return CageOutline(cells: cage.cells, geometry: geometry,
                               inset: 3, cornerRadius: 0)
                .path(in: geometry.boardRect)
        }

        // 2. A line-scoped deduction travels the row or column it argues about,
        //    spanning only the cells actually involved.
        if let line = step.explanation.line {
            return linePath(line)
        }

        // 3. Otherwise, join the witnesses in the order the solver found them.
        return polylineThroughWitnesses()
    }

    private func linePath(_ line: Line) -> Path {
        let touched = step.focusCells + step.eliminations.map(\.cell) + step.placements.map(\.cell)
        let relevant = touched.filter { line.contains($0) }
        guard !relevant.isEmpty else { return polylineThroughWitnesses() }

        let centers = relevant.map { geometry.center(for: $0) }
        var path = Path()
        switch line.kind {
        case .row:
            let y = centers[0].y
            let minX = centers.map(\.x).min()!
            let maxX = centers.map(\.x).max()!
            path.move(to: CGPoint(x: minX, y: y))
            path.addLine(to: CGPoint(x: maxX, y: y))
        case .column:
            let x = centers[0].x
            let minY = centers.map(\.y).min()!
            let maxY = centers.map(\.y).max()!
            path.move(to: CGPoint(x: x, y: minY))
            path.addLine(to: CGPoint(x: x, y: maxY))
        }
        return path
    }

    private func polylineThroughWitnesses() -> Path {
        let cells = step.focusCells.isEmpty
            ? step.placements.map(\.cell) + step.eliminations.map(\.cell)
            : step.focusCells
        guard cells.count > 1 else { return Path() }

        var path = Path()
        path.move(to: geometry.center(for: cells[0]))
        for cell in cells.dropFirst() {
            path.addLine(to: geometry.center(for: cell))
        }
        return path
    }

}
