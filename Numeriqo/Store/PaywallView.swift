//
//  PaywallView.swift
//  Numeriqo
//

import SwiftUI

/// Which feature the player just bumped into, so the sheet leads with it.
struct PaywallContext: Identifiable, Equatable {
    let feature: PaidFeature
    var id: String { feature.rawValue }
}

/// Owns paywall presentation for the whole app. One sheet at the root beats five
/// copies scattered through the view tree.
@Observable @MainActor
final class PaywallPresenter {
    private(set) var context: PaywallContext?
    func present(_ feature: PaidFeature) { context = PaywallContext(feature: feature) }
    func dismiss() { context = nil }
}

struct PaywallView: View {
    let context: PaywallContext

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.Space.section) {
                header
                featureList
                controls
            }
            .padding(Layout.Space.section)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.paper)
        .presentationBackground(Theme.paper)
        // Swipe-to-dismiss was the only exit, and it competes with the scroll
        // view. That is a trap for VoiceOver and Switch Control users.
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                    .frame(width: Layout.minimumTarget, height: Layout.minimumTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .task { await entitlements.loadProduct() }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(context.feature.headline)
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text(context.feature.pitch)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("The full game includes")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
                .textCase(.uppercase)
            ForEach(PaidFeature.allCases) { feature in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(feature.headline)
                        .font(.subheadline)
                        .foregroundStyle(feature == context.feature ? Theme.ink : Theme.inkSecondary)
                        .fontWeight(feature == context.feature ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
            }
        }
        .card(padding: Layout.Space.block)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            Button {
                Task { await entitlements.purchase() }
            } label: {
                Group {
                    if entitlements.purchaseState == .purchasing {
                        ProgressView().tint(Theme.paper)
                    } else {
                        // Never hardcode the price — App Review rejects a button
                        // that disagrees with the real localized price.
                        Text(entitlements.product.map { "Unlock everything · \($0.displayPrice)" }
                             ?? "Unlock everything")
                            .font(.headline)
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(entitlements.purchaseState == .purchasing)

            Text("One purchase, and that's the whole game.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSecondary)

            Button("Restore purchases") { Task { await entitlements.restore() } }
                .buttonStyle(.quiet)
                .disabled(entitlements.purchaseState == .restoring)

            if case .failed(let message) = entitlements.purchaseState {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
