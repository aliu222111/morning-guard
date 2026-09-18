import XCTest

/// Parks the app on each screen worth photographing, holding long enough for a
/// `simctl io screenshot` running alongside to catch it. Kept next to
/// DemoWalkthrough so the marketing assets can both be regenerated.
final class ScreenshotTour: XCTestCase {

    private let hold: TimeInterval = 6

    override func setUpWithError() throws { continueAfterFailure = true }

    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String, wait: TimeInterval = 4) -> Bool {
        let b = app.buttons[label]
        guard b.waitForExistence(timeout: wait), b.isHittable else { return false }
        b.tap(); return true
    }

    @MainActor
    func testTour() throws {
        let app = XCUIApplication()
        app.launch()
        Thread.sleep(forTimeInterval: 3)

        // Through onboarding, clearing the system prompts.
        for _ in 0..<2 { app.swipeLeft(); Thread.sleep(forTimeInterval: 1.5) }
        tap(app, "Not now, explore first", wait: 3)
        Thread.sleep(forTimeInterval: 1.5)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Allow While Using App", "OK"] {
            if springboard.buttons[label].waitForExistence(timeout: 2) {
                springboard.buttons[label].tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        Thread.sleep(forTimeInterval: 2)

        // 1. Home, tasks untouched.
        Thread.sleep(forTimeInterval: hold)

        // 2. Home with water done.
        tap(app, "I drank water", wait: 3)
        Thread.sleep(forTimeInterval: hold)

        // 3. Home scrolled to the light meter.
        app.swipeUp()
        Thread.sleep(forTimeInterval: hold)

        // 4. Guard tab.
        app.tabBars.buttons.element(boundBy: 1).tap()
        Thread.sleep(forTimeInterval: hold)

        // 5. Guard tab scrolled to auto-activate.
        app.swipeUp()
        Thread.sleep(forTimeInterval: hold)

        // 6. Settings.
        app.tabBars.buttons.element(boundBy: 2).tap()
        Thread.sleep(forTimeInterval: hold)
    }
}
