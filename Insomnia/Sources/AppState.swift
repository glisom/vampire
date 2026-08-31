import Foundation

enum AppState: Equatable, Sendable {
    case setupRequired
    case unsupported
    case off
    case on
    case error(String)
}
