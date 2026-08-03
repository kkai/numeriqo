//
//  DesignShotTests.swift
//  NumeriqoUITests
//
//  Not assertions. A design pass has to be looked at, and this walks the app
//  taking one screenshot per surface so the whole set can be reviewed at once
//  instead of by driving the simulator by hand.
//
//  Skipped in both schemes. Run it explicitly:
//
//      xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo \
//        -destination '...' -only-testing:NumeriqoUITests/DesignShotTests
//

import XCTest

final class DesignShotTests: XCTestCase {

    private var app: XCUIApplication!

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? data.write(to: dir.appendingPathComponent("shot-\(name).png"))
    }

    private func launch(hugeType: Bool = false, solved: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-uiTestResetState"]
            + (hugeType ? ["-UIPreferredContentSizeCategoryName",
                           "UICTContentSizeCategoryAccessibilityXXXL"] : [])
            + (solved ? ["-uiTestSolveBoard"] : [])
        app.launch()
    }

    /// The screen that prompted this pass: the win banner used to float over the
    /// completed grid and hide its bottom row.
    func testFinishScreen() {
        launch(solved: true)
        XCTAssertTrue(app.buttons["Skip, I know Calcudoku"].waitForExistence(timeout: 15))
        playOnePuzzle()

        // One cell left, so the win comes from a real placement.
        let last = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row 4, column 4"))
            .firstMatch
        XCTAssertTrue(last.waitForExistence(timeout: 10))
        last.tap()
        for digit in 1...4 where !app.buttons["New puzzle"].exists {
            app.buttons["Digit \(digit)"].tap()
        }
        XCTAssertTrue(app.buttons["New puzzle"].waitForExistence(timeout: 10))
        shot("12-finish")
    }

    /// Into a game, and far enough to leave a save and a best time behind, so
    /// the returning home screen and the stats table have something to show.
    private func playOnePuzzle() {
        app.buttons["Skip, I know Calcudoku"].tap()
        XCTAssertTrue(app.buttons["Digit 1"].waitForExistence(timeout: 25))
    }

    func testEverySurface() {
        launch()
        XCTAssertTrue(app.buttons["Show me how"].waitForExistence(timeout: 15))
        shot("01-first-run")

        playOnePuzzle()
        shot("02-board")

        app.buttons["Hint"].firstMatch.tap()
        shot("03-hint")
        app.buttons["Dismiss hint"].firstMatch.tap()

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 10))
        shot("04-home")

        app.buttons["Learn"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))
        shot("05-learn")

        app.staticTexts["Free Cells"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Unlock practice drills"].waitForExistence(timeout: 10))
        shot("06-lesson")
        app.buttons["Unlock practice drills"].tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        shot("07-paywall")
        app.buttons["Close"].firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Progress"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        shot("08-progress")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        shot("09-settings")
    }

    func testTutorialAndLargeType() {
        launch()
        XCTAssertTrue(app.buttons["Show me how"].waitForExistence(timeout: 15))
        app.buttons["Show me how"].tap()
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 5))
        app.buttons["Next"].tap()
        app.buttons["Next"].tap()
        shot("10-tutorial")

        launch(hugeType: true)
        XCTAssertTrue(app.buttons["Show me how"].waitForExistence(timeout: 15))
        shot("11-first-run-xxxl")
    }
}
