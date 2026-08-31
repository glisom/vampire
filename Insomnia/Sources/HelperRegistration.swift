import InsomniaShared
import ServiceManagement

enum HelperServiceStatus: Equatable, Sendable {
    case notRegistered
    case requiresApproval
    case enabled
    case notFound
}

struct HelperRegistrationAssessment: Equatable, Sendable {
    let state: AppState
    let needsSystemSettings: Bool
    let canConnect: Bool

    init(state: AppState, needsSystemSettings: Bool, canConnect: Bool) {
        self.state = state
        self.needsSystemSettings = needsSystemSettings
        self.canConnect = canConnect
    }

    init(status: HelperServiceStatus) {
        switch status {
        case .notRegistered:
            self.init(state: .setupRequired, needsSystemSettings: false, canConnect: false)
        case .requiresApproval:
            self.init(state: .setupRequired, needsSystemSettings: true, canConnect: false)
        case .enabled:
            self.init(state: .off, needsSystemSettings: false, canConnect: true)
        case .notFound:
            self.init(
                state: .error("The bundled helper could not be found."),
                needsSystemSettings: false,
                canConnect: false
            )
        }
    }
}

enum HelperRegistrationFailure: Error, Equatable, Sendable {
    case registrationFailed(String)
    case removalFailed(String)
}

protocol HelperRegistering: AnyObject {
    func assessment() -> HelperRegistrationAssessment
    func register() -> Result<HelperRegistrationAssessment, HelperRegistrationFailure>
    func unregister() -> Result<Void, HelperRegistrationFailure>
}

final class HelperRegistration: HelperRegistering {
    private let service: SMAppService

    init(service: SMAppService = .daemon(plistName: AppConstants.helperPlistName)) {
        self.service = service
    }

    func assessment() -> HelperRegistrationAssessment {
        HelperRegistrationAssessment(status: service.status.helperServiceStatus)
    }

    func register() -> Result<HelperRegistrationAssessment, HelperRegistrationFailure> {
        do {
            try service.register()
            return .success(assessment())
        } catch {
            return .failure(.registrationFailed("The privileged helper could not be registered."))
        }
    }

    func unregister() -> Result<Void, HelperRegistrationFailure> {
        do {
            try service.unregister()
            return .success(())
        } catch {
            return .failure(.removalFailed("The privileged helper could not be removed."))
        }
    }
}

private extension SMAppService.Status {
    var helperServiceStatus: HelperServiceStatus {
        switch self {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notFound
        }
    }
}
