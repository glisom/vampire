import AppKit
import ServiceManagement

@MainActor
protocol AppPresenting: AnyObject {
    func presentSetupRequired(needsSystemSettings: Bool)
    func presentSetupStatus(
        _ assessment: HelperRegistrationAssessment,
        retryRegistration: @escaping @MainActor () -> Void,
        removeHelper: @escaping @MainActor () -> Void
    )
    func presentError(_ message: String)
    func presentAbout()
}

@MainActor
final class SetupPresenter: AppPresenting {
    func presentSetupRequired(needsSystemSettings: Bool) {
        let alert = NSAlert()
        alert.messageText = "Set Up Vampire"
        alert.informativeText = needsSystemSettings
            ? "Approve Vampire in Login Items so it can change lid-close sleep behavior."
            : "Vampire needs one-time macOS approval to change lid-close sleep behavior."
        alert.addButton(withTitle: needsSystemSettings ? "Open System Settings" : "Continue")
        if alert.runModal() == .alertFirstButtonReturn, needsSystemSettings {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func presentSetupStatus(
        _ assessment: HelperRegistrationAssessment,
        retryRegistration: @escaping @MainActor () -> Void,
        removeHelper: @escaping @MainActor () -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = "Vampire Setup Status"
        var action: (() -> Void)?
        switch assessment.state {
        case .setupRequired:
            alert.informativeText = assessment.needsSystemSettings
                ? "The helper is waiting for approval in System Settings."
                : "The privileged helper is not registered."
            alert.addButton(withTitle: assessment.needsSystemSettings ? "Open System Settings" : "Retry Registration")
            action = assessment.needsSystemSettings
                ? { SMAppService.openSystemSettingsLoginItems() }
                : retryRegistration
        case .off, .on:
            alert.informativeText = "The privileged helper is enabled."
            alert.addButton(withTitle: "Remove Helper")
            action = removeHelper
        case .unsupported:
            alert.informativeText = "Vampire requires a MacBook with a built-in lid."
        case let .error(message):
            alert.informativeText = message
            alert.addButton(withTitle: "Retry Registration")
            action = retryRegistration
        }
        alert.addButton(withTitle: "Done")
        if alert.runModal() == .alertFirstButtonReturn {
            action?()
        }
    }

    func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Vampire Error"
        alert.informativeText = message
        alert.runModal()
    }

    func presentAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
