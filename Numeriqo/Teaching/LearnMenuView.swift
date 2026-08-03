//
//  LearnMenuView.swift
//  Numeriqo
//
//  The curriculum, in order, showing what the player has earned.
//
//  This is the same list as the technique ladder, the difficulty tiers and the
//  hint vocabulary. One spine, four views.
//

import SwiftUI

struct LearnMenuView: View {
    @Binding var path: [Route]

    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    @State private var lockedExplanation: String?

    var body: some View {
        List {
            Section {
                row(technique: nil,
                    title: "How Numeriqo works",
                    subtitle: "Rows, columns, cages and the four operators")
            }

            Section {
                ForEach(Technique.allCases) { technique in
                    row(technique: technique,
                        title: technique.displayName,
                        subtitle: TechniqueContent.summary(for: technique))
                }
            } header: {
                Text("Techniques")
            } footer: {
                // Thirteen padlocks under a bare "Techniques" heading read as a
                // demo build rather than a curriculum. Saying how many are open
                // and what opens the next one turns the same list into a path.
                Text(openCount == Technique.allCases.count
                     ? "All \(openCount) techniques are open. Revisit any of them whenever a grid stops making sense."
                     : "\(openCount) of \(Technique.allCases.count) open. Each one unlocks when you've finished the lesson before it.")
            }
        }
        .listStyle(.insetGrouped)
        // The app is ink on paper everywhere else. A grouped list is the
        // only surface that was not, so walking Home to here changed the
        // wall colour and the card radius mid-flow.
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Learn")
        // A real binding, not `.constant`: SwiftUI cannot write false back
        // through a constant, so any dismissal other than the button left the
        // state set and the alert re-presented itself.
        .alert("Not yet", isPresented: Binding(
            get: { lockedExplanation != nil },
            set: { if !$0 { lockedExplanation = nil } }
        )) {
            Button("OK") { lockedExplanation = nil }
        } message: {
            Text(lockedExplanation ?? "")
        }
    }

    /// The one lesson to do next: the first that is open and not yet finished.
    ///
    /// Without it the list is seventeen equal rows and no answer to "where was
    /// I?". A curriculum that does not say what is next is a glossary.
    private var nextUp: Technique? {
        Technique.allCases.first {
            mastery.state(of: $0) != .locked
                && mastery.state(of: $0) != .learned
                && FeatureGate.isLessonAvailable($0, unlocked: entitlements.isUnlocked)
        }
    }

    /// Techniques the player can actually open right now — neither locked
    /// behind mastery nor behind the paywall.
    private var openCount: Int {
        Technique.allCases.filter {
            mastery.state(of: $0) != .locked
                && FeatureGate.isLessonAvailable($0, unlocked: entitlements.isUnlocked)
        }.count
    }

    @ViewBuilder
    private func row(technique: Technique?, title: String, subtitle: String) -> some View {
        let state = technique.map { mastery.state(of: $0) } ?? .learned
        // Two different locks. A mastery-locked row is genuinely unreachable, so
        // it stays disabled. A paywalled row stays tappable and opens the
        // paywall — a dead row neither teaches nor sells.
        let masteryLocked = state == .locked
        let paywalled = !FeatureGate.isLessonAvailable(technique, unlocked: entitlements.isUnlocked)

        Button {
            if paywalled {
                paywall.present(.advancedLessons)
            } else if masteryLocked, let technique {
                lockedExplanation = lockedReason(for: technique)
            } else {
                path.append(.lesson(technique))
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                badge(state: state, paywalled: paywalled)
                // Both lines take `fixedSize` vertically. Without it a row keeps
                // the height a List gives a single line and crops the text
                // instead of growing, which is the "Text clipped" the audit was
                // conceding at large Dynamic Type.
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(Theme.caption)
                        .foregroundStyle(Theme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if technique != nil, technique == nextUp {
                    Text("Next").eyebrow(Theme.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Deliberately NOT `.disabled()`. SwiftUI dims a disabled button, which
        // `performAccessibilityAudit` correctly reported as failing contrast —
        // and a dead grey row teaches nothing anyway. A locked row stays
        // readable and says what unlocks it.
        .accessibilityLabel(title)
        .accessibilityValue(spoken(state, paywalled: paywalled))
    }

    /// Two locks used to draw the same padlock, which is the single thing that
    /// made this list hard to read: "you have not got here yet" and "this costs
    /// money" are different answers to *why can I not tap it*, and a player
    /// staring at fourteen identical padlocks cannot tell which is which.
    /// A padlock now means money and nothing else.
    @ViewBuilder
    private func badge(state: MasteryTracker.MasteryState, paywalled: Bool) -> some View {
        Group {
            if paywalled {
                Image(systemName: "lock.fill")
            } else {
                switch state {
                case .locked: Image(systemName: "circle.dotted")
                case .introduced: Image(systemName: "circle")
                case .practicing: Image(systemName: "circle.lefthalf.filled")
                case .learned: Image(systemName: "checkmark.circle.fill")
                }
            }
        }
        // A semantic style, not a fixed 15pt: the audit flagged the fixed size
        // as unscaling, and the fixed 20pt frame clipped the glyph once type
        // grew. `minWidth` keeps the rows aligned without capping the glyph.
        .font(Theme.heading)
        .foregroundStyle(state == .learned && !paywalled ? Theme.accent : Theme.ink)
        .frame(minWidth: 22)
        // The badge is decorative; state is re-announced via accessibilityValue.
        .accessibilityHidden(true)
    }

    /// What the player has to do to open this lesson.
    private func lockedReason(for technique: Technique) -> String {
        guard let previous = Technique(rawValue: technique.rawValue - 1) else {
            return "This one opens once you have started the curriculum."
        }
        return "\(technique.displayName) opens once you have worked through \(previous.displayName)."
    }

    private func spoken(_ state: MasteryTracker.MasteryState, paywalled: Bool) -> String {
        if paywalled { return "locked, included in the full game" }
        switch state {
        case .locked: return "locked"
        case .introduced: return "not started"
        case .practicing: return "in progress"
        case .learned: return "learned"
        }
    }
}
