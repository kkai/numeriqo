//
//  CageShape.swift
//  Numeriqo
//
//  Rounded outline around a cage's cells, inset so neighboring cages
//  read as separate soft tiles (2.0 "Icon Blue" design).
//

import SwiftUI

/// Traces the perimeter of a cage (an edge-connected set of grid cells),
/// insets it, and rounds the corners. Used for both cage fills and strokes.
struct CageShape: Shape {
    let positions: Set<Position>
    let cellSize: CGFloat
    var xOffset: CGFloat = 0
    var yOffset: CGFloat = 0
    var inset: CGFloat = 2.5
    var cornerRadius: CGFloat = 9

    private struct GridPoint: Hashable {
        let x: Int
        let y: Int
    }

    func path(in rect: CGRect) -> Path {
        let cells = positions
        guard !cells.isEmpty else { return Path() }

        // Directed boundary edges (interior always on the right of travel):
        // top edges go right, right edges go down, bottom left, left up.
        var outgoing: [GridPoint: [GridPoint]] = [:]
        var edgeCount = 0
        func addEdge(_ from: GridPoint, _ to: GridPoint) {
            outgoing[from, default: []].append(to)
            edgeCount += 1
        }
        for pos in positions {
            let c = pos.col, r = pos.row
            if !cells.contains(Position(row: r - 1, col: c)) {
                addEdge(GridPoint(x: c, y: r), GridPoint(x: c + 1, y: r))
            }
            if !cells.contains(Position(row: r, col: c + 1)) {
                addEdge(GridPoint(x: c + 1, y: r), GridPoint(x: c + 1, y: r + 1))
            }
            if !cells.contains(Position(row: r + 1, col: c)) {
                addEdge(GridPoint(x: c + 1, y: r + 1), GridPoint(x: c, y: r + 1))
            }
            if !cells.contains(Position(row: r, col: c - 1)) {
                addEdge(GridPoint(x: c, y: r + 1), GridPoint(x: c, y: r))
            }
        }

        var path = Path()
        var consumed = 0
        while consumed < edgeCount {
            guard let start = outgoing.first(where: { !$0.value.isEmpty })?.key else { break }
            var loop: [GridPoint] = [start]
            var current = start
            var direction = GridPoint(x: 0, y: 0)
            while true {
                guard var candidates = outgoing[current], !candidates.isEmpty else { break }
                // At pinch points prefer the tightest (right) turn to hug the interior.
                let next: GridPoint
                if candidates.count == 1 {
                    next = candidates[0]
                } else {
                    let rightTurn = GridPoint(x: current.x - direction.y, y: current.y + direction.x)
                    let straight = GridPoint(x: current.x + direction.x, y: current.y + direction.y)
                    next = candidates.first(where: { $0 == rightTurn })
                        ?? candidates.first(where: { $0 == straight })
                        ?? candidates[0]
                }
                candidates.removeAll { $0 == next }
                outgoing[current] = candidates
                consumed += 1
                direction = GridPoint(x: next.x - current.x, y: next.y - current.y)
                current = next
                if next == start { break }
                loop.append(next)
            }
            guard loop.count >= 4 else { continue }
            addLoop(loop, to: &path)
        }
        return path
    }

    private func addLoop(_ gridLoop: [GridPoint], to path: inout Path) {
        let pitch = cellSize + 1

        // Drop collinear vertices so only true corners remain.
        var corners: [GridPoint] = []
        let n = gridLoop.count
        for i in 0..<n {
            let prev = gridLoop[(i + n - 1) % n]
            let curr = gridLoop[i]
            let next = gridLoop[(i + 1) % n]
            let d1 = (curr.x - prev.x, curr.y - prev.y)
            let d2 = (next.x - curr.x, next.y - curr.y)
            if d1 != d2 { corners.append(curr) }
        }
        guard corners.count >= 4 else { return }

        // Inset each corner toward the interior (right side of travel).
        var points: [CGPoint] = []
        let m = corners.count
        for i in 0..<m {
            let prev = corners[(i + m - 1) % m]
            let curr = corners[i]
            let next = corners[(i + 1) % m]
            let d1x = CGFloat((curr.x - prev.x).signum()), d1y = CGFloat((curr.y - prev.y).signum())
            let d2x = CGFloat((next.x - curr.x).signum()), d2y = CGFloat((next.y - curr.y).signum())
            // right perpendicular of (dx, dy) in screen coords is (-dy, dx)
            let offsetX = inset * (-d1y + -d2y)
            let offsetY = inset * (d1x + d2x)
            points.append(CGPoint(
                x: CGFloat(curr.x) * pitch + xOffset + offsetX,
                y: CGFloat(curr.y) * pitch + yOffset + offsetY
            ))
        }

        // Rounded polygon via tangent arcs, radius clamped per vertex.
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            hypot(a.x - b.x, a.y - b.y)
        }

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
