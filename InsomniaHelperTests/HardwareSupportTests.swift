import XCTest

final class HardwareSupportTests: XCTestCase {
    func testLegacyMacBookIdentifiersAreSupportedWithoutBatteryReadback() {
        XCTAssertTrue(
            MacBookHardwareSupport(
                modelIdentifier: "MacBookPro18,3",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
    }

    func testModernMacIdentifierWithInternalBatteryIsSupported() {
        XCTAssertTrue(
            MacBookHardwareSupport(
                modelIdentifier: "Mac17,2",
                hasInternalBattery: true
            ).isSupportedMacBook
        )
    }

    func testNonportableModelsAreUnsupported() {
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "Mac17,2",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "iMac21,1",
                hasInternalBattery: true
            ).isSupportedMacBook
        )
    }
}
