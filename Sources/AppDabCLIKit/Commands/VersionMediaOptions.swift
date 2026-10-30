import ArgumentParser

struct VersionMediaOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "AppDab account identifier.")
    var accountID: String

    @Option(name: .customLong("version-id"), help: "App Store version identifier.")
    var versionID: String

    @Option(help: "Existing version localization locale, such as en-US.")
    var locale: String
}
