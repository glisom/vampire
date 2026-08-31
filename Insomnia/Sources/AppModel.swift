import Foundation

@MainActor
final class AppModel {
    private let hardware: HardwareSupporting
    private let registration: HelperRegistering
    private let helperClient: HelperClientProtocol
    private let presenter: AppPresenting
    private let launchAtLogin: LaunchAtLoginControlling
    private let terminate: @MainActor @Sendable () -> Void
    private var operationInFlight = false

    private(set) var state: AppState = .setupRequired {
        didSet { onStateChange?(state) }
    }
    private(set) var launchAtLoginEnabled = false
    var onStateChange: ((AppState) -> Void)?

    init(
        hardware: HardwareSupporting,
        registration: HelperRegistering,
        helperClient: HelperClientProtocol,
        presenter: AppPresenting,
        launchAtLogin: LaunchAtLoginControlling = LaunchAtLoginController(),
        terminate: @escaping @MainActor @Sendable () -> Void
    ) {
        self.hardware = hardware
        self.registration = registration
        self.helperClient = helperClient
        self.presenter = presenter
        self.launchAtLogin = launchAtLogin
        self.terminate = terminate
    }

    func start() {
        launchAtLoginEnabled = launchAtLogin.isEnabled
        guard hardware.isSupportedMacBook else {
            state = .unsupported
            return
        }
        handleRegistrationAssessment(registration.assessment(), registerIfNeeded: true)
    }

    func toggleInsomnia() {
        guard !operationInFlight else { return }
        switch state {
        case .setupRequired:
            performRegistration()
        case .off:
            requestEnabled(true)
        case .on, .error:
            requestEnabled(false)
        case .unsupported:
            break
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        switch launchAtLogin.setEnabled(enabled) {
        case let .success(actualValue):
            launchAtLoginEnabled = actualValue
            onStateChange?(state)
        case .failure:
            let message = enabled
                ? "Launch at Login could not be enabled."
                : "Launch at Login could not be disabled."
            state = .error(message)
            presenter.presentError(message)
        }
    }

    func showSetupStatus() {
        presenter.presentSetupStatus(
            registration.assessment(),
            retryRegistration: { [weak self] in self?.performRegistration() },
            removeHelper: { [weak self] in self?.removeHelper() }
        )
    }

    func showAbout() {
        presenter.presentAbout()
    }

    func quit() {
        guard !operationInFlight else { return }
        switch state {
        case .on, .error:
            operationInFlight = true
            helperClient.setEnabled(false) { [weak self] response in
                guard let self else { return }
                self.operationInFlight = false
                if response == .off {
                    self.state = .off
                    self.terminate()
                } else {
                    self.state = Self.errorState(from: response, fallback: "Normal lid-close sleep could not be restored.")
                    if case let .error(message) = self.state {
                        self.presenter.presentError(message)
                    }
                }
            }
        case .setupRequired, .unsupported, .off:
            terminate()
        }
    }

    func removeHelper() {
        guard !operationInFlight else { return }
        operationInFlight = true
        helperClient.setEnabled(false) { [weak self] response in
            guard let self else { return }
            self.operationInFlight = false
            guard response == .off else {
                self.state = Self.errorState(from: response, fallback: "Normal lid-close sleep could not be restored.")
                if case let .error(message) = self.state { self.presenter.presentError(message) }
                return
            }

            self.state = .off
            switch self.registration.unregister() {
            case .success:
                self.state = .setupRequired
            case let .failure(error):
                self.presenter.presentError(error.message)
            }
        }
    }

    private func handleRegistrationAssessment(
        _ assessment: HelperRegistrationAssessment,
        registerIfNeeded: Bool
    ) {
        state = assessment.state
        if assessment.canConnect {
            refreshHelperStatus()
        } else if assessment.state == .setupRequired {
            presenter.presentSetupRequired(needsSystemSettings: assessment.needsSystemSettings)
            if registerIfNeeded, !assessment.needsSystemSettings {
                performRegistration()
            }
        } else if case let .error(message) = assessment.state {
            presenter.presentError(message)
        }
    }

    private func performRegistration() {
        switch registration.register() {
        case let .success(assessment):
            handleRegistrationAssessment(assessment, registerIfNeeded: false)
        case let .failure(error):
            let message = error.message
            state = .error(message)
            presenter.presentError(message)
        }
    }

    private func refreshHelperStatus() {
        helperClient.getStatus { [weak self] response in
            guard let self else { return }
            self.state = response
            if case let .error(message) = response {
                self.presenter.presentError(message)
            }
        }
    }

    private func requestEnabled(_ enabled: Bool) {
        operationInFlight = true
        helperClient.setEnabled(enabled) { [weak self] response in
            guard let self else { return }
            self.operationInFlight = false
            let expected: AppState = enabled ? .on : .off
            if response == expected {
                self.state = expected
            } else {
                self.state = Self.errorState(
                    from: response,
                    fallback: enabled ? "Vampire could not be awakened." : "Vampire could not be turned off."
                )
                if case let .error(message) = self.state {
                    self.presenter.presentError(message)
                }
            }
        }
    }

    private static func errorState(from response: AppState, fallback: String) -> AppState {
        if case .error = response { return response }
        return .error(fallback)
    }
}

private extension HelperRegistrationFailure {
    var message: String {
        switch self {
        case let .registrationFailed(message), let .removalFailed(message): message
        }
    }
}
