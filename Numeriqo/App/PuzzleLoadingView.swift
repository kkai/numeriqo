//
//  PuzzleLoadingView.swift
//  Numeriqo
//
//  The board builds itself.
//
//  Generating a 9x9 with technique grading measures ~62ms median and ~191ms
//  worst in Release, so this is the exception rather than the rule — which is
//  exactly why it should be good. A rare screen that looks considered reads as
//  craft; a spinner does not.
//
//  It deliberately does NOT track real progress: node-budget progress is lumpy
//  and non-monotonic, and a bar that stalls at 80% is worse than no bar. The
//  grid animates on its own clock and simply stops when the puzzle arrives.
//  That is honest only because the node budget bounds the worst case.
//

import SwiftUI

struct PuzzleLoadingView: View {
    let size: Int
    /// Generation returned nothing. Before this the view simply animated
    /// forever: three code paths ended in `guard let generated else { return }`,
    /// so a failed generate left the player staring at a grid that would never
    /// fill, on the app's primary action.
    var failed = false
    var onRetry: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false

    var body: some View {
        if failed {
            failureState
        } else {
            buildingState
        }
    }

    private var failureState: some View {
        VStack(spacing: Layout.Space.step) {
            Image(systemName: "square.grid.3x3.slash")
                .font(Theme.title)
                .foregroundStyle(Theme.inkSecondary)
            Text("That one wouldn't come together")
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text("Every puzzle is checked for a single solution before you see it, and this one didn't pass. Trying again builds a different grid.")
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let onRetry {
                Button("Try again", action: onRetry)
                    .buttonStyle(.primary)
                    .padding(.top, Layout.Space.snug)
            }
        }
        .padding(Layout.Space.section)
        .frame(maxWidth: 420)
        .accessibilityElement(children: .contain)
    }

    private var buildingState: some View {
        GeometryReader { proxy in
            let geo = BoardGeometry(size: size, container: proxy.size)
            ZStack(alignment: .topLeading) {
                Path { path in
                    for i in 0...geo.size {
                        let offset = CGFloat(i) * geo.cellSize
                        path.move(to: CGPoint(x: geo.origin.x, y: geo.origin.y + offset))
                        path.addLine(to: CGPoint(x: geo.origin.x + geo.boardLength,
                                                 y: geo.origin.y + offset))
                        path.move(to: CGPoint(x: geo.origin.x + offset, y: geo.origin.y))
                        path.addLine(to: CGPoint(x: geo.origin.x + offset,
                                                 y: geo.origin.y + geo.boardLength))
                    }
                }
                .stroke(Theme.cellRule, style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .opacity(drawn ? 1 : 0.25)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 12)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
            value: drawn
        )
        .onAppear { drawn = true }
        .accessibilityElement()
        .accessibilityLabel("Building a \(size) by \(size) puzzle")
    }
}
