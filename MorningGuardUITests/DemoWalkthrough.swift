import XCTest

/// Drives the app through the flow used in the website recording, paced slowly
/// enough to be watchable.
///
/// It deliberately does not tap "Start now": FamilyControls has no simulator
/// implementation, so arming the guard there only raises a Screen Time error.
/// The armed state has to be filmed on a real device.
final class DemoWalkthrough: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    private func beat(_ seconds: TimeInterval = 1.5) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @discardableResult
    private func tap(_ app: XCUIApplication, _ label: String, wait: TimeInterval = 4) -> Bool {
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: wait), button.isHittable else { return false }
        button.tap()
        return true
    }

    @MainActor
    func testWalkthrough() throws {
        let app = XCUIApplication()

        // The notification prompt is a system alert, so it needs a monitor.
        addUIInterruptionMonitor(withDescription: "system dialog") { alert in
            for label in ["Allow", "OK", "Continue"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }

        app.launch()
        beat(2.5)

        // Onboarding: page through by swiping, which survives the TabView's
        // paging animation better than hunting the button down twice.
        for _ in 0..<2 {
            app.swipeLeft()
            beat(2.0)
        }
        tap(app, "Not now, explore first", wait: 3)
        beat(1.5)

        // Clear the notification prompt if it showed up.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "Don't Allow"] where springboard.buttons[label].waitForExistence(timeout: 2) {
            springboard.buttons[label].tap()
            break
        }
        beat(2.8)

        // Home: the block card leads, the two tasks sit under it.
        beat(2.5)
        tap(app, "I drank water", wait: 3)
        beat(2.5)

        // Scroll down to the light meter.
        app.swipeUp()
        beat(3.0)
        app.swipeUp()
        beat(2.5)

        // The Guard tab: duration, app picker, auto-activate.
        app.tabBars.buttons.element(boundBy: 1).tap()
        beat(3.5)
        app.swipeUp()
        beat(3.0)

        // Back where we started.
        app.tabBars.buttons.element(boundBy: 0).tap()
        beat(3.0)
    }
}
