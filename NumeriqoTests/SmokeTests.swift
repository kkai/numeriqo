//
//  SmokeTests.swift
//  NumeriqoTests
//

import Testing
@testable import Numeriqo

@Test func testTargetIsWired() {
    let position = Position(row: 0, col: 0)
    #expect(position.row == 0)
}
