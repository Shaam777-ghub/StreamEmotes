import XCTest

final class LaunchTests: XCTestCase {
    func testLaunchAndSettings() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 45), "WebKit interface did not load")
        let heading = app.staticTexts["Прямо сейчас"].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 30), "Home screen did not appear")
        XCTAssertTrue(app.staticTexts["Весь Twitch. Более живой чат."].firstMatch.waitForExistence(timeout: 30), "Initial session check did not complete")
        let startup = XCTAttachment(screenshot: app.screenshot())
        startup.name = "Simulator-Home"
        startup.lifetime = .keepAlways
        add(startup)
        let settings = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Настройки")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        XCTAssertTrue(app.staticTexts["Твой StreamEmotes"].firstMatch.waitForExistence(timeout: 10))
        let settingsShot = XCTAttachment(screenshot: app.screenshot())
        settingsShot.name = "Simulator-Settings"
        settingsShot.lifetime = .keepAlways
        add(settingsShot)
        app.buttons["Готово"].firstMatch.tap()
        XCTAssertTrue(heading.exists)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
