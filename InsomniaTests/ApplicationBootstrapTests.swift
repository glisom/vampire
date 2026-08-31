import AppKit
import XCTest
@testable import Insomnia

@MainActor
final class ApplicationBootstrapTests: XCTestCase {
    func testBootstrapInstallsAndRetainsAppDelegate() {
        let application = NSApplication.shared
        let previousDelegate = application.delegate
        defer { application.delegate = previousDelegate }

        var delegate: AppDelegate? = AppDelegate()
        weak var weakDelegate = delegate
        let bootstrap = ApplicationBootstrap(
            application: application,
            delegate: delegate!
        )
        delegate = nil

        XCTAssertTrue(application.delegate === weakDelegate)
        XCTAssertNotNil(weakDelegate)
        withExtendedLifetime(bootstrap) {}
    }
}
