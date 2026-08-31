import Foundation
import Security

enum TeamIdentifierError: Error {
    case signingInformationUnavailable
    case missingTeamIdentifier
    case invalidRequirementValue
}

protocol TeamIdentifierProviding {
    func currentTeamIdentifier() throws -> String
}

struct SecurityTeamIdentifierProvider: TeamIdentifierProviding {
    func currentTeamIdentifier() throws -> String {
        var currentCode: SecCode?
        guard SecCodeCopySelf([], &currentCode) == errSecSuccess, let currentCode else {
            throw TeamIdentifierError.signingInformationUnavailable
        }
        guard SecCodeCheckValidity(currentCode, [], nil) == errSecSuccess,
              let executableURL = Bundle.main.executableURL else {
            throw TeamIdentifierError.signingInformationUnavailable
        }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(executableURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else {
            throw TeamIdentifierError.signingInformationUnavailable
        }

        var signingInformation: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &signingInformation) == errSecSuccess,
              let information = signingInformation as? [CFString: Any],
              let teamIdentifier = information[kSecCodeInfoTeamIdentifier] as? String,
              !teamIdentifier.isEmpty else {
            throw TeamIdentifierError.missingTeamIdentifier
        }
        return teamIdentifier
    }
}

enum SigningRequirementBuilding {
    static func requirement(appIdentifier: String, teamIdentifier: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-"))
        guard !appIdentifier.isEmpty,
              !teamIdentifier.isEmpty,
              appIdentifier.unicodeScalars.allSatisfy(allowed.contains),
              teamIdentifier.unicodeScalars.allSatisfy(allowed.contains) else {
            throw TeamIdentifierError.invalidRequirementValue
        }

        return "identifier \"\(appIdentifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(teamIdentifier)\""
    }
}
