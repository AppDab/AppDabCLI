import ConnectKeychain
import Foundation

enum CLIKeychainConfiguration: Sendable {
    case standalone
    case sharedAppDab

    static let sharedAccessGroup = "R7YA4RGA8U.app.AppDab.AppDab"

    static var current: Self {
        guard let executableURL = Bundle.main.executableURL else { return .standalone }
        return configuration(forExecutableAt: executableURL)
    }

    static func configuration(forExecutableAt executableURL: URL) -> Self {
        // Homebrew launches a symlink outside the app bundle. Resolve it before reading signed metadata.
        let executableURL = executableURL.resolvingSymlinksInPath()
        let executableDirectory = executableURL.deletingLastPathComponent()
        let contents = executableDirectory.deletingLastPathComponent()
        let app = contents.deletingLastPathComponent()
        guard executableDirectory.lastPathComponent == "MacOS",
              contents.lastPathComponent == "Contents",
              app.pathExtension == "app",
              let bundle = Bundle(url: app),
              bundle.executableURL?.resolvingSymlinksInPath() == executableURL
        else { return .standalone }
        return bundle.object(forInfoDictionaryKey: "AppDabSharedKeychain") as? Bool == true ? .sharedAppDab : .standalone
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
