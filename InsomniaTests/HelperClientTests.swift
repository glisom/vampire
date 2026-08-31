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

    private func status(from client: HelperClient) async -> AppState {
        await withCheckedContinuation { continuation in
            client.getStatus { state in
                XCTAssertTrue(Thread.isMainThread)
                continuation.resume(returning: state)
            }
        }
    }
}

private enum TestTransportError: Error {
    case failed
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
