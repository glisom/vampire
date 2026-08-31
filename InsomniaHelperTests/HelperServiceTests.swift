import XCTest
@testable import InsomniaShared

final class HelperServiceTests: XCTestCase {
    func testGetStatusMapsControllerResultToStableValues() {
        let controller = FakeHelperController(
            result: HelperResult(state: .error, error: .verificationFailed, message: "verify")
        )
        let sut = HelperService(controller: controller)
        let replied = expectation(description: "status reply")

        sut.getStatus { state, version, error, message in
            XCTAssertEqual(state, HelperState.error.rawValue)
            XCTAssertEqual(version, AppConstants.helperVersion)
            XCTAssertEqual(error, HelperErrorCode.verificationFailed.rawValue)
            XCTAssertEqual(message, "verify")
            replied.fulfill()
        }

        wait(for: [replied], timeout: 1)
        XCTAssertEqual(controller.statusCallCount, 1)
    }

    func testSetEnabledDelegatesExactlyOnceAndMapsReply() {
        let controller = FakeHelperController(
            result: HelperResult(state: .on, error: .none, message: nil)
        )
        let sut = HelperService(controller: controller)
        let replied = expectation(description: "set reply")

        sut.setEnabled(true) { state, error, message in
            XCTAssertEqual(state, HelperState.on.rawValue)
            XCTAssertEqual(error, HelperErrorCode.none.rawValue)
            XCTAssertNil(message)
            replied.fulfill()
        }

        wait(for: [replied], timeout: 1)
        XCTAssertEqual(controller.setEnabledValues, [true])
    }

    func testConnectionInvalidationRecoversExactlyOnce() {
        let controller = FakeHelperController(
            result: HelperResult(state: .off, error: .none, message: nil)
        )
        let sut = ConnectionInvalidationRecovery(controller: controller)

        sut.invalidate()
        sut.invalidate()

        XCTAssertEqual(controller.invalidationCallCount, 1)
    }
}

private final class FakeHelperController: HelperControlling {
    let result: HelperResult
    private(set) var statusCallCount = 0
    private(set) var setEnabledValues: [Bool] = []
    private(set) var invalidationCallCount = 0

    init(result: HelperResult) {
        self.result = result
    }

    func status() -> HelperResult {
        statusCallCount += 1
        return result
    }

    func setEnabled(_ enabled: Bool) -> HelperResult {
        setEnabledValues.append(enabled)
        return result
    }

    func connectionInvalidated() {
        invalidationCallCount += 1
    }
}
