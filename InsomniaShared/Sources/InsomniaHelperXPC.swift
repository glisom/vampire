import Foundation

@objc public protocol InsomniaHelperXPC {
    func getStatus(reply: @escaping (Int, String, Int, String?) -> Void)
    func setEnabled(_ enabled: Bool, reply: @escaping (Int, Int, String?) -> Void)
}
