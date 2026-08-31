import AppKit
import ServiceManagement

@MainActor
protocol AppPresenting: AnyObject {
    func presentSetupRequired(needsSystemSettings: Bool)
    func presentSetupStatus(_ assessment: HelperRegistrationAssessment)
    func presentError(_ message: String)
    func presentAbout()
}

@MainActor
final class SetupPresenter: AppPresenting {
    func presentSetupRequired(needsSystemSettings: Bool) {
        let alert = NSAlert()
        alert.messageText = "Set Up Insomnia"
        alert.informativeText = needsSystemSettings
            ? "Approve Insomnia in Login Items so it can change lid-close sleep behavior."
            : "Insomnia needs one-time macOS approval to change lid-close sleep behavior."
        alert.addButton(withTitle: needsSystemSettings ? "Open System Settings" : "Continue")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn, needsSystemSettings {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    func presentSetupStatus(_ assessment: HelperRegistrationAssessment) {
        let alert = NSAlert()
        alert.messageText = "Insomnia Setup Status"
        switch assessment.state {
        case .setupRequired:
            alert.informativeText = assessment.needsSystemSettings
                ? "The helper is waiting for approval in System Settings."
                : "The privileged helper is not registered."
        case .off, .on:
            alert.informativeText = "The privileged helper is enabled."
        case .unsupported:
            alert.informativeText = "Insomnia requires a MacBook with a built-in lid."
        case let .error(message):
            alert.informativeText = message
        }
        alert.runModal()
    }

    func presentError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Insomnia Error"
        alert.informativeText = message
        alert.runModal()
    }

    func presentAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
