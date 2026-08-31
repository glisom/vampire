import Foundation

protocol PowerSettingsManaging {
    func setSleepDisabled(_ disabled: Bool) throws
    func readSleepDisabled() throws -> Bool?
}

enum PMSetError: Error, Equatable {
    case unsupportedHardware
    case commandFailed(Int32, String)
    case verificationFailed
}

final class PMSetController: PowerSettingsManaging {
    private static let executable = URL(fileURLWithPath: "/usr/bin/pmset")
    private let runner: CommandRunning
    private let hardware: HardwareChecking

    init(runner: CommandRunning, hardware: HardwareChecking) {
        self.runner = runner
        self.hardware = hardware
    }

    func setSleepDisabled(_ disabled: Bool) throws {
        let requestedValue = disabled ? "1" : "0"
        let write = try runner.run(
            executable: Self.executable,
            arguments: ["-a", "disablesleep", requestedValue]
        )
        guard write.exitCode == 0 else {
            throw PMSetError.commandFailed(write.exitCode, write.stderr)
        }

        if let reportedValue = try readSleepDisabled() {
            guard reportedValue == disabled else {
                throw PMSetError.verificationFailed
            }
        } else if !hardware.isSupportedMacBook {
            throw PMSetError.unsupportedHardware
        }
    }

    func readSleepDisabled() throws -> Bool? {
        let readback = try runner.run(executable: Self.executable, arguments: ["-g", "custom"])
        guard readback.exitCode == 0 else {
            throw PMSetError.commandFailed(readback.exitCode, readback.stderr)
        }

        let values = readback.stdout.split(whereSeparator: \Character.isNewline).compactMap { line -> Bool? in
            let fields = line.split(whereSeparator: \Character.isWhitespace)
            guard fields.count == 2, fields[0] == "disablesleep" else {
                return nil
            }
            switch fields[1] {
            case "0": return false
            case "1": return true
            default: return nil
            }
        }

        guard let first = values.first else {
            return nil
        }
        guard values.allSatisfy({ $0 == first }) else {
            throw PMSetError.verificationFailed
        }
        return first
    }
}
