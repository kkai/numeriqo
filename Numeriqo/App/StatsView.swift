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
                        .font(Theme.secondary).foregroundStyle(Theme.inkSecondary)
                }
                // This is the table the type pass exists for: a right-aligned
                // numeric column set in proportional figures, where 4:07 and
                // 11:52 did not line up under each other.
                ForEach(times, id: \.key) { key, time in
                    LabeledContent {
                        Text(format(time)).font(Theme.numeral(.body))
                    } label: {
                        Text("\(key.size)×\(key.size) · \(key.difficulty.displayName)")
                            .font(Theme.steady(.body))
                    }
                }
            }

            if FeatureGate.areFullStatsAvailable(unlocked: entitlements.isUnlocked) {
                Section("Solves") {
                    counter("Puzzles solved", progress.stats.puzzlesSolved)
                    counter("Daily streak", progress.daily.currentStreak)
                    counter("Best streak", progress.daily.bestStreak)
                }

                Section("Skill") {
                    ForEach(Technique.allCases) { technique in
                        let record = mastery.record(for: technique)
                        LabeledContent {
                            if record.state == .learned {
                                Text("Learned").font(Theme.secondary)
                            } else {
                                Text("\(record.unaidedUses)/\(MasteryTracker.learnedThreshold)")
                                    .font(Theme.numeral(.footnote))
                            }
                        } label: {
                            Text(technique.displayName).font(Theme.secondary)
                        }
                    }
                }
            } else {
                Section {
                    Button("See your full progress") { paywall.present(.stats) }
                        .font(Theme.body)
                } footer: {
                    Text("Solve counts, streaks, and how far you've got with each of the 16 techniques.")
                }
            }
        }
        .listStyle(.insetGrouped)
        // The app is ink on paper everywhere else. A grouped list is the
        // only surface that was not, so walking Home to here changed the
        // wall colour and the card radius mid-flow.
        .scrollContentBackground(.hidden)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Progress")
    }

    private func counter(_ label: String, _ value: Int) -> some View {
        LabeledContent {
            Text("\(value)").font(Theme.numeral(.body))
        } label: {
            Text(label).font(Theme.steady(.body))
        }
    }

    private func format(_ time: TimeInterval) -> String {
        let total = Int(time.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
