import Foundation

struct CommandResult: Equatable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

protocol CommandRunning {
    func run(executable: URL, arguments: [String]) throws -> CommandResult
}

struct ProcessCommandRunner: CommandRunning {
    func run(executable: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        return CommandResult(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }
}
