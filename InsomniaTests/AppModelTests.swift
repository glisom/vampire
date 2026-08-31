import XCTest
@testable import Insomnia

@MainActor
final class AppModelTests: XCTestCase {
    func testStartOnUnsupportedMacNeverRegistersHelper() {
        let registration = FakeRegistration(status: .enabled)
        let sut = makeModel(hardwareSupported: false, registration: registration)

        sut.start()

        XCTAssertEqual(sut.state, .unsupported)
        XCTAssertEqual(registration.assessmentCallCount, 0)
    }

    func testStartWithUnregisteredHelperShowsSetupRequired() {
        let sut = makeModel(registration: FakeRegistration(status: .notRegistered))

        sut.start()

        XCTAssertEqual(sut.state, .setupRequired)
    }

    func testAppLaunchNeverCallsHelperEnable() {
        let client = FakeHelperClient(status: .off)
        let sut = makeModel(client: client)

        sut.start()

        XCTAssertTrue(client.setEnabledValues.isEmpty)
    }

    func testEnableReportsOnOnlyAfterHelperAcknowledgesOn() {
        let client = FakeHelperClient(status: .off)
        let sut = makeStartedModel(client: client)

        sut.toggleInsomnia()
        XCTAssertEqual(sut.state, .off)

        client.completeSet(with: .on)
        XCTAssertEqual(sut.state, .on)
    }

    func testEnableFailureShowsError() {
        let client = FakeHelperClient(status: .off)
        let sut = makeStartedModel(client: client)

        sut.toggleInsomnia()
        client.completeSet(with: .error("enable failed"))

        XCTAssertEqual(sut.state, .error("enable failed"))
    }

    func testDisableReportsOffOnlyAfterHelperAcknowledgesOff() {
        let client = FakeHelperClient(status: .on)
        let sut = makeStartedModel(client: client)

        sut.toggleInsomnia()
        XCTAssertEqual(sut.state, .on)

        client.completeSet(with: .off)
        XCTAssertEqual(sut.state, .off)
    }

    func testQuitWhileOnDisablesBeforeTerminating() {
        let client = FakeHelperClient(status: .on)
        var terminationCount = 0
        let sut = makeStartedModel(client: client, terminate: { terminationCount += 1 })

        sut.quit()
        XCTAssertEqual(client.setEnabledValues, [false])
        XCTAssertEqual(terminationCount, 0)

        client.completeSet(with: .off)
        XCTAssertEqual(terminationCount, 1)
    }

    func testQuitFailureKeepsAppRunningInError() {
        let client = FakeHelperClient(status: .on)
        var terminationCount = 0
        let sut = makeStartedModel(client: client, terminate: { terminationCount += 1 })

        sut.quit()
        client.completeSet(with: .error("restore failed"))

        XCTAssertEqual(terminationCount, 0)
        XCTAssertEqual(sut.state, .error("restore failed"))
    }
}

@MainActor
private func makeStartedModel(
    client: FakeHelperClient,
    terminate: @escaping @MainActor @Sendable () -> Void = {}
) -> AppModel {
    let sut = makeModel(client: client, terminate: terminate)
    sut.start()
    return sut
}

@MainActor
private func makeModel(
    hardwareSupported: Bool = true,
    registration: FakeRegistration = FakeRegistration(status: .enabled),
    client: FakeHelperClient = FakeHelperClient(status: .off),
    terminate: @escaping @MainActor @Sendable () -> Void = {}
) -> AppModel {
    AppModel(
        hardware: FakeHardware(isSupportedMacBook: hardwareSupported),
        registration: registration,
        helperClient: client,
        presenter: FakePresenter(),
        terminate: terminate
    )
}

private struct FakeHardware: HardwareSupporting {
    let isSupportedMacBook: Bool
}

private final class FakeRegistration: HelperRegistering {
    private let status: HelperServiceStatus
    private(set) var assessmentCallCount = 0

    init(status: HelperServiceStatus) {
        self.status = status
    }

    func assessment() -> HelperRegistrationAssessment {
        assessmentCallCount += 1
        return HelperRegistrationAssessment(status: status)
    }

    func register() -> Result<HelperRegistrationAssessment, HelperRegistrationFailure> {
        .success(HelperRegistrationAssessment(status: status))
    }

    func unregister() -> Result<Void, HelperRegistrationFailure> {
        .success(())
    }
}

@MainActor
private final class FakeHelperClient: HelperClientProtocol {
    let status: AppState
    private(set) var setEnabledValues: [Bool] = []
    private var setCompletion: (@MainActor @Sendable (AppState) -> Void)?

    init(status: AppState) {
        self.status = status
    }

    func getStatus(completion: @escaping @MainActor @Sendable (AppState) -> Void) {
        completion(status)
    }

    func setEnabled(_ enabled: Bool, completion: @escaping @MainActor @Sendable (AppState) -> Void) {
        setEnabledValues.append(enabled)
        setCompletion = completion
    }

    func completeSet(with state: AppState) {
        let completion = setCompletion
        setCompletion = nil
        completion?(state)
    }
}

@MainActor
private final class FakePresenter: AppPresenting {
    func presentSetupRequired(needsSystemSettings: Bool) {}
    func presentSetupStatus(
        _ assessment: HelperRegistrationAssessment,
        retryRegistration: @escaping @MainActor () -> Void,
        removeHelper: @escaping @MainActor () -> Void
    ) {}
    func presentError(_ message: String) {}
    func presentAbout() {}
}
