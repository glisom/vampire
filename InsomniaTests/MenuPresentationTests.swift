import XCTest
@testable import Insomnia

final class MenuPresentationTests: XCTestCase {
    func testSetupRequiredPresentation() {
        let presentation = MenuPresentation(state: .setupRequired)
        XCTAssertEqual(presentation.statusTitle, "Insomnia: Setup Required")
        XCTAssertEqual(presentation.primaryActionTitle, "Set Up Insomnia…")
        XCTAssertEqual(presentation.symbolName, "moon.zzz")
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testUnsupportedPresentation() {
        let presentation = MenuPresentation(state: .unsupported)
        XCTAssertEqual(presentation.statusTitle, "Insomnia: Unsupported Mac")
        XCTAssertEqual(presentation.symbolName, "exclamationmark.triangle")
        XCTAssertFalse(presentation.primaryEnabled)
    }

    func testOffPresentation() {
        let presentation = MenuPresentation(state: .off)
        XCTAssertEqual(presentation.statusTitle, "Insomnia: Off")
        XCTAssertEqual(presentation.primaryActionTitle, "Turn Insomnia On")
        XCTAssertEqual(presentation.symbolName, "moon.zzz")
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testOnPresentation() {
        let presentation = MenuPresentation(state: .on)
        XCTAssertEqual(presentation.statusTitle, "Insomnia: On")
        XCTAssertEqual(presentation.primaryActionTitle, "Restore Lullaby")
        XCTAssertEqual(presentation.symbolName, "moon.zzz.fill")
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testErrorPresentation() {
        let presentation = MenuPresentation(state: .error("failed"))
        XCTAssertEqual(presentation.statusTitle, "Insomnia: Error")
        XCTAssertEqual(presentation.primaryActionTitle, "Retry Restore Lullaby")
        XCTAssertEqual(presentation.symbolName, "exclamationmark.triangle.fill")
        XCTAssertEqual(presentation.errorDetail, "failed")
        XCTAssertTrue(presentation.primaryEnabled)
    }
}
