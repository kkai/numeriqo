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
            CloseButton { dismiss() }
        }
        .task { await entitlements.loadProduct() }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.Space.snug) {
            Text(context.feature.headline)
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text(context.feature.pitch)
                .font(Theme.body)
                .foregroundStyle(Theme.inkSecondary)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Layout.Space.step) {
            Text("The full game includes").eyebrow()
            ForEach(PaidFeature.allCases) { feature in
                HStack(alignment: .firstTextBaseline, spacing: Layout.Space.snug) {
                    Image(systemName: "checkmark")
                        .font(Theme.caption.weight(.bold))
                        .foregroundStyle(Theme.accent)
                    Text(feature.headline)
                        .font(Theme.body)
                        .foregroundStyle(feature == context.feature ? Theme.ink : Theme.inkSecondary)
                        .fontWeight(feature == context.feature ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
            }
        }
        .card()
    }

    private var controls: some View {
        VStack(spacing: Layout.Space.step) {
            Button {
                Task { await entitlements.purchase() }
            } label: {
                Group {
                    if entitlements.purchaseState == .purchasing {
                        ProgressView().tint(Theme.paper)
                    } else if let product = entitlements.product {
                        // Never hardcode the price. App Review rejects a button
                        // that disagrees with the real localized price, so this
                        // always comes from StoreKit.
                        Text("Unlock everything · \(product.displayPrice)")
                    } else {
                        Text("Unlock everything")
                    }
                }
            }
            .buttonStyle(.primary)
            .disabled(entitlements.purchaseState == .purchasing)

            // Says which of the two silent states you are in. Without this the
            // button reads as a finished control that simply has no price, and
            // a store that never answered looks identical to a free upgrade.
            Group {
                if entitlements.product != nil {
                    Text("One purchase, and that's the whole game.")
                } else if entitlements.purchaseState == .loadingProduct {
                    Text("Fetching the price…")
                } else {
                    Text("The App Store hasn't sent a price yet. Tapping will try again.")
                }
            }
            .font(Theme.secondary)
            .foregroundStyle(Theme.inkSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Button("Restore purchases") { Task { await entitlements.restore() } }
                .buttonStyle(.quiet)
                .disabled(entitlements.purchaseState == .restoring)

            if case .failed(let message) = entitlements.purchaseState {
                Text(message)
                    .font(Theme.secondary)
                    .foregroundStyle(Theme.error)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
