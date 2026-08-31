import XCTest
@testable import Insomnia

final class AppLaunchEnvironmentTests: XCTestCase {
    func testXCTestHostNeverStartsProductionComposition() {
        XCTAssertFalse(
            AppLaunchEnvironment.shouldStartApplication(
                environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
            )
        )
    }

    func testNormalLaunchStartsProductionComposition() {
        XCTAssertTrue(AppLaunchEnvironment.shouldStartApplication(environment: [:]))
    }
}
