import ConnectKeychain
import Foundation

enum CLIKeychainConfiguration: Sendable {
    case standalone
    case sharedAppDab

    static let sharedAccessGroup = "R7YA4RGA8U.app.AppDab.AppDab"

    static var current: Self {
        // This flag is part of the signed release bundle, not a command or environment override.
        Bundle.main.object(forInfoDictionaryKey: "AppDabSharedKeychain") as? Bool == true ? .sharedAppDab : .standalone
    }

    var serviceName: String {
        switch self {
        case .standalone: "AppDabCLI"
        case .sharedAppDab: "AppDab"
        }
    }

    func makeKeychain() -> Keychain {
        switch self {
        case .standalone: .macOSLogin()
        case .sharedAppDab: Keychain(accessGroup: Self.sharedAccessGroup)
        }
    }
}
