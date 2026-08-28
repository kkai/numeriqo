//
//  PlatformSeams.swift
//  Numeriqo
//

import SwiftUI

#if os(iOS)
/// Switches off the edge swipe-back for as long as it is on screen.
///
/// The board is tap-only, so there is no drag to collide with the system's
/// interactive pop — but a left-edge swipe still pops a live puzzle back to
/// Home, which reads as the app misbehaving. On a board screen the Back
/// button is the only way out.
///
/// **Restoring on disappear is the load-bearing half.** The recogniser belongs
/// to the `UINavigationController`, not to this screen, so leaving it disabled
/// would kill swipe-back everywhere else for the rest of the session.
struct SwipeBackDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        /// What the gesture was set to before this screen touched it, so the
        /// restore puts back the real previous value rather than assuming true.
        private var wasEnabled: Bool?

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
            wasEnabled = gesture.isEnabled
            gesture.isEnabled = false
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if let wasEnabled {
                navigationController?.interactivePopGestureRecognizer?.isEnabled = wasEnabled
            }
            wasEnabled = nil
        }
    }
}
#endif

extension View {
    /// Turns off the interactive pop gesture while this screen is showing.
    /// Use it on any screen holding live puzzle state.
    @ViewBuilder
    func swipeBackDisabled() -> some View {
        #if os(iOS)
        background(SwipeBackDisabler().frame(width: 0, height: 0).accessibilityHidden(true))
        #else
        self
        #endif
    }
}
