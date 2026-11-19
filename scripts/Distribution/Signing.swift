import Foundation

func matches(_ value: String, _ pattern: String) -> Bool {
    // Provisioning identifiers permit a trailing wildcard, not arbitrary glob syntax.
    if pattern.hasSuffix("*") {
        return value.hasPrefix(String(pattern.dropLast()))
    }
    return value == pattern
}

func validateProfile(_ profile: [String: Any], development: Bool = false, now: Date = Date()) throws {
    guard let expiry = profile["ExpirationDate"] as? Date, expiry > now else { throw Failure("Provisioning profile has expired or has no expiration date.") }
    guard (profile["Platform"] as? [String] ?? []).contains("OSX") else { throw Failure("A macOS provisioning profile is required.") }
    guard (profile["TeamIdentifier"] as? [String] ?? []).contains(team) else { throw Failure("The profile must belong to the AppDab developer team.") }
    let entitlements = profile["Entitlements"] as? [String: Any] ?? [:]
    guard matches(team + "." + bundleID, entitlements["com.apple.application-identifier"] as? String ?? "") else { throw Failure("The profile does not authorize the CLI bundle identifier.") }
    guard (entitlements["keychain-access-groups"] as? [String] ?? []).contains(where: { matches(accessGroup, $0) }) else { throw Failure("The profile does not authorize the AppDab Keychain access group.") }
    guard development || profile["ProvisionsAllDevices"] as? Bool == true else { throw Failure("A Developer ID provisioning profile is required for distribution; use --development only for local tests.") }
}

func inspect(_ app: URL) throws {
    try run(["codesign", "--verify", "--strict", app.path])
    let entitlements = try plist(run(["codesign", "--display", "--entitlements", ":-", app.path], capture: true).output)
    guard entitlements["com.apple.security.app-sandbox"] as? Bool != true else { throw Failure("The standalone package is unexpectedly sandboxed.") }
    guard entitlements["keychain-access-groups"] as? [String] == [accessGroup] else { throw Failure("Unexpected signed Keychain access groups.") }
    let info = try plist(Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")))
    guard info["AppDabSharedKeychain"] as? Bool == true else { throw Failure("The package does not select shared Keychain storage.") }
}
