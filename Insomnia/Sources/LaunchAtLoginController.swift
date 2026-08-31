import ServiceManagement

enum LoginItemStatus: Equatable {
    case notRegistered
    case enabled
}

protocol LoginItemServicing: AnyObject {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
}

enum LaunchAtLoginError: Error, Equatable {
    case registrationFailed
    case removalFailed
}

protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) -> Result<Bool, LaunchAtLoginError>
}

final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: LoginItemServicing

    init(service: LoginItemServicing = MainAppLoginItemService()) {
        self.service = service
    }

    var isEnabled: Bool {
        service.status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> Result<Bool, LaunchAtLoginError> {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return .success(isEnabled)
        } catch {
            return .failure(enabled ? .registrationFailed : .removalFailed)
        }
    }
}

private final class MainAppLoginItemService: LoginItemServicing {
    private let service = SMAppService.mainApp

    var status: LoginItemStatus {
        service.status == .enabled ? .enabled : .notRegistered
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
