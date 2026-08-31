import Foundation
import Security
import XCTest

final class SigningRequirementIntegrationTests: XCTestCase {
    func testAppAndHelperHaveSameTeamIdentifierWhenTeamSigned() throws {
        let app = try builtAppURL()
        let helper = app.appendingPathComponent("Contents/MacOS/InsomniaHelper")
        guard let appTeam = try teamIdentifier(at: app) else {
            throw XCTSkip("Debug build is ad-hoc signed; Team ID checks run on signed configurations.")
        }

        XCTAssertFalse(appTeam.isEmpty)
        XCTAssertEqual(try teamIdentifier(at: helper), appTeam)
    }

    func testWrongIdentifierClientFailsAppRequirementWhenTeamSigned() throws {
        let app = try builtAppURL()
        guard let team = try teamIdentifier(at: app) else {
            throw XCTSkip("Debug build is ad-hoc signed; requirement checks run on signed configurations.")
        }
        let requirementString = try SigningRequirementBuilding.requirement(
            appIdentifier: "co.groundwork-ai.insomnia",
            teamIdentifier: team
        )
        var requirement: SecRequirement?
        XCTAssertEqual(SecRequirementCreateWithString(requirementString as CFString, [], &requirement), errSecSuccess)
        let wrongClientURL = app.deletingLastPathComponent().appendingPathComponent("InsomniaWrongIdentifierClient")
        let code = try staticCode(at: wrongClientURL)

        XCTAssertNotEqual(SecStaticCodeCheckValidity(code, [], requirement), errSecSuccess)
    }
}

private func teamIdentifier(at url: URL) throws -> String? {
    let code = try staticCode(at: url)
    var information: CFDictionary?
    XCTAssertEqual(
        SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information),
        errSecSuccess
    )
    let values = try XCTUnwrap(information as? [CFString: Any])
    return values[kSecCodeInfoTeamIdentifier] as? String
}

private func staticCode(at url: URL) throws -> SecStaticCode {
    var code: SecStaticCode?
    XCTAssertEqual(SecStaticCodeCreateWithPath(url as CFURL, [], &code), errSecSuccess)
    return try XCTUnwrap(code)
}
