import AppKit

enum AppLaunchEnvironment {
    static func shouldStartApplication(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var menuController: MenuController?
    private var allowTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AppLaunchEnvironment.shouldStartApplication(
            environment: ProcessInfo.processInfo.environment
        ) else {
            return
        }
        let presenter = SetupPresenter()
        let model = AppModel(
            hardware: MacBookHardwareSupport(),
            registration: HelperRegistration(),
            helperClient: HelperClient(),
            presenter: presenter,
            launchAtLogin: LaunchAtLoginController(),
            terminate: { [weak self] in
                self?.allowTermination = true
                NSApp.terminate(nil)
            }
        )
        self.model = model
        menuController = MenuController(model: model)
        model.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !allowTermination else { return .terminateNow }
        model?.quit()
        return .terminateCancel
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
