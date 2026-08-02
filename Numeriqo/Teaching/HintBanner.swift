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
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            footer
        }
        .card()
        .padding(.horizontal, Layout.Space.gutter)
        .accessibilityElement(children: .contain)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(reduceMotion ? nil : Motion.overlay, value: hint.level)
    }

    private var header: some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(hint.isError ? Theme.error : Theme.ink)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    // A 44pt target, without a 44pt glyph.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    .font(.footnote.weight(.medium))
                    .tint(Theme.ink)
            } else if hint.level < .resolution {
                Button("Tell me more", action: onMore)
                    .font(.footnote.weight(.medium))
                    .tint(Theme.ink)
                    .accessibilityHint("Shows one more step of the reasoning")
            }

            Spacer()

            if hint.level == .resolution, !hint.isError, hint.step != nil {
                Button(action: onApply) {
                    Text("Apply")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, Layout.Space.block)
                        .frame(minHeight: Layout.minimumTarget)
                        .background(Capsule().fill(Theme.ink))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
