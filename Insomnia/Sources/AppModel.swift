import Foundation

@MainActor
final class AppModel {
    private let hardware: HardwareSupporting
    private let registration: HelperRegistering
    private let helperClient: HelperClientProtocol
    private let presenter: AppPresenting
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
        terminate: @escaping @MainActor @Sendable () -> Void
    ) {
        self.hardware = hardware
        self.registration = registration
        self.helperClient = helperClient
        self.presenter = presenter
        self.terminate = terminate
    }

    func start() {
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
        launchAtLoginEnabled = enabled
        onStateChange?(state)
    }

    func showSetupStatus() {
        presenter.presentSetupStatus(registration.assessment())
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
                    fallback: enabled ? "Insomnia could not be enabled." : "Normal lid-close sleep could not be restored."
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
