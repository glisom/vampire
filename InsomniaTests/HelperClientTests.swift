import Foundation
import XCTest
@testable import Insomnia
@testable import InsomniaShared

@MainActor
final class HelperClientTests: XCTestCase {
    func testStatusRawValuesMapToAppStateOnMainActor() async {
        let transport = FakeHelperTransport(status: (.on, .none, nil))
        let sut = HelperClient(transport: transport)

        let state = await status(from: sut)

        XCTAssertEqual(state, .on)
        XCTAssertTrue(transport.callbackUsedBackgroundQueue)
    }

    func testConnectionErrorsMapToError() async {
        let sut = HelperClient(transport: FakeHelperTransport(error: TestTransportError.failed))

        let state = await status(from: sut)

        XCTAssertEqual(state, .error("The privileged helper is unavailable."))
    }

    func testUnknownHelperStateMapsToError() async {
        let transport = FakeHelperTransport(rawState: 99, errorCode: .none, message: nil)
        let sut = HelperClient(transport: transport)

        let state = await status(from: sut)

        XCTAssertEqual(state, .error("The helper reported an unknown state."))
    }

    func testSetEnabledReplyMapsToAcknowledgedState() async {
        let transport = FakeHelperTransport(status: (.off, .none, nil))
        let sut = HelperClient(transport: transport)

        let state = await withCheckedContinuation { continuation in
            sut.setEnabled(false) { state in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(returning: state)
            }
        }

        XCTAssertEqual(state, .off)
        XCTAssertEqual(transport.setEnabledValues, [false])
    }

    func testInvalidatedPrivilegedConnectionIsReplacedBeforeNextRequest() async {
        let first = FakePrivilegedConnection(state: .on)
        let second = FakePrivilegedConnection(state: .off)
        let third = FakePrivilegedConnection(state: .on)
        let factory = FakePrivilegedConnectionFactory(connections: [first, second, third])
        let sut = PrivilegedHelperXPCTransport(makeConnection: factory.makeConnection)

        let firstState = await status(from: sut)
        XCTAssertEqual(firstState, .on)

        first.simulateInvalidation()

        let secondState = await status(from: sut)
        XCTAssertEqual(secondState, .off)

        second.simulateInterruption()

        let thirdState = await status(from: sut)
        XCTAssertEqual(thirdState, .on)
        XCTAssertEqual(factory.connectionCount, 3)
        XCTAssertEqual(first.invalidationHandlerInstallCount, 1)
        XCTAssertEqual(first.interruptionHandlerInstallCount, 1)
    }

    private func status(from client: HelperClient) async -> AppState {
        await withCheckedContinuation { continuation in
            client.getStatus { state in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(returning: state)
            }
        }
    }

    private func status(from transport: HelperXPCTransporting) async -> AppState {
        await withCheckedContinuation { continuation in
            transport.getStatus { state, _, _, _ in
                continuation.resume(returning: HelperState(xpcValue: state) == .on ? .on : .off)
            } error: { _ in
                continuation.resume(returning: .error("transport failed"))
            }
        }
    }
}

private enum TestTransportError: Error {
    case failed
}

private final class FakePrivilegedConnectionFactory: @unchecked Sendable {
    private let connections: [FakePrivilegedConnection]
    private let lock = NSLock()
    private var nextIndex = 0

    init(connections: [FakePrivilegedConnection]) {
        self.connections = connections
    }

    var connectionCount: Int {
        lock.withLock { nextIndex }
    }

    func makeConnection() -> HelperXPCConnecting {
        lock.withLock {
            defer { nextIndex += 1 }
            return connections[nextIndex]
        }
    }
}

private final class FakePrivilegedConnection: HelperXPCConnecting, @unchecked Sendable {
    private let proxy: FakePrivilegedHelperProxy
    private(set) var invalidationHandlerInstallCount = 0
    private(set) var interruptionHandlerInstallCount = 0
    private var invalidationHandler: (@Sendable () -> Void)?
    private var interruptionHandler: (@Sendable () -> Void)?

    init(state: HelperState) {
        proxy = FakePrivilegedHelperProxy(state: state)
    }

    func installHandlers(
        interruption: @escaping @Sendable () -> Void,
        invalidation: @escaping @Sendable () -> Void
    ) {
        interruptionHandlerInstallCount += 1
        invalidationHandlerInstallCount += 1
        interruptionHandler = interruption
        invalidationHandler = invalidation
    }

    func activate() {}
    func invalidate() {}

    func remoteObjectProxyWithErrorHandler(_ handler: @escaping @Sendable (Error) -> Void) -> Any {
        proxy
    }

    func simulateInvalidation() {
        invalidationHandler?()
    }

    func simulateInterruption() {
        interruptionHandler?()
    }
}

private final class FakePrivilegedHelperProxy: NSObject, InsomniaHelperXPC {
    private let state: HelperState

    init(state: HelperState) {
        self.state = state
    }

    func getStatus(reply: @escaping (Int, String, Int, String?) -> Void) {
        reply(state.rawValue, AppConstants.helperVersion, HelperErrorCode.none.rawValue, nil)
    }

    func setEnabled(_ enabled: Bool, reply: @escaping (Int, Int, String?) -> Void) {
        reply(state.rawValue, HelperErrorCode.none.rawValue, nil)
    }
}

private final class FakeHelperTransport: HelperXPCTransporting, @unchecked Sendable {
    private let rawState: Int
    private let errorCode: Int
    private let message: String?
    private let transportError: Error?
    private let lock = NSLock()
    private(set) var callbackUsedBackgroundQueue = false
    private(set) var setEnabledValues: [Bool] = []

    convenience init(status: (HelperState, HelperErrorCode, String?)) {
        self.init(rawState: status.0.rawValue, errorCode: status.1, message: status.2)
    }

    init(rawState: Int = HelperState.off.rawValue, errorCode: HelperErrorCode = .none, message: String? = nil) {
        self.rawState = rawState
        self.errorCode = errorCode.rawValue
        self.message = message
        transportError = nil
    }

    init(error: Error) {
        rawState = HelperState.error.rawValue
        errorCode = HelperErrorCode.commandFailed.rawValue
        message = nil
        transportError = error
    }

    func getStatus(
        reply: @escaping @Sendable (Int, String, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    ) {
        DispatchQueue.global().async { [self] in
            lock.lock()
            callbackUsedBackgroundQueue = !Thread.isMainThread
            lock.unlock()
            if let transportError {
                error(transportError)
            } else {
                reply(rawState, AppConstants.helperVersion, errorCode, message)
            }
        }
    }

    func setEnabled(
        _ enabled: Bool,
        reply: @escaping @Sendable (Int, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    ) {
        lock.lock()
        setEnabledValues.append(enabled)
        lock.unlock()
        DispatchQueue.global().async { [self] in
            if let transportError {
                error(transportError)
            } else {
                reply(rawState, errorCode, message)
            }
        }
    }
}
