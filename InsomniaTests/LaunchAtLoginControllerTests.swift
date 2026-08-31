import XCTest
@testable import Insomnia

final class LaunchAtLoginControllerTests: XCTestCase {
    func testDefaultNotRegisteredStatusIsOff() {
        let sut = LaunchAtLoginController(service: FakeLoginItemService(status: .notRegistered))
        XCTAssertFalse(sut.isEnabled)
    }

    func testEnabledAndDisabledStatusesAreReflected() {
        XCTAssertTrue(LaunchAtLoginController(service: FakeLoginItemService(status: .enabled)).isEnabled)
        XCTAssertFalse(LaunchAtLoginController(service: FakeLoginItemService(status: .notRegistered)).isEnabled)
    }

    func testRegisterAndUnregisterErrorsAreMapped() {
        let registerFailure = LaunchAtLoginController(
            service: FakeLoginItemService(status: .notRegistered, registerError: LoginTestError.failed)
        )
        let unregisterFailure = LaunchAtLoginController(
            service: FakeLoginItemService(status: .enabled, unregisterError: LoginTestError.failed)
        )

        XCTAssertEqual(registerFailure.setEnabled(true), .failure(.registrationFailed))
        XCTAssertEqual(unregisterFailure.setEnabled(false), .failure(.removalFailed))
    }
}

private enum LoginTestError: Error {
    case failed
}

private final class FakeLoginItemService: LoginItemServicing {
    var status: LoginItemStatus
    let registerError: Error?
    let unregisterError: Error?

    init(status: LoginItemStatus, registerError: Error? = nil, unregisterError: Error? = nil) {
        self.status = status
        self.registerError = registerError
        self.unregisterError = unregisterError
    }

    func register() throws {
        if let registerError { throw registerError }
        status = .enabled
    }

    func unregister() throws {
        if let unregisterError { throw unregisterError }
        status = .notRegistered
    }
}
