import Dispatch
import Foundation
import InsomniaShared

struct HelperResult {
    let state: HelperState
    let error: HelperErrorCode
    let message: String?
}

protocol HelperControlling: AnyObject {
    func status() -> HelperResult
    func setEnabled(_ enabled: Bool) -> HelperResult
    func connectionInvalidated()
}

final class HelperController: HelperControlling, @unchecked Sendable {
    private let powerSettings: PowerSettingsManaging
    private let markerStore: RecoveryMarkerStoring
    private let queue = DispatchQueue(label: "co.groundwork-ai.insomnia.helper.controller")
    private var result = HelperResult(state: .off, error: .none, message: nil)

    init(powerSettings: PowerSettingsManaging, markerStore: RecoveryMarkerStoring) {
        self.powerSettings = powerSettings
        self.markerStore = markerStore
    }

    func status() -> HelperResult {
        queue.sync { result }
    }

    func normalizeAtStartup() -> HelperResult {
        queue.sync { disableLocked() }
    }

    func setEnabled(_ enabled: Bool) -> HelperResult {
        queue.sync {
            if enabled {
                return enableLocked()
            }
            return disableLocked()
        }
    }

    func connectionInvalidated() {
        queue.sync {
            guard markerStore.exists else { return }
            _ = disableLocked()
        }
    }

    private func enableLocked() -> HelperResult {
        if result.state == .error, markerStore.exists {
            return update(state: .error, error: .recoveryFailed, message: "Normal sleep must be restored before waking Vampire.")
        }

        do {
            try markerStore.create()
        } catch {
            return update(state: .error, error: .markerFailed, message: "The recovery marker could not be created.")
        }

        do {
            try powerSettings.setSleepDisabled(true)
            return update(state: .on, error: .none, message: nil)
        } catch {
            let original = helperError(for: error)
            do {
                try powerSettings.setSleepDisabled(false)
                try markerStore.remove()
                return update(state: .error, error: original.code, message: original.message)
            } catch {
                return update(state: .error, error: .recoveryFailed, message: "Normal lid-close sleep could not be restored.")
            }
        }
    }

    private func disableLocked() -> HelperResult {
        do {
            try powerSettings.setSleepDisabled(false)
        } catch {
            return update(state: .error, error: .recoveryFailed, message: "Normal lid-close sleep could not be restored.")
        }

        if markerStore.exists {
            do {
                try markerStore.remove()
            } catch {
                return update(state: .error, error: .markerFailed, message: "The recovery marker could not be removed.")
            }
        }
        return update(state: .off, error: .none, message: nil)
    }

    private func helperError(for error: Error) -> (code: HelperErrorCode, message: String) {
        switch error {
        case PMSetError.unsupportedHardware:
            return (.unsupportedHardware, "Vampire requires a MacBook with a built-in lid.")
        case let PMSetError.commandFailed(exitCode, _):
            return (.commandFailed, "pmset exited with status \(exitCode).")
        case PMSetError.verificationFailed:
            return (.verificationFailed, "The lid-close setting could not be verified.")
        default:
            return (.commandFailed, "The lid-close setting could not be changed.")
        }
    }

    private func update(state: HelperState, error: HelperErrorCode, message: String?) -> HelperResult {
        result = HelperResult(state: state, error: error, message: message)
        return result
    }
}
