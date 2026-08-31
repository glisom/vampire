import XCTest

final class SigningRequirementTests: XCTestCase {
    func testRequirementPinsIdentifierAndTeam() throws {
        XCTAssertEqual(
            try SigningRequirementBuilding.requirement(
                appIdentifier: "co.groundwork-ai.insomnia",
                teamIdentifier: "ABCDE12345"
            ),
            "identifier \"co.groundwork-ai.insomnia\" and anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
    }

    func testEmptyTeamIdentifierIsRejected() {
        XCTAssertThrowsError(
            try SigningRequirementBuilding.requirement(
                appIdentifier: "co.groundwork-ai.insomnia",
                teamIdentifier: ""
            )
        )
    }
}
