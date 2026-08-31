import Foundation
import InsomniaShared

final class HelperService: NSObject, InsomniaHelperXPC {
    private let controller: HelperControlling

    init(controller: HelperControlling) {
        self.controller = controller
    }

    func getStatus(reply: @escaping (Int, String, Int, String?) -> Void) {
        let result = controller.status()
        reply(result.state.rawValue, AppConstants.helperVersion, result.error.rawValue, result.message)
    }

    func setEnabled(_ enabled: Bool, reply: @escaping (Int, Int, String?) -> Void) {
        let result = controller.setEnabled(enabled)
        reply(result.state.rawValue, result.error.rawValue, result.message)
    }
}

final class ConnectionInvalidationRecovery: @unchecked Sendable {
    private let controller: HelperControlling
    private let lock = NSLock()
    private var invalidated = false

    init(controller: HelperControlling) {
        self.controller = controller
    }

    func invalidate() {
        lock.lock()
        guard !invalidated else {
            lock.unlock()
            return
        }
        invalidated = true
        lock.unlock()
        controller.connectionInvalidated()
    }
}
