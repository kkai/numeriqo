//
//  ThemeIsolationTests.swift
//  NumeriqoTests
//
//  Three independent guards against one specific crash.
//
//  The project builds with SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor. Without
//  `nonisolated`, `Theme` — and the provider closure it hands to
//  `UIColor(dynamicProvider:)` — is implicitly @MainActor. UIKit imports
//  `-initWithDynamicProvider:` without NS_SWIFT_SENDABLE, so the closure
//  inherits that isolation and Swift 6 emits an executor assertion in its
//  prologue. UIKit resolves dynamic colours on SwiftUI's
//  `com.apple.SwiftUI.AsyncRenderer` thread, which trips the assertion and traps
//  (EXC_BREAKPOINT).
//
//  This shipped in Just Kakuro. It fired intermittently — anywhere, including an
//  idle Home screen — because whether a given resolve lands off-main is a race.
//
//  Each guard below is independently sufficient. That redundancy is deliberate:
//  losing one annotation must not silently bring the trap back.
//

import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Numeriqo

@Suite struct ThemeIsolationTests {

    // MARK: - Guard 1: compile-time

    /// This function is `nonisolated` and reads every token. If `Theme` ever
    /// loses its `nonisolated`, the **test target stops compiling** — the
    /// failure arrives at build time rather than as a field crash report.
    private nonisolated func nonisolatedThemeColors() -> [Color] {
        [
            Theme.paper, Theme.surface, Theme.ink, Theme.inkSecondary,
            Theme.cellRule, Theme.cageRule, Theme.accent, Theme.error, Theme.clueInk,
        ] + Difficulty.allCases.flatMap { [Theme.tierAccent($0), Theme.tierWash($0)] }
    }

    @Test func themeIsReadableFromANonisolatedContext() {
        // Not a hardcoded count: the list is here to force every token through a
        // nonisolated context, and pinning a number only creates busywork when
        // a token is added.
        #expect(nonisolatedThemeColors().count >= 9)
    }

    // MARK: - Guard 2: runtime, off the main thread

    #if canImport(UIKit)
    /// Resolves every token off-main against both interface styles — the exact
    /// situation that used to trap.
    ///
    /// Known environment quirk, inherited from Kakuro: this can fail under
    /// serial (non-cloned) test runs because the `UIColor(Color)` round-trip
    /// loses its dynamic provider without a fresh host environment. That is a
    /// harness artefact. **Do not "fix" Theme because of it.**
    @Test func dynamicColorsResolveOffTheMainThread() async {
        struct Resolved: Sendable {
            let onMain: Bool
            let differing: Int
        }

        let result = await Task.detached { () -> Resolved in
            let light = UITraitCollection(userInterfaceStyle: .light)
            let dark = UITraitCollection(userInterfaceStyle: .dark)
            var differing = 0
            for color in [
                Theme.paper, Theme.surface, Theme.ink, Theme.inkSecondary,
                Theme.cellRule, Theme.cageRule, Theme.accent, Theme.error, Theme.clueInk,
            ] {
                let ui = UIColor(color)
                if ui.resolvedColor(with: light) != ui.resolvedColor(with: dark) {
                    differing += 1
                }
            }
            // `Thread.isMainThread` is unavailable from an async context, so
            // ask the runtime directly whether this is the main thread.
            let onMain = pthread_main_np() != 0
            return Resolved(onMain: onMain, differing: differing)
        }.value

        #expect(!result.onMain, "the detached task ran on main; this guard proved nothing")
        // If every token resolved identically in both styles, the provider was
        // never really exercised and this guard has quietly become a no-op.
        #expect(result.differing > 0,
                "no token differs between light and dark — the dynamic provider never ran")
    }
    #endif

    // MARK: - Guard 3: source scan

    /// The dangerous API may appear in exactly one file. `dynamicProvider:` is
    /// spelled out rather than used as a trailing closure precisely so it stays
    /// greppable.
    @Test func dynamicColorProvidersLiveOnlyInNonisolatedTheme() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // NumeriqoTests
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("Numeriqo")

        var offenders: [String] = []
        var themeSource = ""

        let enumerator = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        )
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "swift" else { continue }
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if url.lastPathComponent == "Theme.swift" { themeSource = source }
            if source.contains("dynamicProvider") || source.contains("UIColor {") {
                offenders.append(url.lastPathComponent)
            }
        }

        #expect(offenders == ["Theme.swift"],
                "dynamic colour providers must live only in Theme.swift; found \(offenders)")
        #expect(themeSource.contains("nonisolated enum Theme"),
                "Theme must be declared `nonisolated enum Theme`")
        #expect(themeSource.contains("@Sendable"),
                "the dynamic provider closure must be explicitly @Sendable")
    }
}
