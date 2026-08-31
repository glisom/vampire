import Foundation

public enum AppConstants {
    public static let appBundleID = "co.groundwork-ai.insomnia"
    public static let helperLabel = "co.groundwork-ai.insomnia.helper"
    public static let helperPlistName = "co.groundwork-ai.insomnia.helper.plist"
    public static let helperVersion = "1"
    public static let recoveryDirectory = URL(fileURLWithPath: "/Library/Application Support/Insomnia", isDirectory: true)
    public static let recoveryMarker = recoveryDirectory.appendingPathComponent("active.plist")
}
