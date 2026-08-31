import Foundation
import InsomniaShared

@MainActor
protocol HelperClientProtocol: AnyObject {
    func getStatus(completion: @escaping @MainActor @Sendable (AppState) -> Void)
    func setEnabled(_ enabled: Bool, completion: @escaping @MainActor @Sendable (AppState) -> Void)
}

protocol HelperXPCTransporting: AnyObject {
    func getStatus(
        reply: @escaping @Sendable (Int, String, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    )
    func setEnabled(
        _ enabled: Bool,
        reply: @escaping @Sendable (Int, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    )
}

@MainActor
final class HelperClient: HelperClientProtocol {
    private let transport: HelperXPCTransporting

    init(transport: HelperXPCTransporting = PrivilegedHelperXPCTransport()) {
        self.transport = transport
    }

    func getStatus(completion: @escaping @MainActor @Sendable (AppState) -> Void) {
        transport.getStatus { state, version, error, message in
            let mapped = Self.mapStatus(state: state, version: version, error: error, message: message)
            Task { @MainActor in completion(mapped) }
        } error: { _ in
            Task { @MainActor in completion(.error("The privileged helper is unavailable.")) }
        }
    }

    func setEnabled(_ enabled: Bool, completion: @escaping @MainActor @Sendable (AppState) -> Void) {
        transport.setEnabled(enabled) { state, error, message in
            let mapped = Self.mapState(state: state, error: error, message: message)
            Task { @MainActor in completion(mapped) }
        } error: { _ in
            Task { @MainActor in completion(.error("The privileged helper is unavailable.")) }
        }
    }

    nonisolated private static func mapStatus(
        state: Int,
        version: String,
        error: Int,
        message: String?
    ) -> AppState {
        guard version == AppConstants.helperVersion else {
            return .error("The privileged helper version does not match this app.")
        }
        return mapState(state: state, error: error, message: message)
    }

    nonisolated private static func mapState(state: Int, error: Int, message: String?) -> AppState {
        guard HelperState(rawValue: state) != nil else {
            return .error("The helper reported an unknown state.")
        }
        switch HelperState(xpcValue: state) {
        case .off:
            return .off
        case .on:
            return .on
        case .error:
            return .error(message ?? "The privileged helper reported an error (\(error)).")
        }
    }
}

private enum HelperTransportError: Error {
    case unavailable
}

private final class PrivilegedHelperXPCTransport: HelperXPCTransporting, @unchecked Sendable {
    private let connection: NSXPCConnection

    init() {
        connection = NSXPCConnection(machServiceName: AppConstants.helperLabel, options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: InsomniaHelperXPC.self)
        connection.activate()
    }

    deinit {
        connection.invalidate()
    }

    func getStatus(
        reply: @escaping @Sendable (Int, String, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    ) {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler(error) as? InsomniaHelperXPC else {
            error(HelperTransportError.unavailable)
            return
        }
        proxy.getStatus(reply: reply)
    }

    func setEnabled(
        _ enabled: Bool,
        reply: @escaping @Sendable (Int, Int, String?) -> Void,
        error: @escaping @Sendable (Error) -> Void
    ) {
        guard let proxy = connection.remoteObjectProxyWithErrorHandler(error) as? InsomniaHelperXPC else {
            error(HelperTransportError.unavailable)
            return
        }
        proxy.setEnabled(enabled, reply: reply)
    }
}
