//
//  HintBanner.swift
//  Numeriqo
//
//  The ladder's face. "Tell me more" climbs a rung; Apply appears only at the
//  last one, so taking the answer is a deliberate act rather than the default.
//

import SwiftUI

struct HintBanner: View {
    let hint: Hint
    let onMore: () -> Void
    let onApply: () -> Void
    let onDismiss: () -> Void
    var onUnlock: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Space.snug) {
            header
            Text(hint.text)
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .card()
        .accessibilityElement(children: .contain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? nil : Motion.overlay, value: hint.level)
    }

    private var header: some View {
        HStack {
            Text(title).eyebrow(hint.isError ? Theme.error : Theme.ink)
            Spacer()
            CloseButton(action: onDismiss)
                .accessibilityLabel("Dismiss hint")
        }
    }

    /// Level 1 and 2 deliberately differ: the first says only that something is
    /// there, the second names it. Showing the technique name at level 1 would
    /// collapse the ladder's first rung.
    private var title: String {
        if hint.isError { return "Check your work" }
        if hint.isLocked { return "Hint" }
        guard let step = hint.step else { return "Hint" }
        return hint.level >= .technique ? step.technique.displayName : "Hint"
    }

    @ViewBuilder
    private var footer: some View {
        HStack {
            if hint.isLocked {
                Button("Unlock hints", action: onUnlock)
                    .buttonStyle(.quiet)
            } else if hint.level < .resolution {
                Button("Tell me more", action: onMore)
                    .buttonStyle(.quiet)
                    .accessibilityHint("Shows one more step of the reasoning")
            }

            Spacer()

            if hint.level == .resolution, !hint.isError, hint.step != nil {
                // A compact primary, not a capsule. This was the app's second
                // primary shape, with its own corner and its own height.
                Button("Apply", action: onApply)
                    .buttonStyle(.primary(fills: false))
            }
        }
    }
}
