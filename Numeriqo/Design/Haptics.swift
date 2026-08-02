//
//  Haptics.swift
//  Numeriqo
//
//  Haptic vocabulary, one generator per feel, kept warm.
//
//  Feedback scales with rarity: a note tick is barely there, a placement is
//  light, a completed line is medium, and the win is the only .success in the
//  app. If the rarest event fired the same pattern as a routine one, the app
//  would have no climax. See docs/DESIGN.md §6.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Unlike `Theme` and `Motion` this must **stay** `@MainActor`:
/// `UIFeedbackGenerator` is `NS_SWIFT_UI_ACTOR`, and `enabled` is mutable global
/// state that would be a hard error under `nonisolated`. Do not "fix" this for
/// consistency with the other design tokens.
@MainActor
enum Haptics {
    static var enabled = true

    #if canImport(UIKit)
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notify = UINotificationFeedbackGenerator()

    /// A digit placed.
    static func place() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.7)
    }

    /// A pencil note toggled — deliberately fainter than a placement.
    static func note() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.4)
    }

    /// Selection moved.
    static func select() {
        guard enabled else { return }
        soft.impactOccurred(intensity: 0.5)
    }

    /// A digit that isn't the one that goes here. Muted, not punitive.
    static func wrong() {
        guard enabled else { return }
        rigid.impactOccurred(intensity: 0.7)
    }

    /// A cage's arithmetic satisfied.
    static func cageSatisfied() {
        guard enabled else { return }
        light.impactOccurred(intensity: 0.6)
    }

    /// A row or column completed.
    static func lineComplete() {
        guard enabled else { return }
        medium.impactOccurred(intensity: 0.8)
    }

    /// A hint revealed.
    static func hint() {
        guard enabled else { return }
        soft.impactOccurred(intensity: 0.6)
    }

    /// The puzzle solved. The rarest event, and the only notification feedback.
    static func win() {
        guard enabled else { return }
        notify.notificationOccurred(.success)
    }
    #else
    static func place() {}
    static func note() {}
    static func select() {}
    static func wrong() {}
    static func cageSatisfied() {}
    static func lineComplete() {}
    static func hint() {}
    static func win() {}
    #endif
}
