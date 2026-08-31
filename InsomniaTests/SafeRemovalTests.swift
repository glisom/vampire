import XCTest
@testable import Insomnia

@MainActor
final class SafeRemovalTests: XCTestCase {
    func testRemovalDisablesBeforeUnregisteringHelper() {
        let events = RemovalEvents()
        let client = RemovalHelperClient(events: events)
        let registration = RemovalRegistration(events: events, result: .success(()))
        let sut = makeRemovalModel(client: client, registration: registration)

        sut.removeHelper()
        client.complete(with: .off)

        XCTAssertEqual(events.values, [.setEnabled(false), .unregisterHelper])
        XCTAssertEqual(sut.state, .setupRequired)
    }

    func testOffFailureNeverUnregistersHelper() {
        let events = RemovalEvents()
        let client = RemovalHelperClient(events: events)
        let registration = RemovalRegistration(events: events, result: .success(()))
        let sut = makeRemovalModel(client: client, registration: registration)

        sut.removeHelper()
        client.complete(with: .error("restore failed"))

        XCTAssertEqual(events.values, [.setEnabled(false)])
        XCTAssertEqual(registration.unregisterCallCount, 0)
        XCTAssertEqual(sut.state, .error("restore failed"))
    }

    func testUnregisterFailureAfterOffKeepsOffAndShowsError() {
        let events = RemovalEvents()
        let client = RemovalHelperClient(events: events)
        let registration = RemovalRegistration(
            events: events,
            result: .failure(.removalFailed("remove failed"))
        )
        let presenter = RemovalPresenter()
        let sut = makeRemovalModel(client: client, registration: registration, presenter: presenter)

        sut.removeHelper()
        client.complete(with: .off)

        XCTAssertEqual(events.values, [.setEnabled(false), .unregisterHelper])
        XCTAssertEqual(sut.state, .off)
        XCTAssertEqual(presenter.errors, ["remove failed"])
    }
}

private enum RemovalEvent: Equatable {
    case setEnabled(Bool)
    case unregisterHelper
}

private final class RemovalEvents {
    var values: [RemovalEvent] = []
}

@MainActor
private final class RemovalHelperClient: HelperClientProtocol {
    let events: RemovalEvents
    var completion: (@MainActor @Sendable (AppState) -> Void)?

    init(events: RemovalEvents) { self.events = events }
    func getStatus(completion: @escaping @MainActor @Sendable (AppState) -> Void) { completion(.off) }
    func setEnabled(_ enabled: Bool, completion: @escaping @MainActor @Sendable (AppState) -> Void) {
        events.values.append(.setEnabled(enabled))
        self.completion = completion
    }
    func complete(with state: AppState) { completion?(state) }
}

private final class RemovalRegistration: HelperRegistering {
    let events: RemovalEvents
    let result: Result<Void, HelperRegistrationFailure>
    private(set) var unregisterCallCount = 0

    init(events: RemovalEvents, result: Result<Void, HelperRegistrationFailure>) {
        self.events = events
        self.result = result
    }

    func assessment() -> HelperRegistrationAssessment { .init(status: .enabled) }
    func register() -> Result<HelperRegistrationAssessment, HelperRegistrationFailure> { .success(.init(status: .enabled)) }
    func unregister() -> Result<Void, HelperRegistrationFailure> {
        unregisterCallCount += 1
        events.values.append(.unregisterHelper)
        return result
    }
}

@MainActor
private final class RemovalPresenter: AppPresenting {
    var errors: [String] = []
    func presentSetupRequired(needsSystemSettings: Bool) {}
    func presentSetupStatus(
        _ assessment: HelperRegistrationAssessment,
        retryRegistration: @escaping @MainActor () -> Void,
        removeHelper: @escaping @MainActor () -> Void
    ) {}
    func presentError(_ message: String) { errors.append(message) }
    func presentAbout() {}
}

private struct RemovalHardware: HardwareSupporting { let isSupportedMacBook = true }

@MainActor
private func makeRemovalModel(
    client: RemovalHelperClient,
    registration: RemovalRegistration,
    presenter: RemovalPresenter = RemovalPresenter()
) -> AppModel {
    AppModel(
        hardware: RemovalHardware(),
        registration: registration,
        helperClient: client,
        presenter: presenter,
        terminate: {}
    )
}
