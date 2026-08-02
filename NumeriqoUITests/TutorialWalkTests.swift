//
//  TutorialWalkTests.swift
//  NumeriqoUITests
//
//  Walks the first-run tutorial the way a new player would.
//
//  TutorialTests already drives the engine directly, but a scripted tutorial
//  that cannot be finished traps a new player on step one with no way out, and
//  the engine passing says nothing about whether the buttons that drive it are
//  reachable. So this walks the real screens: two reading steps, a refusal that
//  must not advance, every taught placement, the free cells, and out the other
//  side into a game.
//

import XCTest

final class TutorialWalkTests: XCTestCase {

    private func cell(_ app: XCUIApplication, _ row: Int, _ col: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@",
                                  "Row \(row + 1), column \(col + 1)"))
            .firstMatch
    }

    func testWalkTheTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"]
        app.launch()

        let show = app.buttons["Show me how"]
        XCTAssertTrue(show.waitForExistence(timeout: 10), "first run should offer the tutorial")
        show.tap()

        // Two reading steps, then the first thing to do.
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        next.tap()

        XCTAssertTrue(app.staticTexts["Your turn"].waitForExistence(timeout: 5),
                      "step 3 should be interactive")

        // A wrong digit must be refused, and the step must not move on.
        app.buttons["Digit 1"].tap()
        XCTAssertTrue(app.staticTexts["Your turn"].exists, "a refusal must not advance")

        // Now follow the script.
        let required = [2, 3, 1, 3, 1]
        var placed = 0
        for _ in 0..<40 {
            if app.buttons["Start playing"].exists { break }
            if next.exists {
                next.tap()
            } else if placed < required.count {
                app.buttons["Digit \(required[placed])"].tap()
                placed += 1
            } else {
                break
            }
        }
        XCTAssertEqual(placed, required.count, "every taught placement should have landed")

        // solveFreely: the last four cells of the 3x3.
        //   1 2 .        remaining: r0c0=1 r0c1=2 r1c0=2 r2c0=3
        //   . 3 1
        //   . 1 2
        for (row, col, digit) in [(2, 0, 3), (1, 0, 2), (0, 0, 1), (0, 1, 2)] {
            cell(app, row, col).tap()
            app.buttons["Digit \(digit)"].tap()
        }

        let finish = app.buttons["Start playing"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5),
                      "solving the board should reach the celebration")
        finish.tap()
        XCTAssertTrue(app.buttons["Digit 1"].waitForExistence(timeout: 20),
                      "finishing the tutorial should land in a game, not back on a list")
    }

    /// There is one save slot, and starting a new game used to overwrite it
    /// with no warning: a half-finished 9x9 could be destroyed by tapping Play
    /// to see what a 4x4 looked like.
    func testStartingANewGameWarnsAboutTheSavedOne() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"]
        app.launch()

        // Skip the tutorial, play far enough to leave a save, then come back.
        let skip = app.buttons["Skip, I know Calcudoku"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        XCTAssertTrue(app.buttons["Digit 1"].waitForExistence(timeout: 20))
        app.buttons["Digit 1"].tap()
        cell(app, 0, 0).tap()
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 10),
                      "an unfinished game should offer to continue")

        app.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Start a new game?"].waitForExistence(timeout: 5),
                      "starting a new game over a save must warn first")

        app.buttons["Keep playing mine"].tap()
        XCTAssertTrue(app.buttons["Digit 1"].waitForExistence(timeout: 20),
                      "declining should resume the saved game, not discard it")
    }
}
