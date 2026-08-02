//
//  SettingsView.swift
//  Numeriqo
//

import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        @Bindable var progress = progress

        List {
            Section {
                Toggle("Fill in candidates", isOn: $progress.settings.autoNotes)
                Toggle("Mark wrong digits", isOn: $progress.settings.showErrors)
            } footer: {
                Text("Candidates are filled from the simplest rules only, so nothing is solved for you. Wrong digits are marked as you place them, while you can still remember why.")
            }

            Section {
                Toggle("Tap the cell first", isOn: $progress.settings.cellFirstInput)
            } footer: {
                Text("By default you pick a number, then tap where it goes, which shows you every place that number already sits. Turn this on to select a cell first instead.")
            }

            Section {
                Toggle("Haptics", isOn: $progress.settings.hapticsEnabled)
            }

            storeSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .task { await entitlements.loadProduct() }
        .onChange(of: progress.settings.hapticsEnabled) { _, enabled in
            Haptics.enabled = enabled
        }
    }

    /// The store, reachable without first bumping into a locked feature.
    ///
    /// **Restore sits here unconditionally.** Before this it existed only inside
    /// the paywall sheet, which only opens when you hit a wall — so somebody who
    /// reinstalled and already owned the game had nowhere to restore from.
    @ViewBuilder
    private var storeSection: some View {
        if EntitlementStore.isUnlockedByBuild {
            proSection
        } else {
            purchasableSection
        }
    }

    /// Numeriqo Pro. One row saying so, and nothing to tap.
    ///
    /// No Restore: Restore is required of apps that *sell* in-app purchases,
    /// and Pro sells none. A Restore button that can only ever fail is worse
    /// than no button, and a store section with nothing purchasable in it reads
    /// as a bug rather than as generosity.
    private var proSection: some View {
        Section {
            LabeledContent("Everything", value: "Included")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Everything is included in Numeriqo Pro")
        } header: {
            Text("Numeriqo Pro")
        } footer: {
            Text("Every lesson, every drill, hints that teach, grids up to 9×9 and full progress. Yours already.")
        }
    }

    @ViewBuilder
    private var purchasableSection: some View {
        Section("Full game") {
            if entitlements.isUnlocked {
                LabeledContent("Full game", value: "Unlocked")
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Full game unlocked")
            } else {
                Button {
                    paywall.present(.advancedLessons)
                } label: {
                    HStack {
                        Text("Unlock everything")
                        Spacer()
                        // Empty until StoreKit answers. Without an explicit
                        // label the row reported "element has no description"
                        // in that window.
                        if let price = entitlements.product?.displayPrice {
                            Text(price).foregroundStyle(Theme.inkSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Unlock everything")
                .accessibilityValue(entitlements.product?.displayPrice ?? "Loading price")
            }

            Button("Restore purchases") {
                Task { await entitlements.restore() }
            }
            .disabled(entitlements.purchaseState == .restoring)

            if case .failed(let message) = entitlements.purchaseState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
            }
        }
    }
}
