import XCTest
@testable import InsomniaShared

final class HelperControllerTests: XCTestCase {
    func testEnableWritesMarkerBeforePMSet() {
        let recorder = EventRecorder()
        let sut = makeController(recorder: recorder)

        XCTAssertEqual(sut.setEnabled(true).state, .on)
        XCTAssertEqual(recorder.events, [.createMarker, .setPower(true)])
    }

    func testDisableSetsPMSetBeforeRemovingMarker() {
        let recorder = EventRecorder()
        let sut = makeController(markerExists: true, recorder: recorder)

        XCTAssertEqual(sut.setEnabled(false).state, .off)
        XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
    }

    func testEnableFailureAttemptsOffRecoveryAndReturnsError() {
        let recorder = EventRecorder()
        let sut = makeController(enableError: PMSetError.commandFailed(1, "failed"), recorder: recorder)

        XCTAssertEqual(sut.setEnabled(true).state, .error)
        XCTAssertEqual(recorder.events, [.createMarker, .setPower(true), .setPower(false), .removeMarker])
    }

    func testStartupAlwaysNormalizesOffWithoutMarker() {
        let recorder = EventRecorder()
        let sut = makeController(recorder: recorder)

        XCTAssertEqual(sut.normalizeAtStartup().state, .off)
        XCTAssertEqual(recorder.events, [.setPower(false)])
    }

    func testStartupClearsStaleMarkerOnlyAfterOffSucceeds() {
        let recorder = EventRecorder()
        let sut = makeController(markerExists: true, recorder: recorder)

        XCTAssertEqual(sut.normalizeAtStartup().state, .off)
        XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
    }

    func testDisconnectWhileOnRestoresOff() {
        let recorder = EventRecorder()
        let sut = makeController(markerExists: true, recorder: recorder)

        sut.connectionInvalidated()

        XCTAssertEqual(recorder.events, [.setPower(false), .removeMarker])
    }

    func testFailedRecoveryRetainsMarkerAndErrorState() {
        let recorder = EventRecorder()
        let marker = RecordingMarkerStore(exists: true, recorder: recorder)
        let sut = makeController(
            marker: marker,
            disableError: PMSetError.commandFailed(1, "failed"),
            recorder: recorder
        )

        XCTAssertEqual(sut.normalizeAtStartup().state, .error)
        XCTAssertTrue(marker.exists)
        XCTAssertEqual(recorder.events, [.setPower(false)])
    }

    func testEnableIsRejectedWhileRecoveryIsUnresolved() {
        let recorder = EventRecorder()
        let marker = RecordingMarkerStore(exists: true, recorder: recorder)
        let sut = makeController(
            marker: marker,
            disableError: PMSetError.commandFailed(1, "failed"),
            recorder: recorder
        )

        XCTAssertEqual(sut.normalizeAtStartup().state, .error)
        XCTAssertEqual(sut.setEnabled(true).error, .recoveryFailed)
        XCTAssertEqual(recorder.events, [.setPower(false)])
    }
}

private enum RecordedEvent: Equatable {
    case createMarker
    case removeMarker
    case setPower(Bool)
}

private final class EventRecorder {
    var events: [RecordedEvent] = []
}

private final class RecordingMarkerStore: RecoveryMarkerStoring {
    var exists: Bool
    private let recorder: EventRecorder

    init(exists: Bool, recorder: EventRecorder) {
        self.exists = exists
        self.recorder = recorder
    }

    func create() throws {
        recorder.events.append(.createMarker)
        exists = true
    }

    func remove() throws {
        recorder.events.append(.removeMarker)
        exists = false
    }
}

private final class RecordingPowerSettings: PowerSettingsManaging {
    private let enableError: Error?
    private let disableError: Error?
    private let recorder: EventRecorder

    init(enableError: Error?, disableError: Error?, recorder: EventRecorder) {
        self.enableError = enableError
        self.disableError = disableError
        self.recorder = recorder
    }

    func setSleepDisabled(_ disabled: Bool) throws {
        recorder.events.append(.setPower(disabled))
        if disabled, let enableError { throw enableError }
        if !disabled, let disableError { throw disableError }
    }

    func readSleepDisabled() throws -> Bool? {
        nil
    }
}

private func makeController(
    markerExists: Bool = false,
    marker: RecordingMarkerStore? = nil,
    enableError: Error? = nil,
    disableError: Error? = nil,
    recorder: EventRecorder
) -> HelperController {
    let marker = marker ?? RecordingMarkerStore(exists: markerExists, recorder: recorder)
    let power = RecordingPowerSettings(
        enableError: enableError,
        disableError: disableError,
        recorder: recorder
    )
    return HelperController(powerSettings: power, markerStore: marker)
}
