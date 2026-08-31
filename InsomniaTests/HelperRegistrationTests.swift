import XCTest
@testable import Insomnia

final class HelperRegistrationTests: XCTestCase {
    func testNotRegisteredRequiresSetupWithoutSystemSettings() {
        XCTAssertEqual(
            HelperRegistrationAssessment(status: .notRegistered),
            .init(state: .setupRequired, needsSystemSettings: false, canConnect: false)
        )
    }

    func testRequiresApprovalNeedsSystemSettings() {
        XCTAssertEqual(
            HelperRegistrationAssessment(status: .requiresApproval),
            .init(state: .setupRequired, needsSystemSettings: true, canConnect: false)
        )
    }

    func testEnabledAllowsConnection() {
        XCTAssertEqual(
            HelperRegistrationAssessment(status: .enabled),
            .init(state: .off, needsSystemSettings: false, canConnect: true)
        )
    }

    func testNotFoundRequiresInitialSetup() {
        XCTAssertEqual(
            HelperRegistrationAssessment(status: .notFound),
            .init(state: .setupRequired, needsSystemSettings: false, canConnect: false)
        )
    }

    func testRegisterReturnsRequiresApprovalWhenSystemRecordsItemBeforeThrowing() {
        var status = HelperServiceStatus.notFound
        let sut = HelperRegistration(
            serviceStatus: { status },
            registerService: {
                status = .requiresApproval
                throw StubServiceError.operationNotPermitted
            },
            unregisterService: {}
        )

        XCTAssertEqual(
            sut.register(),
            .success(.init(state: .setupRequired, needsSystemSettings: true, canConnect: false))
        )
    }

    func testRegisterReturnsFailureWhenSystemDoesNotRecordItem() {
        let sut = HelperRegistration(
            serviceStatus: { .notFound },
            registerService: { throw StubServiceError.operationNotPermitted },
            unregisterService: {}
        )

        XCTAssertEqual(
            sut.register(),
            .failure(.registrationFailed("The privileged helper could not be registered."))
        )
    }
}

private enum StubServiceError: Error {
    case operationNotPermitted
}
