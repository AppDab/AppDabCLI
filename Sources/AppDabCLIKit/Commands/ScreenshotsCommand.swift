import ArgumentParser

struct ScreenshotsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshots",
        abstract: "Manage screenshots for an App Store version localization.",
        discussion: "List shows placements. Add --requirements to see valid Apple placement groups and media specifications. Upload transfers one file and attaches it to the localization. Remove detaches the placement and retains the reusable asset. Writes support preview, confirmation, and reconciliation.",
        subcommands: [ScreenshotsListCommand.self, ScreenshotsGetCommand.self, ScreenshotsUploadCommand.self, ScreenshotsDownloadCommand.self, ScreenshotsRemoveCommand.self, ScreenshotsReorderCommand.self],
    )
}
