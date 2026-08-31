import AppKit

enum MenuIcon: Equatable {
    case vampire(isAwake: Bool)
    case systemSymbol(String)
}

struct MenuPresentation: Equatable {
    let statusTitle: String
    let primaryActionTitle: String
    let icon: MenuIcon
    let primaryEnabled: Bool
    let errorDetail: String?

    private init(
        statusTitle: String,
        primaryActionTitle: String,
        icon: MenuIcon,
        primaryEnabled: Bool,
        errorDetail: String?
    ) {
        self.statusTitle = statusTitle
        self.primaryActionTitle = primaryActionTitle
        self.icon = icon
        self.primaryEnabled = primaryEnabled
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
                errorDetail: nil
            )
        case .unsupported:
            self.init(
                statusTitle: "Vampire: Unsupported Mac",
                primaryActionTitle: "Wake Vampire",
                icon: .systemSymbol("exclamationmark.triangle"),
                primaryEnabled: false,
                errorDetail: nil
            )
        case .off:
            self.init(
                statusTitle: "Vampire: Off",
                primaryActionTitle: "Wake Vampire",
                icon: .vampire(isAwake: false),
                primaryEnabled: true,
                errorDetail: nil
            )
        case .on:
            self.init(
                statusTitle: "Vampire: On",
                primaryActionTitle: "Turn Off Vampire",
                icon: .vampire(isAwake: true),
                primaryEnabled: true,
                errorDetail: nil
            )
        case let .error(message):
            self.init(
                statusTitle: "Vampire: Error",
                primaryActionTitle: "Retry Turning Off Vampire",
                icon: .systemSymbol("exclamationmark.triangle.fill"),
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
        statusItem.button?.image = StatusIconRenderer.image(for: presentation.icon)
        statusItem.button?.setAccessibilityLabel(presentation.statusTitle)

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

        let about = NSMenuItem(title: "About Vampire", action: #selector(showAbout), keyEquivalent: "")
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

private enum StatusIconRenderer {
    static func image(for icon: MenuIcon) -> NSImage? {
        switch icon {
        case let .systemSymbol(name):
            return NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case let .vampire(isAwake):
            return vampireImage(isAwake: isAwake)
        }
    }

    private static func vampireImage(isAwake: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let coffin = NSBezierPath()
            coffin.move(to: NSPoint(x: 6, y: 1.5))
            coffin.line(to: NSPoint(x: 12, y: 1.5))
            coffin.line(to: NSPoint(x: 15, y: 5.5))
            coffin.line(to: NSPoint(x: 13, y: 16.5))
            coffin.line(to: NSPoint(x: 5, y: 16.5))
            coffin.line(to: NSPoint(x: 3, y: 5.5))
            coffin.close()

            NSColor.black.set()
            if isAwake {
                coffin.fill()
            } else {
                coffin.lineWidth = 1.4
                coffin.lineJoinStyle = .round
                coffin.stroke()
            }

            let crescent = NSBezierPath()
            crescent.windingRule = .evenOdd
            crescent.appendOval(in: NSRect(x: 6, y: 6, width: 6, height: 7))
            crescent.appendOval(in: NSRect(x: 8, y: 7, width: 5, height: 6))

            if isAwake {
                NSGraphicsContext.current?.compositingOperation = .destinationOut
            }
            crescent.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
