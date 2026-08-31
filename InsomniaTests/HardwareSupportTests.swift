import XCTest
@testable import Insomnia

final class HardwareSupportTests: XCTestCase {
    func testMacBookModelIdentifiersAreSupported() {
        XCTAssertTrue(MacBookHardwareSupport(modelIdentifier: "MacBookPro18,3").isSupportedMacBook)
        XCTAssertTrue(MacBookHardwareSupport(modelIdentifier: "MacBookAir10,1").isSupportedMacBook)
    }

    func testModelsWithoutBuiltInLidAreUnsupported() {
        XCTAssertFalse(MacBookHardwareSupport(modelIdentifier: "Mac14,2").isSupportedMacBook)
        XCTAssertFalse(MacBookHardwareSupport(modelIdentifier: "iMac21,1").isSupportedMacBook)
        XCTAssertFalse(MacBookHardwareSupport(modelIdentifier: "").isSupportedMacBook)
    }
}
