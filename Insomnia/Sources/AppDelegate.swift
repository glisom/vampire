import AppKit

@main
enum InsomniaApplication {
    @MainActor
    static func main() {
        ApplicationBootstrap(
            application: NSApplication.shared,
            delegate: AppDelegate()
        ).run()
    }
}

@MainActor
final class ApplicationBootstrap {
    private let application: NSApplication
    private let delegate: AppDelegate

    init(application: NSApplication, delegate: AppDelegate) {
        self.application = application
        self.delegate = delegate
        application.delegate = delegate
    }

    func run() {
        withExtendedLifetime(delegate) {
            application.run()
        }
    }
}

enum AppLaunchEnvironment {
    static func shouldStartApplication(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}

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
