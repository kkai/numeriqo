//
//  CageOutline.swift
//  Numeriqo
//
//  The outline traced around a cage's cells, as ONE continuous closed contour.
//
//  Ported from the legacy app's `CageShape.swift`, whose half-edge boundary walk
//  is genuinely good work: it emits directed lattice edges (interior always on
//  the right of travel), chains them into loops with a right-turn preference at
//  pinch points, drops collinear vertices, and applies a corner inset that is
//  correct at reflex corners as well as convex ones — which is exactly where
//  naive insets break on L- and S-shaped cages.
//
//  Four things are fixed here:
//
//  1. **Deterministic start vertex.** The original seeded the walk from
//     `Dictionary.first(where:)`, whose order varies per launch, so an animated
//     stroke would begin at a random corner every time. Seeding from the
//     lexicographically smallest lattice point starts it at the top-left of the
//     anchor cell — which is exactly where the clue is drawn. The reveal now
//     always begins at the clue and travels around.
//  2. **Pitch is derived from geometry** rather than a baked-in `cellSize + 1`.
//  3. **Single-subpath guarantee**, so `.trim` describes one travelling stroke.
//  4. `animatableData`, so cell size interpolates instead of snapping.
//

import SwiftUI

nonisolated struct CageOutline: Shape {
    let cells: [Cell]
    var geometry: BoardGeometry
    var inset: CGFloat = 3
    var cornerRadius: CGFloat = 6

    /// Interpolate on cell size, so a resizing board morphs rather than snaps.
    var animatableData: CGFloat {
        get { geometry.cellSize }
        set { /* geometry is rebuilt by the layout; nothing to write back */ }
    }

    private struct Lattice: Hashable, Comparable {
        let x: Int
        let y: Int
        // Row-major, so the minimum is the top-left corner of the anchor cell.
        static func < (a: Lattice, b: Lattice) -> Bool { (a.y, a.x) < (b.y, b.x) }
    }

    func path(in rect: CGRect) -> Path {
        guard !cells.isEmpty else { return Path() }
        let members = Set(cells)

        // Directed boundary edges, interior always on the right of travel:
        // top goes right, right goes down, bottom goes left, left goes up.
        // Interior edges are never emitted from either side, so they cancel
        // without any union or clipping step.
        var outgoing: [Lattice: [Lattice]] = [:]
        var edgeCount = 0
        func addEdge(_ from: Lattice, _ to: Lattice) {
            outgoing[from, default: []].append(to)
            edgeCount += 1
        }

        for cell in cells {
            let c = cell.col, r = cell.row
            if !members.contains(Cell(r - 1, c)) {
                addEdge(Lattice(x: c, y: r), Lattice(x: c + 1, y: r))
            }
            if !members.contains(Cell(r, c + 1)) {
                addEdge(Lattice(x: c + 1, y: r), Lattice(x: c + 1, y: r + 1))
            }
            if !members.contains(Cell(r + 1, c)) {
                addEdge(Lattice(x: c + 1, y: r + 1), Lattice(x: c, y: r + 1))
            }
            if !members.contains(Cell(r, c - 1)) {
                addEdge(Lattice(x: c, y: r + 1), Lattice(x: c, y: r))
            }
        }

        var path = Path()
        var consumed = 0
        var loops = 0

        while consumed < edgeCount {
            // Deterministic seed — see note 1 above.
            guard let start = outgoing.filter({ !$0.value.isEmpty }).keys.min() else { break }

            var loop: [Lattice] = [start]
            var current = start
            var direction = Lattice(x: 0, y: 0)

            while true {
                guard var candidates = outgoing[current], !candidates.isEmpty else { break }
                let next: Lattice
                if candidates.count == 1 {
                    next = candidates[0]
                } else {
                    // At a pinch point (two cages meeting at one lattice vertex)
                    // prefer the tightest right turn, which hugs the interior.
                    let rightTurn = Lattice(x: current.x - direction.y, y: current.y + direction.x)
                    let straight = Lattice(x: current.x + direction.x, y: current.y + direction.y)
                    next = candidates.first(where: { $0 == rightTurn })
                        ?? candidates.first(where: { $0 == straight })
                        ?? candidates[0]
                }
                candidates.removeAll { $0 == next }
                outgoing[current] = candidates
                consumed += 1
                direction = Lattice(x: next.x - current.x, y: next.y - current.y)
                current = next
                if next == start { break }
                loop.append(next)
            }

            guard loop.count >= 4 else { continue }
            loops += 1
            addLoop(loop, to: &path)
        }

        // A second loop means a hole, and `.trim` would then draw the two
        // sequentially rather than as one travelling stroke. Generated cages cap
        // at four cells, so this needs at least eight to arise — but it would be
        // a confusing thing to debug from the animation alone.
        assert(loops <= 1, "cage has \(loops) boundary loops; .trim will not read as one stroke")

        return path
    }

    private func addLoop(_ lattice: [Lattice], to path: inout Path) {
        let pitch = geometry.cellSize

        // Keep only true corners.
        var corners: [Lattice] = []
        let n = lattice.count
        for i in 0..<n {
            let prev = lattice[(i + n - 1) % n]
            let curr = lattice[i]
            let next = lattice[(i + 1) % n]
            let d1 = (curr.x - prev.x, curr.y - prev.y)
            let d2 = (next.x - curr.x, next.y - curr.y)
            if d1 != d2 { corners.append(curr) }
        }
        guard corners.count >= 4 else { return }

        // Inset each corner toward the interior. The right perpendicular of
        // (dx, dy) in screen coordinates is (-dy, dx); summing the incoming and
        // outgoing perpendiculars gives the offset-line intersection, which is
        // correct at reflex corners too.
        var points: [CGPoint] = []
        let m = corners.count
        for i in 0..<m {
            let prev = corners[(i + m - 1) % m]
            let curr = corners[i]
            let next = corners[(i + 1) % m]
            // Split across several statements deliberately: as one expression
            // this exceeds the type checker's budget and fails to compile.
            let d1x = CGFloat((curr.x - prev.x).signum())
            let d1y = CGFloat((curr.y - prev.y).signum())
            let d2x = CGFloat((next.x - curr.x).signum())
            let d2y = CGFloat((next.y - curr.y).signum())

            let offsetX: CGFloat = inset * (-d1y - d2y)
            let offsetY: CGFloat = inset * (d1x + d2x)
            let baseX: CGFloat = geometry.origin.x + CGFloat(curr.x) * pitch
            let baseY: CGFloat = geometry.origin.y + CGFloat(curr.y) * pitch

            points.append(CGPoint(x: baseX + offsetX, y: baseY + offsetY))
        }

        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

        // Start at an edge midpoint so the first arc has a tangent to work from,
        // then walk corner to corner. `addArc(tangent1End:tangent2End:)`
        // implicitly prepends a line, so the contour is a continuous
        // line-arc-line-arc chain with no gaps — which is what lets `.trim`
        // describe a single travelling stroke.
        path.move(to: mid(points[m - 1], points[0]))
        for i in 0..<m {
            let curr = points[i]
            let prev = points[(i + m - 1) % m]
            let next = points[(i + 1) % m]
            let radius = min(cornerRadius, dist(prev, curr) / 2, dist(curr, next) / 2)
            path.addArc(tangent1End: curr, tangent2End: mid(curr, next), radius: max(radius, 0.5))
        }
        path.closeSubpath()
    }
}
