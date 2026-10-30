import ArgumentParser

struct AppPreviewsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "appPreviews",
        abstract: "Manage app previews for an App Store version localization.",
        discussion: "List shows placements. Add --requirements to see valid Apple placement groups and media specifications. Upload transfers one file and attaches it to the localization. Remove detaches the placement and retains the reusable asset. Writes support preview, confirmation, and reconciliation.",
        subcommands: [AppPreviewsListCommand.self, AppPreviewsGetCommand.self, AppPreviewsUploadCommand.self, AppPreviewsDownloadCommand.self, AppPreviewsRemoveCommand.self, AppPreviewsReorderCommand.self],
    )
}
