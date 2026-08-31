import Foundation

public enum HelperState: Int {
    case off = 0
    case on = 1
    case error = 2

    public init(xpcValue: Int) {
        self = HelperState(rawValue: xpcValue) ?? .error
    }
}

public enum HelperErrorCode: Int {
    case none = 0
    case unsupportedHardware = 1
    case commandFailed = 2
    case verificationFailed = 3
    case markerFailed = 4
    case recoveryFailed = 5
}
