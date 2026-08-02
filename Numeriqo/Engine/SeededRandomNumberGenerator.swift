//
//  SeededRandomNumberGenerator.swift
//  Numeriqo
//
//  Deterministic RNG. Dailies derive their seed from the date, so the same seed
//  must produce the same board on every device and OS version — the system RNG
//  guarantees no such thing. See docs/ARCHITECTURE.md §4.
//

import Foundation

/// SplitMix64. Small, fast, and its output is fully specified by the algorithm,
/// so it is reproducible across platforms and Swift versions.
nonisolated struct SeededRandomNumberGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        // Avoid the all-zero state, whose first outputs are poor.
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    /// A seed for a given day, so every player gets the same daily puzzle.
    init(day: Int, size: Int, tier: Int) {
        self.init(seed: UInt64(bitPattern: Int64(day &* 2_654_435_761
            &+ size &* 40_503
            &+ tier &* 97)))
    }

    mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
