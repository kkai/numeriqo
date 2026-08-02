//
//  StatsView.swift
//  Numeriqo
//
//  Best times are free; the rest is not. 2.x tracked best times, and 3.0 never
//  removes something 2.x gave away.
//

import SwiftUI

struct StatsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        List {
            Section("Best times") {
                let times = progress.bestTimes.sorted {
                    ($0.key.size, $0.key.difficulty.order) < ($1.key.size, $1.key.difficulty.order)
                }
                if times.isEmpty {
                    Text("Solve a puzzle and your best time lands here.")
                        .font(.footnote).foregroundStyle(Theme.inkSecondary)
                }
                ForEach(times, id: \.key) { key, time in
                    LabeledContent("\(key.size)×\(key.size) · \(key.difficulty.displayName)",
                                   value: format(time))
                        .font(.subheadline)
                }
            }

            if FeatureGate.areFullStatsAvailable(unlocked: entitlements.isUnlocked) {
                Section("Solves") {
                    LabeledContent("Puzzles solved", value: "\(progress.stats.puzzlesSolved)")
                    LabeledContent("Daily streak", value: "\(progress.daily.currentStreak)")
                    LabeledContent("Best streak", value: "\(progress.daily.bestStreak)")
                }

                Section("Skill") {
                    ForEach(Technique.allCases) { technique in
                        let record = mastery.record(for: technique)
                        LabeledContent(technique.displayName) {
                            Text(record.state == .learned
                                 ? "Learned"
                                 : "\(record.unaidedUses)/\(MasteryTracker.learnedThreshold)")
                        }
                        .font(.footnote)
                    }
                }
            } else {
                Section {
                    Button("See your full progress") { paywall.present(.stats) }
                        .font(.subheadline)
                } footer: {
                    Text("Solve counts, streaks, and how far you've got with each of the 16 techniques.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Progress")
    }

    private func format(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
