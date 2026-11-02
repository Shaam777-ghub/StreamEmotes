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
    func testGuestStreamAndChat() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let query = app.textFields["Поиск каналов"].firstMatch
        XCTAssertTrue(query.waitForExistence(timeout: 45))
        query.tap()
        query.typeText("xqc")
        app.buttons["Найти"].firstMatch.tap()
        let player = app.webViews["TwitchPlayer"]
        XCTAssertTrue(player.waitForExistence(timeout: 30), "Native remote player missing")
        let chat = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Чат подключён")).firstMatch
        XCTAssertTrue(chat.waitForExistence(timeout: 60), "Real guest IRC connection failed")
        let count = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ AND label != %@", "Сообщений: ", "Сообщений: 0")).firstMatch
        let received = count.waitForExistence(timeout: 90)
        let play = player.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "play", "воспроизвести")).firstMatch
        if play.waitForExistence(timeout: 15) { play.tap() }
        else { player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        // Allow the real network player to show video or its actual error state.
        let delay = expectation(description: "Player network response")
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { delay.fulfill() }
        wait(for: [delay], timeout: 20)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Simulator-Real-Stream-Chat"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(received, "No real messages received during observation window")
        app.buttons["Смайлики"].firstMatch.tap()
        let emotes = XCTAttachment(screenshot: app.screenshot())
        emotes.name = "Simulator-Real-Stream-Emotes"
        emotes.lifetime = .keepAlways
        add(emotes)
        app.buttons["‹ Назад"].firstMatch.tap()
        XCTAssertFalse(player.exists, "Player must be removed on leaving channel")
    }

}
