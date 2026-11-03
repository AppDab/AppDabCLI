#!/usr/bin/env swift
import CryptoKit
import Foundation

// Shared implementation for the small Bash entry points in this directory.
let team = "R7YA4RGA8U"
let bundleID = "app.AppDab.AppDabCLI"
let accessGroup = team + ".app.AppDab.AppDab"
let files = FileManager.default
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) {
        description = message
    }
}

struct Result {
    let status: Int32
    let output: Data
    let error: Data
    var text: String {
        String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@discardableResult
func run(_ arguments: [String], capture: Bool = false, allowFailure: Bool = false, timeout: TimeInterval? = nil) throws -> Result {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    // Files avoid pipe deadlocks when a tool produces substantial output.
    let directory = try temporaryDirectory()
    defer { try? files.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("stdout")
    let errorURL = directory.appendingPathComponent("stderr")
    files.createFile(atPath: outputURL.path, contents: nil)
    files.createFile(atPath: errorURL.path, contents: nil)
    let output = try FileHandle(forWritingTo: outputURL)
    let error = try FileHandle(forWritingTo: errorURL)
    defer { try? output.close(); try? error.close() }
    if capture {
        process.standardOutput = output; process.standardError = error
    }
    try process.run()
    let timer = timeout.map { interval in
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        timer.resume()
        return timer
    }
    process.waitUntilExit()
    timer?.cancel()
    if timeout != nil, process.terminationReason == .uncaughtSignal, process.terminationStatus == SIGTERM {
        throw Failure("The command exceeded its time limit.")
    }
    let result = try Result(status: process.terminationStatus, output: Data(contentsOf: outputURL), error: Data(contentsOf: errorURL))
    if result.status != 0, !allowFailure {
        // Captured account responses are never included in diagnostics.
        throw Failure("\(arguments.prefix(2).joined(separator: " ")) failed (status \(result.status)).")
    }
    return result
}

func temporaryDirectory(in parent: URL = files.temporaryDirectory) throws -> URL {
    let directory = parent.appendingPathComponent("appdab-distribution-" + UUID().uuidString)
    try files.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return directory
}

func plist(_ data: Data) throws -> [String: Any] {
    guard let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw Failure("Expected a property list dictionary.") }
    return value
}

func writePlist(_ value: [String: Any], to url: URL) throws {
    try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0).write(to: url)
}

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

func validateVersion(_ version: String) throws {
    guard version.range(of: #"\A[0-9]+\.[0-9]+\.[0-9]+\z"#, options: .regularExpression) != nil else { throw Failure("Version must contain three numeric components, such as 1.0.0.") }
}

func checksum(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
        hash.update(data: data)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}

struct Options {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    init(_ arguments: [String], required: [String], optional: [String] = [], flags allowedFlags: [String] = []) throws {
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard values[key] == nil, !flags.contains(key) else { throw Failure("Duplicate option: \(key)") }
            if allowedFlags.contains(key) {
                flags.insert(key)
            } else {
                guard (required + optional).contains(key), index + 1 < arguments.count else { throw Failure("Unknown or incomplete option: \(key)") }
                index += 1
                values[key] = arguments[index]
            }
            index += 1
        }
        for key in required where values[key] == nil {
            throw Failure("Missing required option: \(key)")
        }
    }

    subscript(_ key: String) -> String {
        values[key] ?? ""
    }

    func url(_ key: String) -> URL {
        URL(fileURLWithPath: self[key]).standardizedFileURL
    }
}

func package(_ options: Options) throws {
    let version = options["--version"]
    try validateVersion(version)
    let development = options.flags.contains("--development")
    guard !development || options["--notary-profile"].isEmpty else { throw Failure("Development packages cannot be submitted for notarization.") }
    let profileURL = options.url("--profile")
    let profile = try plist(run(["security", "cms", "-D", "-i", profileURL.path], capture: true).output)
    try validateProfile(profile, development: development)
    let output = options.values["--output"].map { URL(fileURLWithPath: $0).standardizedFileURL } ?? repo.appendingPathComponent(".build/distribution")
    try files.createDirectory(at: output, withIntermediateDirectories: true)
    let destination = output.appendingPathComponent("AppDabCLI-" + version)
    let archive = output.appendingPathComponent("AppDabCLI-" + version + ".zip")
    let digest = archive.appendingPathExtension("sha256")
    guard ![destination, archive, digest].contains(where: { files.fileExists(atPath: $0.path) }) else { throw Failure("The output version already exists; choose an empty output directory.") }
    let binary: URL
    if options.values["--binary"] != nil {
        binary = options.url("--binary")
    } else {
        let flags = ["--package-path", repo.path, "--configuration", "release", "--arch", "arm64", "--arch", "x86_64", "--scratch-path", repo.appendingPathComponent(".build/distribution-build").path, "--force-resolved-versions"]
        try run(["swift", "build", "--product", "dab", "-j", "4"] + flags)
        binary = try URL(fileURLWithPath: run(["swift", "build", "--show-bin-path"] + flags, capture: true).text).appendingPathComponent("dab")
    }
    let architectures = try run(["lipo", "-archs", binary.path], capture: true).text.split(separator: " ").map(String.init)
    guard development || Set(["arm64", "x86_64"]).isSubset(of: Set(architectures)) else { throw Failure("Distribution requires a universal arm64 and x86_64 executable.") }
    let stage = try temporaryDirectory(in: output)
    defer { try? files.removeItem(at: stage) }
    let app = stage.appendingPathComponent("AppDabCLI.app")
    let contents = app.appendingPathComponent("Contents")
    try files.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
    try files.copyItem(at: binary, to: contents.appendingPathComponent("MacOS/dab"))
    let resources = contents.appendingPathComponent("Resources")
    try files.createDirectory(at: resources, withIntermediateDirectories: true)
    for bundle in try files.contentsOfDirectory(at: binary.deletingLastPathComponent(), includingPropertiesForKeys: nil) where bundle.pathExtension == "bundle" {
        try files.copyItem(at: bundle, to: resources.appendingPathComponent(bundle.lastPathComponent))
        try files.createSymbolicLink(atPath: app.appendingPathComponent(bundle.lastPathComponent).path, withDestinationPath: "Contents/Resources/" + bundle.lastPathComponent)
    }
    var info = try plist(Data(contentsOf: repo.appendingPathComponent("Distribution/Info.plist")))
    info["CFBundleShortVersionString"] = version
    info["CFBundleVersion"] = version
    try writePlist(info, to: contents.appendingPathComponent("Info.plist"))
    try files.copyItem(at: profileURL, to: contents.appendingPathComponent("embedded.provisionprofile"))
    var signing = ["codesign", "--force", "--sign", options["--identity"], "--options", "runtime", "--entitlements", repo.appendingPathComponent("Distribution/AppDabCLI.entitlements").path]
    if !development {
        signing.append("--timestamp")
    }
    try run(signing + [app.path])
    try inspect(app)
    let prefix = stage.appendingPathComponent("signer-").path
    try run(["codesign", "--display", "--extract-certificates=" + prefix, app.path], capture: true)
    guard try (profile["DeveloperCertificates"] as? [Data] ?? []).contains(Data(contentsOf: URL(fileURLWithPath: prefix + "0"))) else { throw Failure("The signing certificate is not authorized by the provisioning profile.") }
    let details = try run(["codesign", "--display", "--verbose=4", app.path], capture: true)
    guard development || String(decoding: details.error, as: UTF8.self).contains("Authority=Developer ID Application:") else { throw Failure("Distribution requires a Developer ID Application signing identity.") }
    var finished = false
    defer {
        if !finished {
            try? files.removeItem(at: archive); try? files.removeItem(at: digest); try? files.removeItem(at: destination)
        }
    }
    try run(["ditto", "-c", "-k", "--keepParent", app.path, archive.path])
    if !options["--notary-profile"].isEmpty {
        var notary = ["xcrun", "notarytool", "submit", archive.path, "--keychain-profile", options["--notary-profile"], "--wait", "--output-format", "json"]
        if !options["--notary-keychain"].isEmpty {
            notary += ["--keychain", options["--notary-keychain"]]
        }
        let submission = try JSONSerialization.jsonObject(with: run(notary, capture: true).output) as? [String: Any]
        guard submission?["status"] as? String == "Accepted" else { throw Failure("Notarization was not accepted. Submission: \(submission?["id"] as? String ?? "unknown")") }
        try run(["xcrun", "stapler", "staple", app.path])
        try run(["xcrun", "stapler", "validate", app.path])
        try run(["spctl", "--assess", "--type", "execute", "--verbose=2", app.path])
        try files.removeItem(at: archive)
        try run(["ditto", "-c", "-k", "--keepParent", app.path, archive.path])
    }
    try (checksum(archive) + "  " + archive.lastPathComponent + "\n").write(to: digest, atomically: true, encoding: .utf8)
    try files.createDirectory(at: destination, withIntermediateDirectories: false)
    try files.moveItem(at: app, to: destination.appendingPathComponent(app.lastPathComponent))
    finished = true
    print("Package: \(destination.appendingPathComponent(app.lastPathComponent).path)\nArchive: \(archive.path)")
    if development {
        print("Development proof only. This package is not suitable for distribution.")
    } else if options["--notary-profile"].isEmpty {
        print("Signed but not notarized. Supply --notary-profile before distribution.")
    }
}

func inspect(_ app: URL) throws {
    try run(["codesign", "--verify", "--strict", app.path])
    let entitlements = try plist(run(["codesign", "--display", "--entitlements", ":-", app.path], capture: true).output)
    guard entitlements["com.apple.security.app-sandbox"] as? Bool != true else { throw Failure("The standalone package is unexpectedly sandboxed.") }
    guard entitlements["keychain-access-groups"] as? [String] == [accessGroup] else { throw Failure("Unexpected signed Keychain access groups.") }
    let info = try plist(Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")))
    guard info["AppDabSharedKeychain"] as? Bool == true else { throw Failure("The package does not select shared Keychain storage.") }
}

func accountIDs(_ executable: URL) throws -> Set<String> {
    let result = try run([executable.path, "accounts", "list", "--format", "json"], capture: true, timeout: 30)
    guard let response = try JSONSerialization.jsonObject(with: result.output) as? [String: Any], let data = response["data"] as? [String: Any], let accounts = data["accounts"] as? [[String: Any]] else { throw Failure("Unexpected account lookup response.") }
    return try Set(accounts.map { account in
        guard let id = account["accountID"] as? String else { throw Failure("Missing account identifier.") }
        return id
    })
}

func verify(_ options: Options) throws {
    let app = options.url("--app")
    try inspect(app)
    let root = try temporaryDirectory()
    defer { try? files.removeItem(at: root) }
    let link = root.appendingPathComponent("dab")
    try files.createSymbolicLink(at: link, withDestinationURL: app.appendingPathComponent("Contents/MacOS/dab"))
    let identifiers = try accountIDs(link)
    guard options.flags.contains("--allow-empty") || !identifiers.isEmpty else { throw Failure("No shared accounts found. Configure an account in AppDab before verifying sharing.") }
    if options.values["--previous-app"] != nil {
        let previous = options.url("--previous-app")
        try inspect(previous)
        try files.removeItem(at: link)
        try files.createSymbolicLink(at: link, withDestinationURL: previous.appendingPathComponent("Contents/MacOS/dab"))
        guard try accountIDs(link) == identifiers else { throw Failure("Shared accounts changed between package versions.") }
    }
    let unentitled = root.appendingPathComponent("Unentitled.app")
    try files.copyItem(at: app, to: unentitled)
    try files.removeItem(at: unentitled.appendingPathComponent("Contents/embedded.provisionprofile"))
    let empty = root.appendingPathComponent("empty.entitlements")
    try writePlist([:], to: empty)
    try run(["codesign", "--force", "--sign", "-", "--entitlements", empty.path, unentitled.path], capture: true)
    let rejected = try run([unentitled.appendingPathComponent("Contents/MacOS/dab").path, "accounts", "list", "--format", "json"], capture: true, allowFailure: true, timeout: 30)
    guard rejected.status != 0 else { throw Failure("A shared mode package without Keychain authorization unexpectedly succeeded.") }
    print("PASS: signed unsandboxed CLI, symlink invocation, shared account count \(identifiers.count), and rejection without authorization.")
    if options.values["--previous-app"] != nil {
        print("PASS: shared accounts remain available across package versions.")
    }
}

func validateArchivePath(_ path: String, link: String? = nil) throws {
    let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard !path.hasPrefix("/"), !path.contains("\0"), !path.contains("\n"), !path.contains("\r"), !parts.contains(".."), let root = parts.first, ["AppDabCLI.app", "__MACOSX"].contains(root) else { throw Failure("Unexpected archive path.") }
    if let link {
        guard !link.hasPrefix("/"), !link.contains("\0") else { throw Failure("Archive symlink leaves the bundle.") }
        var resolved = Array(parts.dropLast())
        for part in link.split(separator: "/").map(String.init) {
            if part == ".." {
                guard resolved.count > 1 else { throw Failure("Archive symlink leaves the bundle.") }
                resolved.removeLast()
            } else if part != "." {
                resolved.append(part)
            }
        }
    }
}

/// Inspect ZIP central directory metadata before allowing ditto to extract anything.
/// ZIP64 is unnecessary for these CLI packages and is deliberately rejected.
func validateArchive(_ archive: URL) throws {
    let data = try Data(contentsOf: archive, options: .mappedIfSafe)
    func integer(_ offset: Int, _ count: Int) throws -> Int {
        guard offset >= 0, offset <= data.count - count else { throw Failure("Truncated ZIP archive.") }
        return (0 ..< count).reduce(0) { $0 | Int(data[offset + $1]) << ($1 * 8) }
    }
    guard data.count >= 22 else { throw Failure("Invalid ZIP archive.") }
    let lower = max(0, data.count - 65557)
    var end: Int?
    for offset in stride(from: data.count - 22, through: lower, by: -1) {
        if try integer(offset, 4) == 0x0605_4B50, try offset + 22 + integer(offset + 20, 2) == data.count {
            end = offset; break
        }
    }
    guard let end else { throw Failure("Missing ZIP directory.") }
    let count = try integer(end + 10, 2)
    guard try integer(end + 4, 2) == 0, try integer(end + 6, 2) == 0, try integer(end + 8, 2) == count, count > 0, count < 65535 else { throw Failure("Unsupported ZIP directory.") }
    var offset = try integer(end + 16, 4)
    let directoryEnd = try offset + integer(end + 12, 4)
    guard directoryEnd == end else { throw Failure("Unsupported ZIP directory layout.") }
    var names: Set<String> = []
    for _ in 0 ..< count {
        guard try integer(offset, 4) == 0x0201_4B50 else { throw Failure("Invalid ZIP entry.") }
        let length = try integer(offset + 28, 2)
        let extra = try integer(offset + 30, 2)
        let comment = try integer(offset + 32, 2)
        let next = offset + 46 + length + extra + comment
        guard next <= directoryEnd else { throw Failure("Truncated ZIP entry.") }
        guard let name = String(data: data.subdata(in: offset + 46 ..< offset + 46 + length), encoding: .utf8), names.insert(name).inserted else { throw Failure("Invalid or duplicate ZIP path.") }
        try validateArchivePath(name)
        let mode = try integer(offset + 38, 4) >> 16
        if mode & 0o170000 == 0o120000 {
            guard try integer(offset + 24, 4) <= 4096 else { throw Failure("Oversized archive symlink.") }
            let target = try run(["unzip", "-p", archive.path, name], capture: true).output
            guard let link = String(data: target, encoding: .utf8) else { throw Failure("Invalid archive symlink.") }
            try validateArchivePath(name, link: link)
        }
        offset = next
    }
    guard offset == directoryEnd else { throw Failure("Invalid ZIP directory length.") }
}

func renderCask(version: String, sha256: String) throws -> String {
    try validateVersion(version)
    guard sha256.range(of: #"\A[0-9a-f]{64}\z"#, options: .regularExpression) != nil else { throw Failure("Invalid archive SHA256.") }
    return """
    cask "appdab-cli" do
      version "\(version)"
      sha256 "\(sha256)"

      url "https://github.com/AppDab/AppDabCLI/releases/download/v#{version}/AppDabCLI-#{version}.zip"
      name "AppDab CLI"
      desc "App Store Connect automation with shared AppDab credentials"
      homepage "https://github.com/AppDab/AppDabCLI"

      depends_on macos: ">= :sequoia"

      app "AppDabCLI.app"
      binary "#{appdir}/AppDabCLI.app/Contents/MacOS/dab", target: "dab"
    end

    """
}

func cask(_ options: Options) throws {
    let version = options["--version"]
    try validateVersion(version)
    let archive = options.url("--archive")
    guard archive.lastPathComponent == "AppDabCLI-" + version + ".zip" else { throw Failure("Archive filename must match the supplied version.") }
    let output = options.url("--output")
    guard !files.fileExists(atPath: output.path) else { throw Failure("Refusing to overwrite an existing cask.") }
    try validateArchive(archive)
    let temporary = try temporaryDirectory()
    defer { try? files.removeItem(at: temporary) }
    try run(["ditto", "-x", "-k", archive.path, temporary.path])
    let app = temporary.appendingPathComponent("AppDabCLI.app")
    let info = try plist(Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")))
    guard info["CFBundleShortVersionString"] as? String == version, info["CFBundleIdentifier"] as? String == bundleID, info["AppDabSharedKeychain"] as? Bool == true else { throw Failure("The archive does not contain the expected CLI release.") }
    try run(["codesign", "--verify", "--deep", "--strict", app.path])
    try run(["xcrun", "stapler", "validate", app.path])
    let content = try renderCask(version: version, sha256: checksum(archive))
    try files.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(content.utf8).write(to: output, options: .withoutOverwriting)
    print("Generated: \(output.path)")
}

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

let usage = """
Usage:
  scripts/package_cli.sh --version VERSION --identity ID --profile PATH [--output DIR]
    [--binary PATH] [--development] [--notary-profile NAME] [--notary-keychain PATH]
  scripts/generate_homebrew_cask.sh --version VERSION --archive PATH --output PATH
  scripts/verify_keychain_access.sh --app PATH [--previous-app PATH] [--allow-empty]
  scripts/test_distribution.sh

Packaging signs a universal CLI app. Add --notary-profile to notarize before distribution.
--development permits local development signing only. Output files are never overwritten.
Cask generation requires a signed archive with a stapled notarization ticket.
Keychain verification reads accounts without printing credentials or changing the store.
"""

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard let command = arguments.first else { throw Failure(usage) }
    let rest = Array(arguments.dropFirst())
    if rest == ["--help"] || command == "--help" {
        print(usage)
    } else {
        switch command {
        case "package": try package(Options(rest, required: ["--version", "--identity", "--profile"], optional: ["--output", "--binary", "--notary-profile", "--notary-keychain"], flags: ["--development"]))
        case "cask": try cask(Options(rest, required: ["--version", "--archive", "--output"]))
        case "verify": try verify(Options(rest, required: ["--app"], optional: ["--previous-app"], flags: ["--allow-empty"]))
        case "test":
            guard rest.isEmpty else { throw Failure(usage) }
            try tests()
        default: throw Failure(usage)
        }
    }
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
