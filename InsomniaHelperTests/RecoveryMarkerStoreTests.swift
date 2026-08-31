import Foundation
import XCTest

final class RecoveryMarkerStoreTests: XCTestCase {
    func testCreateWritesOnlyActiveTrueWithPrivatePermissions() throws {
        let fixture = try MarkerFixture()
        defer { fixture.cleanup() }
        let sut = FileRecoveryMarkerStore(markerURL: fixture.markerURL)

        try sut.create()

        XCTAssertTrue(sut.exists)
        let data = try Data(contentsOf: fixture.markerURL)
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Bool])
        XCTAssertEqual(plist, ["active": true])
        let attributes = try FileManager.default.attributesOfItem(atPath: fixture.markerURL.path)
        XCTAssertEqual(attributes[.posixPermissions] as? NSNumber, NSNumber(value: 0o600))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: fixture.directoryURL.path), ["active.plist"])
    }

    func testRemoveDeletesExistingMarker() throws {
        let fixture = try MarkerFixture()
        defer { fixture.cleanup() }
        let sut = FileRecoveryMarkerStore(markerURL: fixture.markerURL)
        try sut.create()

        try sut.remove()

        XCTAssertFalse(sut.exists)
    }

    func testRemoveIsIdempotentWhenMarkerIsAbsent() throws {
        let fixture = try MarkerFixture()
        defer { fixture.cleanup() }
        let sut = FileRecoveryMarkerStore(markerURL: fixture.markerURL)

        XCTAssertNoThrow(try sut.remove())
        XCTAssertFalse(sut.exists)
    }
}

private final class MarkerFixture {
    let directoryURL: URL
    let markerURL: URL

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("InsomniaMarkerTests-\(UUID().uuidString)", isDirectory: true)
        markerURL = directoryURL.appendingPathComponent("active.plist")
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
