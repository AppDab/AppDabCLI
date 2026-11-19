import Foundation

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
    print("PASS: signed unsandboxed CLI, symlink invocation, shared account count \(identifiers.count).")
    if options.values["--previous-app"] != nil {
        print("PASS: shared accounts remain available across package versions.")
    }
}
