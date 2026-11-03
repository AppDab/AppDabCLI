import Foundation

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
