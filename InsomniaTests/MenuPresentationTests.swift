import XCTest
@testable import Insomnia

final class MenuPresentationTests: XCTestCase {
    func testSetupRequiredPresentation() {
        let presentation = MenuPresentation(state: .setupRequired)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Setup Required")
        XCTAssertEqual(presentation.primaryActionTitle, "Set Up Vampire…")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: false))
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testUnsupportedPresentation() {
        let presentation = MenuPresentation(state: .unsupported)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Unsupported Mac")
        XCTAssertEqual(presentation.icon, .systemSymbol("exclamationmark.triangle"))
        XCTAssertFalse(presentation.primaryEnabled)
    }

    func testOffPresentation() {
        let presentation = MenuPresentation(state: .off)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Off")
        XCTAssertEqual(presentation.primaryActionTitle, "Wake Vampire")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: false))
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testOnPresentation() {
        let presentation = MenuPresentation(state: .on)
        XCTAssertEqual(presentation.statusTitle, "Vampire: On")
        XCTAssertEqual(presentation.primaryActionTitle, "Turn Off Vampire")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: true))
        XCTAssertTrue(presentation.primaryEnabled)
    }

    func testErrorPresentation() {
        let presentation = MenuPresentation(state: .error("failed"))
        XCTAssertEqual(presentation.statusTitle, "Vampire: Error")
        XCTAssertEqual(presentation.primaryActionTitle, "Retry Turning Off Vampire")
        XCTAssertEqual(presentation.icon, .systemSymbol("exclamationmark.triangle.fill"))
        XCTAssertEqual(presentation.errorDetail, "failed")
        XCTAssertTrue(presentation.primaryEnabled)
    }
}
