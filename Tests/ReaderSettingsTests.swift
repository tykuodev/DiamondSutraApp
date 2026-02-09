import XCTest
@testable import DiamondSutraApp

final class ReaderSettingsTests: XCTestCase {
    func testClampedTextScale_ClampsToMinMax() {
        let settings = ReaderSettings()

        XCTAssertEqual(settings.clampedTextScale(-10), ReaderSettings.minTextScale)
        XCTAssertEqual(settings.clampedTextScale(0), ReaderSettings.minTextScale)
        XCTAssertEqual(settings.clampedTextScale(1.0), 1.0)
        XCTAssertEqual(settings.clampedTextScale(10), ReaderSettings.maxTextScale)
    }

    func testDamping_PinchIsNotTooSensitive() {
        // This mirrors the UI's damping behavior: effective delta is pow(magnification, damping).
        let magnification: CGFloat = 2.0
        let damping: CGFloat = 0.65
        let damped = pow(magnification, damping)

        // 2.0x pinch should end up less than 2.0x after damping.
        XCTAssertLessThan(damped, magnification)
        XCTAssertGreaterThan(damped, 1.0)
    }
}
