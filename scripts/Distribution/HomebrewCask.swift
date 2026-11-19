import Foundation

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
