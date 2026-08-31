import Darwin
import Foundation

protocol HardwareChecking {
    var isSupportedMacBook: Bool { get }
}

struct MacBookHardwareSupport: HardwareChecking {
    private let modelIdentifier: String

    init(modelIdentifier: String = MacBookHardwareSupport.currentModelIdentifier()) {
        self.modelIdentifier = modelIdentifier
    }

    var isSupportedMacBook: Bool {
        modelIdentifier.hasPrefix("MacBook")
    }

    private static func currentModelIdentifier() -> String {
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else {
            return ""
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &value, &size, nil, 0) == 0 else {
            return ""
        }
        return String(cString: value)
    }
}
