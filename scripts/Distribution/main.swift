import Foundation

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
