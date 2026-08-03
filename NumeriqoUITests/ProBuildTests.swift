//
//  ProBuildTests.swift
//  NumeriqoUITests
//
//  Numeriqo Pro was bought outright, so 3.0 has to arrive in it already
//  unlocked and with the store gone. `theBuildFlagIsTheWholeProEntitlement`
//  proves the entitlement; this proves the screens agree with it.
//
//  Driven by bundle identifier rather than as the scheme's target application,
//  because the UI test target is hosted by the standard app. That means these
//  do NOT run in the ordinary suite — they need the Pro build installed first:
//
//      xcodebuild build -project Numeriqo.xcodeproj -scheme "Numeriqo Pro" \
//        -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
//      xcrun simctl install <device> "<TARGET_BUILD_DIR>/Numeriqo Pro.app"
//      xcodebuild test -project Numeriqo.xcodeproj -scheme Numeriqo \
//        -destination '...' -only-testing:NumeriqoUITests/ProBuildTests
//
//  They are skipped in Numeriqo.xcscheme, since every assertion here is
//  deliberately false of the free build.
//

import XCTest

final class ProBuildTests: XCTestCase {

    private func launchPro() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: "de.kaikunze.numeriqopro")
        app.launchArguments = ["-uiTestResetState"]
        app.launch()
        XCTAssertTrue(app.buttons["Skip, I know Calcudoku"].waitForExistence(timeout: 15),
                      "Numeriqo Pro is not installed on this device")
        return app
    }

    /// Straight past the tutorial and onto a returning home screen.
    private func reachHome(_ app: XCUIApplication) {
        app.buttons["Skip, I know Calcudoku"].tap()
        XCTAssertTrue(app.buttons["Digit 1"].waitForExistence(timeout: 25))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 10))
    }

    func testEveryGridSizeIsPlayableAndNothingSells() {
        let app = launchPro()
        reachHome(app)

        // Segments carry the bare size, since the card's label says Grid.
        let nine = app.buttons["9"].firstMatch
        XCTAssertTrue(nine.waitForExistence(timeout: 5))
        nine.tap()

        // The free build re-labels the primary to "Unlock 9×9", and shows a
        // caption about which grids are paid.
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5),
                      "Pro should offer 9×9 outright")
        XCTAssertFalse(app.buttons["Unlock 9×9"].exists)
        XCTAssertFalse(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "is free. Bigger grids")
        ).firstMatch.exists, "the free-tier caption should not appear in Pro")
    }

    /// The Pro build shipped calling itself "Numeriqo" on its own home screen,
    /// because the wordmark was a literal and only Settings knew the SKU.
    func testTheWordmarkSaysPro() {
        let app = launchPro()
        reachHome(app)
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Numeriqo Pro")
        ).firstMatch.exists, "the Pro build should call itself Numeriqo Pro")
    }

    func testSettingsConfirmsProAndOffersNoRestore() {
        let app = launchPro()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // The row combines its children into one accessibility element, which
        // is not a staticText, so match any descendant by label. The section
        // header is uppercased by the list style, so it is not "Numeriqo Pro"
        // to a query either.
        let confirmation = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@",
                                  "Everything is included in Numeriqo Pro"))
            .firstMatch
        XCTAssertTrue(confirmation.exists, "Settings should confirm which build this is")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH %@", "Every lesson, every drill")
        ).firstMatch.exists, "the Pro section should say what is included")
        XCTAssertFalse(app.buttons["Restore purchases"].exists,
                       "Pro sells no purchases, so it must not offer to restore any")
        XCTAssertFalse(app.buttons["Unlock everything"].exists)
    }

    func testTheWholeCurriculumIsOpen() {
        let app = launchPro()
        app.buttons["Learn"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Learn"].waitForExistence(timeout: 5))

        // The free build's footer counts what is open; Pro's says all of them.
        XCTAssertFalse(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "come with the full game")
        ).firstMatch.exists, "Pro should never advertise the full game")
    }
}
