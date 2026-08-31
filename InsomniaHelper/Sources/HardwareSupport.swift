import Darwin
import Foundation
import IOKit.ps

protocol HardwareChecking {
    var isSupportedMacBook: Bool { get }
}

struct MacBookHardwareSupport: HardwareChecking {
    private let modelIdentifier: String
    private let hasInternalBattery: Bool

    init(
        modelIdentifier: String = MacBookHardwareSupport.currentModelIdentifier(),
        hasInternalBattery: Bool = MacBookHardwareSupport.currentHasInternalBattery()
    ) {
        self.modelIdentifier = modelIdentifier
        self.hasInternalBattery = hasInternalBattery
    }

    var isSupportedMacBook: Bool {
        modelIdentifier.hasPrefix("MacBook")
            || (modelIdentifier.hasPrefix("Mac") && hasInternalBattery)
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

    private static func currentHasInternalBattery() -> Bool {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as NSArray

        return sources.contains { source in
            guard let unmanagedDescription = IOPSGetPowerSourceDescription(
                snapshot,
                source as CFTypeRef
            ) else {
                return false
            }
            let description = unmanagedDescription.takeUnretainedValue() as NSDictionary
            return description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }
}
