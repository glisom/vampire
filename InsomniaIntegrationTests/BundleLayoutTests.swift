import Foundation
import XCTest

final class BundleLayoutTests: XCTestCase {
    func testPackagedAppContainsOnlyExpectedHelperLayout() throws {
        let app = try builtAppURL()
        let helperDirectory = app.appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
        let helper = helperDirectory.appendingPathComponent("InsomniaHelper")
        let daemonPlist = helperDirectory.appendingPathComponent("co.groundwork-ai.insomnia.helper.plist")

        XCTAssertTrue(FileManager.default.isExecutableFile(atPath: helper.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: daemonPlist.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: app.appendingPathComponent("Contents/Resources/InsomniaHelper").path))
    }

    func testAppAndDaemonMetadataMatchApprovedDesign() throws {
        let app = try builtAppURL()
        let info = try plist(at: app.appendingPathComponent("Contents/Info.plist"))
        XCTAssertEqual(info["LSUIElement"] as? Bool, true)

        let daemon = try plist(
            at: app.appendingPathComponent(
                "Contents/Library/LaunchDaemons/co.groundwork-ai.insomnia.helper.plist"
            )
        )
        XCTAssertEqual(daemon["Label"] as? String, "co.groundwork-ai.insomnia.helper")
        XCTAssertEqual(daemon["RunAtLoad"] as? Bool, true)
        XCTAssertEqual(
            daemon["BundleProgram"] as? String,
            "Contents/Library/LaunchDaemons/InsomniaHelper"
        )
        let services = try XCTUnwrap(daemon["MachServices"] as? [String: Bool])
        XCTAssertEqual(services, ["co.groundwork-ai.insomnia.helper": true])
    }
}

func builtAppURL() throws -> URL {
    let url: URL
    if let products = ProcessInfo.processInfo.environment["BUILT_PRODUCTS_DIR"] {
        url = URL(fileURLWithPath: products).appendingPathComponent("Insomnia.app", isDirectory: true)
    } else {
        url = Bundle.main.bundleURL
    }
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw CocoaError(.fileNoSuchFile)
    }
    return url
}

private func plist(at url: URL) throws -> [String: Any] {
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}
