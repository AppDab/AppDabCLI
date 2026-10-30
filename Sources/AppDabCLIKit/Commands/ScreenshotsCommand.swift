import ArgumentParser

struct ScreenshotsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshots",
        abstract: "Manage screenshots for an App Store version localization.",
        discussion: "List shows valid Apple placement groups. Upload transfers one file and attaches it to the localization. Remove detaches the placement and retains the reusable asset. Writes support preview, confirmation, and reconciliation.",
        subcommands: [ScreenshotsListCommand.self, ScreenshotsGetCommand.self, ScreenshotsUploadCommand.self, ScreenshotsDownloadCommand.self, ScreenshotsRemoveCommand.self, ScreenshotsReorderCommand.self],
    )
}
