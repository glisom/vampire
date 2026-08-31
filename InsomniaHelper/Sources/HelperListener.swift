import Foundation
import InsomniaShared

final class HelperListener: NSObject, NSXPCListenerDelegate {
    private let controller: HelperControlling
    private let teamIdentifierProvider: TeamIdentifierProviding
    private var listener: NSXPCListener?

    init(
        controller: HelperControlling,
        teamIdentifierProvider: TeamIdentifierProviding = SecurityTeamIdentifierProvider()
    ) {
        self.controller = controller
        self.teamIdentifierProvider = teamIdentifierProvider
    }

    func start() throws {
        let teamIdentifier = try teamIdentifierProvider.currentTeamIdentifier()
        let requirement = try SigningRequirementBuilding.requirement(
            appIdentifier: AppConstants.appBundleID,
            teamIdentifier: teamIdentifier
        )
        let listener = NSXPCListener(machServiceName: AppConstants.helperLabel)
        try listener.setConnectionCodeSigningRequirement(requirement)
        listener.delegate = self
        self.listener = listener
        listener.activate()
        RunLoop.current.run()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let recovery = ConnectionInvalidationRecovery(controller: controller)
        connection.exportedInterface = NSXPCInterface(with: InsomniaHelperXPC.self)
        connection.exportedObject = HelperService(controller: controller)
        connection.invalidationHandler = {
            recovery.invalidate()
        }
        connection.activate()
        return true
    }
}
