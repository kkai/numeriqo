//
//  NumeriqoApp.swift
//  Numeriqo
//

import SwiftUI

@main
struct NumeriqoApp: App {
    @State private var progress: ProgressStore
    @State private var mastery: MasteryTracker
    @State private var entitlements: EntitlementStore
    @State private var paywall = PaywallPresenter()

    init() {
        Self.resetStateIfUITestingAsksFor()
        let store = ProgressStore()
        _progress = State(initialValue: store)
        // The tracker owns no storage; the store is injected.
        _mastery = State(initialValue: MasteryTracker(store: store))
        _entitlements = State(initialValue: EntitlementStore())
        // Applied here as well as on the toggle: a setting that only takes
        // effect after you change it is a setting that does nothing on launch.
        Haptics.enabled = store.settings.hapticsEnabled
    }

    /// Wipes saved state when a UI test asks for it.
    ///
    /// The first-run screens and the "you have a game in progress" warning are
    /// only reachable from particular states, and a UI test that inherits
    /// whatever the previous test left behind passes alone and fails in a full
    /// run. Must happen before any store reads defaults.
    ///
    /// **`#if DEBUG` is not optional here.** Without it a release binary carries
    /// a switch that deletes every best time, streak and saved game. Nothing in
    /// a shipped app should be one launch argument away from that, however
    /// awkward the argument is to pass.
    private static func resetStateIfUITestingAsksFor() {
        #if DEBUG
        guard CommandLine.arguments.contains("-uiTestResetState"),
              let domain = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(mastery)
                .environment(entitlements)
                .environment(paywall)
        }
    }
}
