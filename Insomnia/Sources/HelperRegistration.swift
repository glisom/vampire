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
        case .notRegistered, .notFound:
            self.init(state: .setupRequired, needsSystemSettings: false, canConnect: false)
        case .requiresApproval:
            self.init(state: .setupRequired, needsSystemSettings: true, canConnect: false)
        case .enabled:
            self.init(state: .off, needsSystemSettings: false, canConnect: true)
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
    private let serviceStatus: () -> HelperServiceStatus
    private let registerService: () throws -> Void
    private let unregisterService: () throws -> Void

    init(service: SMAppService = .daemon(plistName: AppConstants.helperPlistName)) {
        serviceStatus = { service.status.helperServiceStatus }
        registerService = { try service.register() }
        unregisterService = { try service.unregister() }
    }

    init(
        serviceStatus: @escaping () -> HelperServiceStatus,
        registerService: @escaping () throws -> Void,
        unregisterService: @escaping () throws -> Void
    ) {
        self.serviceStatus = serviceStatus
        self.registerService = registerService
        self.unregisterService = unregisterService
    }

    func assessment() -> HelperRegistrationAssessment {
        HelperRegistrationAssessment(status: serviceStatus())
    }

    func register() -> Result<HelperRegistrationAssessment, HelperRegistrationFailure> {
        do {
            try registerService()
            return .success(assessment())
        } catch {
            let currentAssessment = assessment()
            if currentAssessment.needsSystemSettings || currentAssessment.canConnect {
                return .success(currentAssessment)
            }
            return .failure(.registrationFailed("The privileged helper could not be registered."))
        }
    }

    func unregister() -> Result<Void, HelperRegistrationFailure> {
        do {
            try unregisterService()
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
