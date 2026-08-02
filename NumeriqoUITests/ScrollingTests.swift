//
//  ScrollingTests.swift
//  NumeriqoUITests
//
//  Two screens are reachable from the same tap and both were reported as
//  unscrollable. These tests assert the thing that actually matters on each:
//  that content below the fold can be brought into view, and that the control
//  which moves you forward can be reached at all.
//
//  They run at the largest accessibility Dynamic Type as well as the default,
//  because that is where a layout stops fitting and a missing ScrollView turns
//  from invisible into a dead end.
//

import XCTest

final class ScrollingTests: XCTestCase {

    private static let hugeType = [
        "-UIPreferredContentSizeCategoryName",
        "UICTContentSizeCategoryAccessibilityXXXL",
    ]

    private func launch(hugeType: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"] + (hugeType ? Self.hugeType : [])
        app.launch()
        return app
    }

    private func openLearn(_ app: XCUIApplication) {
        let learn = app.buttons["Learn"].firstMatch
        XCTAssertTrue(learn.waitForExistence(timeout: 10))
        learn.tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
    }

    // MARK: - Learn

    /// The requirement is that the far end of the ladder can be *reached*, not
    /// that the list moves. On a large iPad all 17 rows fit, and asserting
    /// movement there fails on a screen that is working correctly.
    ///
    /// `isHittable` rather than `exists`: an off-screen row still reports as
    /// existing to XCTest, so `exists` would pass on a list that never scrolls.
    private func assertLearnScrolls(hugeType: Bool) {
        let app = launch(hugeType: hugeType)
        openLearn(app)

        let first = app.staticTexts["Free Cells"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))

        // Reaching the bottom is the whole requirement, so it is the whole
        // assertion. Do not also check that a top row moved: `List` is lazy and
        // recycles rows out of the hierarchy once they scroll off, so querying
        // one afterwards throws "no matches found" on a list that scrolled
        // perfectly well.
        let last = app.staticTexts["X-Wing"].firstMatch
        for _ in 0..<15 where !last.isHittable { app.swipeUp() }
        XCTAssertTrue(last.isHittable,
                      "the end of the ladder never came into view (hugeType: \(hugeType))")
    }

    func testLearnListScrolls() { assertLearnScrolls(hugeType: false) }
    func testLearnListScrollsAtLargeType() { assertLearnScrolls(hugeType: true) }

    // MARK: - The rules tutorial

    /// The tutorial had no ScrollView and was pinned to the top, so at large
    /// Dynamic Type its only forward control sat below the bottom of the screen
    /// and the tutorial could not be finished.
    private func assertTutorialAdvanceIsReachable(hugeType: Bool) {
        let app = launch(hugeType: hugeType)
        openLearn(app)

        app.staticTexts["How Numeriqo works"].firstMatch.tap()

        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(next.isHittable,
                      "the tutorial's Next button is off-screen (hugeType: \(hugeType))")

        // And the rest of the step has to be reachable by scrolling. The pad is
        // a LazyVGrid, so off-screen it does not exist at all — which makes
        // `isHittable` after scrolling the only honest check.
        let digit = app.buttons["Digit 1"]
        for _ in 0..<12 where !digit.exists || !digit.isHittable { app.swipeUp() }
        XCTAssertTrue(digit.exists && digit.isHittable,
                      "the number pad never came into view (hugeType: \(hugeType))")

        // Next must still be there after scrolling: it is pinned, not scrolled.
        XCTAssertTrue(next.isHittable, "Next must stay pinned while the step scrolls")
    }

    func testTutorialAdvanceIsReachable() { assertTutorialAdvanceIsReachable(hugeType: false) }
    func testTutorialAdvanceIsReachableAtLargeType() { assertTutorialAdvanceIsReachable(hugeType: true) }
}
