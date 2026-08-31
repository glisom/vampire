import XCTest
@testable import Insomnia

final class HardwareSupportTests: XCTestCase {
    func testMacBookModelIdentifiersAreSupported() {
        XCTAssertTrue(
            MacBookHardwareSupport(
                modelIdentifier: "MacBookPro18,3",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
        XCTAssertTrue(
            MacBookHardwareSupport(
                modelIdentifier: "MacBookAir10,1",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
    }

    func testModernMacModelWithInternalBatteryIsSupported() {
        XCTAssertTrue(
            MacBookHardwareSupport(
                modelIdentifier: "Mac17,2",
                hasInternalBattery: true
            ).isSupportedMacBook
        )
    }

    func testModelsWithoutBuiltInLidAreUnsupported() {
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "Mac14,2",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "iMac21,1",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "iMac21,1",
                hasInternalBattery: true
            ).isSupportedMacBook
        )
        XCTAssertFalse(
            MacBookHardwareSupport(
                modelIdentifier: "",
                hasInternalBattery: false
            ).isSupportedMacBook
        )
    }
}
