import XCTest
@testable import Insomnia

final class MenuPresentationTests: XCTestCase {
    func testSetupRequiredPresentation() {
        let presentation = MenuPresentation(state: .setupRequired)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Setup Required")
        XCTAssertEqual(presentation.primaryActionTitle, "Set Up Vampire…")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: false))
        XCTAssertTrue(presentation.primaryEnabled)
        XCTAssertFalse(presentation.primaryChecked)
    }

    func testUnsupportedPresentation() {
        let presentation = MenuPresentation(state: .unsupported)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Unsupported Mac")
        XCTAssertEqual(presentation.primaryActionTitle, "Vampire Requires a MacBook")
        XCTAssertEqual(presentation.icon, .systemSymbol("exclamationmark.triangle"))
        XCTAssertFalse(presentation.primaryEnabled)
        XCTAssertFalse(presentation.primaryChecked)
    }

    func testOffPresentation() {
        let presentation = MenuPresentation(state: .off)
        XCTAssertEqual(presentation.statusTitle, "Vampire: Off")
        XCTAssertEqual(presentation.primaryActionTitle, "Keep Mac Awake with Lid Closed")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: false))
        XCTAssertTrue(presentation.primaryEnabled)
        XCTAssertFalse(presentation.primaryChecked)
    }

    func testOnPresentation() {
        let presentation = MenuPresentation(state: .on)
        XCTAssertEqual(presentation.statusTitle, "Vampire: On")
        XCTAssertEqual(presentation.primaryActionTitle, "Keep Mac Awake with Lid Closed")
        XCTAssertEqual(presentation.icon, .vampire(isAwake: true))
        XCTAssertTrue(presentation.primaryEnabled)
        XCTAssertTrue(presentation.primaryChecked)
    }

    func testErrorPresentation() {
        let presentation = MenuPresentation(state: .error("failed"))
        XCTAssertEqual(presentation.statusTitle, "Vampire: Error")
        XCTAssertEqual(presentation.primaryActionTitle, "Restore Normal Lid Sleep…")
        XCTAssertEqual(presentation.icon, .systemSymbol("exclamationmark.triangle.fill"))
        XCTAssertEqual(presentation.errorDetail, "failed")
        XCTAssertTrue(presentation.primaryEnabled)
        XCTAssertFalse(presentation.primaryChecked)
    }

    func testStandardCommandTitles() {
        let presentation = MenuPresentation(state: .off)
        XCTAssertEqual(presentation.setupActionTitle, "Setup & Status…")
        XCTAssertEqual(presentation.quitActionTitle, "Quit Vampire")
    }
}
