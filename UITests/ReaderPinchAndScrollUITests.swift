import XCTest

final class ReaderPinchAndScrollUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPinchUpdatesScaleLabel() {
        let app = XCUIApplication()
        app.launch()

        let pageView = app.otherElements["reader.pageView"]
        XCTAssertTrue(pageView.waitForExistence(timeout: 20))

        let scaleLabel = app.staticTexts["reader.scale"]
        XCTAssertTrue(scaleLabel.waitForExistence(timeout: 10))

        let before = parseScale(scaleLabel.label)

        // Pinch out a bit (zoom in). Keep velocity moderate.
        pageView.pinch(withScale: 1.25, velocity: 0.6)

        let after = parseScale(scaleLabel.label)
        XCTAssertGreaterThan(after, before)

        // Attach screenshots for PR.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "after-pinch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLeavingPageResetsScrollToTop() {
        let app = XCUIApplication()
        app.launch()

        let pageView = app.otherElements["reader.pageView"]
        XCTAssertTrue(pageView.waitForExistence(timeout: 20))

        let chapterTitle = app.staticTexts["reader.chapterTitle"]
        XCTAssertTrue(chapterTitle.waitForExistence(timeout: 10))

        // Scroll down; the title should become not hittable once it scrolls off-screen.
        let scroll = app.scrollViews["reader.pageScroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 10))

        for _ in 0..<6 {
            scroll.swipeUp()
        }

        // Now turn page forward then back.
        pageView.swipeLeft()
        pageView.swipeRight()

        // After returning, the title should be back at the top and hittable.
        XCTAssertTrue(chapterTitle.waitForExistence(timeout: 10))
        XCTAssertTrue(chapterTitle.isHittable)

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "after-scroll-reset"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func parseScale(_ label: String) -> Double {
        // label format: "scale=1.000"
        guard let raw = label.split(separator: "=").last, let value = Double(raw) else {
            XCTFail("Unexpected scale label: \(label)")
            return 0
        }
        return value
    }
}
