import Foundation
import XCTest

final class PMSetControllerTests: XCTestCase {
    func testEnableUsesOnlyFixedPMSetArguments() throws {
        let runner = RecordingCommandRunner(results: [
            .init(exitCode: 0, stdout: "", stderr: ""),
            .init(exitCode: 0, stdout: "AC Power:\n disablesleep 1\nBattery Power:\n disablesleep 1\n", stderr: "")
        ])
        let sut = PMSetController(runner: runner, hardware: SupportedHardware())

        try sut.setSleepDisabled(true)

        XCTAssertEqual(runner.calls, [
            .init(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "1"]),
            .init(executable: "/usr/bin/pmset", arguments: ["-g", "custom"])
        ])
    }

    func testDisableUsesOnlyFixedPMSetArguments() throws {
        let runner = RecordingCommandRunner(results: [
            .init(exitCode: 0, stdout: "", stderr: ""),
            .init(exitCode: 0, stdout: "AC Power:\n disablesleep 0\n", stderr: "")
        ])
        let sut = PMSetController(runner: runner, hardware: SupportedHardware())

        try sut.setSleepDisabled(false)

        XCTAssertEqual(runner.calls, [
            .init(executable: "/usr/bin/pmset", arguments: ["-a", "disablesleep", "0"]),
            .init(executable: "/usr/bin/pmset", arguments: ["-g", "custom"])
        ])
    }

    func testReadbackMismatchThrowsVerificationFailed() {
        let runner = RecordingCommandRunner(results: [
            .init(exitCode: 0, stdout: "", stderr: ""),
            .init(exitCode: 0, stdout: "AC Power:\n disablesleep 0\n", stderr: "")
        ])
        let sut = PMSetController(runner: runner, hardware: SupportedHardware())

        XCTAssertThrowsError(try sut.setSleepDisabled(true)) {
            XCTAssertEqual($0 as? PMSetError, .verificationFailed)
        }
    }

    func testDisagreeingProfilesThrowVerificationFailed() {
        let runner = RecordingCommandRunner(results: [
            .init(exitCode: 0, stdout: "", stderr: ""),
            .init(exitCode: 0, stdout: "AC Power:\n disablesleep 1\nBattery Power:\n disablesleep 0\n", stderr: "")
        ])
        let sut = PMSetController(runner: runner, hardware: SupportedHardware())

        XCTAssertThrowsError(try sut.setSleepDisabled(true)) {
            XCTAssertEqual($0 as? PMSetError, .verificationFailed)
        }
    }

    func testMissingReadbackKeyAcceptsSuccessfulWriteOnlyOnMacBook() {
        let successfulWriteWithoutKey = [
            CommandResult(exitCode: 0, stdout: "", stderr: ""),
            CommandResult(exitCode: 0, stdout: "AC Power:\n sleep 1\n", stderr: "")
        ]

        XCTAssertNoThrow(try PMSetController(
            runner: RecordingCommandRunner(results: successfulWriteWithoutKey),
            hardware: SupportedHardware()
        ).setSleepDisabled(true))
        XCTAssertThrowsError(try PMSetController(
            runner: RecordingCommandRunner(results: successfulWriteWithoutKey),
            hardware: UnsupportedHardware()
        ).setSleepDisabled(true)) {
            XCTAssertEqual($0 as? PMSetError, .unsupportedHardware)
        }
    }

    func testWriteFailureReturnsExitStatusAndStderrWithoutReadback() {
        let runner = RecordingCommandRunner(results: [
            .init(exitCode: 7, stdout: "", stderr: "permission denied")
        ])
        let sut = PMSetController(runner: runner, hardware: SupportedHardware())

        XCTAssertThrowsError(try sut.setSleepDisabled(true)) {
            XCTAssertEqual($0 as? PMSetError, .commandFailed(7, "permission denied"))
        }
        XCTAssertEqual(runner.calls.count, 1)
    }
}

private struct CommandCall: Equatable {
    let executable: String
    let arguments: [String]
}

private final class RecordingCommandRunner: CommandRunning {
    private var results: [CommandResult]
    private(set) var calls: [CommandCall] = []

    init(results: [CommandResult]) {
        self.results = results
    }

    func run(executable: URL, arguments: [String]) throws -> CommandResult {
        calls.append(.init(executable: executable.path, arguments: arguments))
        return results.removeFirst()
    }
}

private struct SupportedHardware: HardwareChecking {
    let isSupportedMacBook = true
}

private struct UnsupportedHardware: HardwareChecking {
    let isSupportedMacBook = false
}
