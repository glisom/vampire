import XCTest
@testable import InsomniaShared

final class SharedContractTests: XCTestCase {
    func testHelperStateRawValuesAreStable() {
        XCTAssertEqual(HelperState.off.rawValue, 0)
        XCTAssertEqual(HelperState.on.rawValue, 1)
        XCTAssertEqual(HelperState.error.rawValue, 2)
    }

    func testUnknownStateFallsBackToError() {
        XCTAssertEqual(HelperState(xpcValue: 99), .error)
    }
}
