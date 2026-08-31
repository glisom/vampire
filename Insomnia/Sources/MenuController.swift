import AppKit

struct MenuPresentation: Equatable {
    let statusTitle: String
    let primaryActionTitle: String
    let symbolName: String
    let primaryEnabled: Bool
    let errorDetail: String?

    private init(
        statusTitle: String,
        primaryActionTitle: String,
        symbolName: String,
        primaryEnabled: Bool,
        errorDetail: String?
    ) {
        self.statusTitle = statusTitle
        self.primaryActionTitle = primaryActionTitle
        self.symbolName = symbolName
        self.primaryEnabled = primaryEnabled
        self.errorDetail = errorDetail
    }

    init(state: AppState) {
        switch state {
        case .setupRequired:
            self.init(
                statusTitle: "Insomnia: Setup Required",
                primaryActionTitle: "Set Up Insomnia…",
                symbolName: "moon.zzz",
                primaryEnabled: true,
                errorDetail: nil
            )
        case .unsupported:
            self.init(
                statusTitle: "Insomnia: Unsupported Mac",
                primaryActionTitle: "Turn Insomnia On",
                symbolName: "exclamationmark.triangle",
                primaryEnabled: false,
                errorDetail: nil
            )
        case .off:
            self.init(
                statusTitle: "Insomnia: Off",
                primaryActionTitle: "Turn Insomnia On",
                symbolName: "moon.zzz",
                primaryEnabled: true,
                errorDetail: nil
            )
        case .on:
            self.init(
                statusTitle: "Insomnia: On",
                primaryActionTitle: "Restore Lullaby",
                symbolName: "moon.zzz.fill",
                primaryEnabled: true,
                errorDetail: nil
            )
        case let .error(message):
            self.init(
                statusTitle: "Insomnia: Error",
                primaryActionTitle: "Retry Restore Lullaby",
                symbolName: "exclamationmark.triangle.fill",
                primaryEnabled: true,
                errorDetail: message
            )
        }
    }
}

@MainActor
final class MenuController: NSObject {
    private let model: AppModel
    private let statusItem: NSStatusItem

    init(model: AppModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        model.onStateChange = { [weak self] state in
            self?.render(MenuPresentation(state: state))
        }
        render(MenuPresentation(state: model.state))
    }

    private func render(_ presentation: MenuPresentation) {
        statusItem.button?.image = NSImage(
            systemSymbolName: presentation.symbolName,
            accessibilityDescription: presentation.statusTitle
        )

        let menu = NSMenu()
        let status = NSMenuItem(title: presentation.statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        if let detail = presentation.errorDetail {
            status.toolTip = detail
        }
        menu.addItem(status)

        let primary = NSMenuItem(
            title: presentation.primaryActionTitle,
            action: #selector(toggleInsomnia),
            keyEquivalent: ""
        )
        primary.target = self
        primary.isEnabled = presentation.primaryEnabled
        menu.addItem(primary)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = model.launchAtLoginEnabled ? .on : .off
        menu.addItem(login)

        let setup = NSMenuItem(title: "Setup Status…", action: #selector(showSetupStatus), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)

        let about = NSMenuItem(title: "About Insomnia", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleInsomnia() { model.toggleInsomnia() }
    @objc private func toggleLaunchAtLogin() { model.setLaunchAtLogin(!model.launchAtLoginEnabled) }
    @objc private func showSetupStatus() { model.showSetupStatus() }
    @objc private func showAbout() { model.showAbout() }
    @objc private func quit() { model.quit() }
}
