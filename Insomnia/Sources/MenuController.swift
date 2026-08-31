import AppKit

struct MenuPresentation: Equatable {
    let statusTitle: String
    let primaryActionTitle: String
    let icon: MenuIcon
    let primaryEnabled: Bool
    let primaryChecked: Bool
    let errorDetail: String?
    let setupActionTitle = "Setup & Status…"
    let quitActionTitle = "Quit Vampire"

    private init(
        statusTitle: String,
        primaryActionTitle: String,
        icon: MenuIcon,
        primaryEnabled: Bool,
        primaryChecked: Bool,
        errorDetail: String?
    ) {
        self.statusTitle = statusTitle
        self.primaryActionTitle = primaryActionTitle
        self.icon = icon
        self.primaryEnabled = primaryEnabled
        self.primaryChecked = primaryChecked
        self.errorDetail = errorDetail
    }

    init(state: AppState) {
        switch state {
        case .setupRequired:
            self.init(
                statusTitle: "Vampire: Setup Required",
                primaryActionTitle: "Set Up Vampire…",
                icon: .vampire(isAwake: false),
                primaryEnabled: true,
                primaryChecked: false,
                errorDetail: nil
            )
        case .unsupported:
            self.init(
                statusTitle: "Vampire: Unsupported Mac",
                primaryActionTitle: "Vampire Requires a MacBook",
                icon: .systemSymbol("exclamationmark.triangle"),
                primaryEnabled: false,
                primaryChecked: false,
                errorDetail: nil
            )
        case .off:
            self.init(
                statusTitle: "Vampire: Off",
                primaryActionTitle: "Keep Mac Awake with Lid Closed",
                icon: .vampire(isAwake: false),
                primaryEnabled: true,
                primaryChecked: false,
                errorDetail: nil
            )
        case .on:
            self.init(
                statusTitle: "Vampire: On",
                primaryActionTitle: "Keep Mac Awake with Lid Closed",
                icon: .vampire(isAwake: true),
                primaryEnabled: true,
                primaryChecked: true,
                errorDetail: nil
            )
        case let .error(message):
            self.init(
                statusTitle: "Vampire: Error",
                primaryActionTitle: "Restore Normal Lid Sleep…",
                icon: .systemSymbol("exclamationmark.triangle.fill"),
                primaryEnabled: true,
                primaryChecked: false,
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
        statusItem.button?.image = StatusIconRenderer.image(for: presentation.icon)
        statusItem.button?.setAccessibilityLabel(presentation.statusTitle)

        let menu = NSMenu()
        let primary = NSMenuItem(
            title: presentation.primaryActionTitle,
            action: #selector(toggleInsomnia),
            keyEquivalent: ""
        )
        primary.target = self
        primary.isEnabled = presentation.primaryEnabled
        primary.state = presentation.primaryChecked ? .on : .off
        primary.toolTip = presentation.errorDetail
        menu.addItem(primary)
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = model.launchAtLoginEnabled ? .on : .off
        menu.addItem(login)

        let setup = NSMenuItem(
            title: presentation.setupActionTitle,
            action: #selector(showSetupStatus),
            keyEquivalent: ""
        )
        setup.target = self
        menu.addItem(setup)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Vampire", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(
            title: presentation.quitActionTitle,
            action: #selector(quit),
            keyEquivalent: "q"
        )
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
