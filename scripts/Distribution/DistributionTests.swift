import Foundation

func tests() throws {
    var count = 0
    func check(_ name: String, _ body: () throws -> Void) throws {
        try body()
        count += 1
        print("PASS: " + name)
    }
    func rejects(_ body: () throws -> Void) throws {
        do { try body() } catch is Failure { return }
        throw Failure("Expected validation to reject the fixture.")
    }
    func profile() -> [String: Any] {
        ["ExpirationDate": Date(timeIntervalSince1970: 4_070_908_800), "Platform": ["OSX"], "TeamIdentifier": [team], "ProvisionsAllDevices": true,
         "Entitlements": ["com.apple.application-identifier": team + "." + bundleID, "keychain-access-groups": [team + ".*"]]]
    }
    try check("rejects profiles for another app, team, or Keychain group") {
        var wrongTeam = profile()
        wrongTeam["TeamIdentifier"] = ["ANOTHERTEAM"]
        try rejects { try validateProfile(wrongTeam) }
        for key in ["com.apple.application-identifier", "keychain-access-groups"] {
            var value = profile()
            var entitlements = value["Entitlements"] as! [String: Any]
            entitlements[key] = key == "keychain-access-groups" ? [team + ".other"] : team + ".other" as Any
            value["Entitlements"] = entitlements
            try rejects { try validateProfile(value) }
        }
    }
    try check("development profiles require explicit local test mode") {
        var value = profile()
        value["ProvisionsAllDevices"] = false
        try rejects { try validateProfile(value) }
        try validateProfile(value, development: true)
    }
    try check("expired and non macOS profiles are rejected") {
        var expired = profile()
        expired["ExpirationDate"] = Date(timeIntervalSince1970: 0)
        try rejects { try validateProfile(expired, development: true) }
        var ios = profile()
        ios["Platform"] = ["iOS"]
        try rejects { try validateProfile(ios, development: true) }
    }
    try check("explicit shared group authorization is accepted") {
        var value = profile()
        var entitlements = value["Entitlements"] as! [String: Any]
        entitlements["keychain-access-groups"] = [accessGroup]
        value["Entitlements"] = entitlements
        try validateProfile(value)
    }
    try check("cask generation rejects injection and invalid checksums") {
        try rejects { _ = try renderCask(version: "1.0.0\"; system(\"bad\")", sha256: String(repeating: "a", count: 64)) }
        try rejects { _ = try renderCask(version: "1.0.0", sha256: "missing") }
        let content = try renderCask(version: "1.2.3", sha256: String(repeating: "a", count: 64))
        guard content.contains("version \"1.2.3\""), content.contains("Contents/MacOS/dab") else { throw Failure("Missing cask release metadata.") }
    }
    try check("archive paths cannot escape the bundle") {
        for path in ["../outside", "/outside", "Other.app/file", "AppDabCLI.app/../outside"] {
            try rejects { try validateArchivePath(path) }
        }
    }
    try check("internal resource links work and escaping links are rejected") {
        try validateArchivePath("AppDabCLI.app/Locales.bundle", link: "Contents/Resources/Locales.bundle")
        for link in ["../../outside", "/outside"] {
            try rejects { try validateArchivePath("AppDabCLI.app/Locales.bundle", link: link) }
        }
    }
    try check("ZIP metadata preserves link safety before extraction") {
        let temporary = try temporaryDirectory()
        defer { try? files.removeItem(at: temporary) }
        let app = temporary.appendingPathComponent("AppDabCLI.app")
        try files.createDirectory(at: app.appendingPathComponent("Contents/Resources/Locales.bundle"), withIntermediateDirectories: true)
        let link = app.appendingPathComponent("Locales.bundle")
        try files.createSymbolicLink(atPath: link.path, withDestinationPath: "Contents/Resources/Locales.bundle")
        let archive = temporary.appendingPathComponent("safe.zip")
        try run(["ditto", "-c", "-k", "--keepParent", app.path, archive.path])
        try validateArchive(archive)
        try files.removeItem(at: link)
        try files.createSymbolicLink(atPath: link.path, withDestinationPath: "../../outside")
        let unsafe = temporary.appendingPathComponent("unsafe.zip")
        try run(["ditto", "-c", "-k", "--keepParent", app.path, unsafe.path])
        try rejects { try validateArchive(unsafe) }
        try Data("invalid ZIP".utf8).write(to: unsafe)
        try rejects { try validateArchive(unsafe) }
    }
    print("\(count) distribution tests passed.")
}
