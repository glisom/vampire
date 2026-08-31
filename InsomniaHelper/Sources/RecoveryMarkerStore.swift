import Foundation

protocol RecoveryMarkerStoring {
    var exists: Bool { get }
    func create() throws
    func remove() throws
}

final class FileRecoveryMarkerStore: RecoveryMarkerStoring {
    private let markerURL: URL
    private let fileManager: FileManager

    init(markerURL: URL, fileManager: FileManager = .default) {
        self.markerURL = markerURL
        self.fileManager = fileManager
    }

    var exists: Bool {
        fileManager.fileExists(atPath: markerURL.path)
    }

    func create() throws {
        let directoryURL = markerURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)

        let data = try PropertyListSerialization.data(
            fromPropertyList: ["active": true],
            format: .binary,
            options: 0
        )
        do {
            try data.write(to: markerURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: markerURL.path)
        } catch {
            try? fileManager.removeItem(at: markerURL)
            throw error
        }
    }

    func remove() throws {
        guard exists else { return }
        try fileManager.removeItem(at: markerURL)
    }
}
