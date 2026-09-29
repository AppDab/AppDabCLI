@testable import AppDabAutomation
@testable import AppDabCLIKit
import AppDabServices
import Testing

struct AppDabCLIParserTests {
    @Test func everyRegisteredActionHasATypedCLICommand() throws {
        let registeredIDs = AutomationRegistry.standard.descriptors.map(\.id)
        let catalogIDs = AutomationCLIActionCatalog.all.map(\.id)

        #expect(catalogIDs == registeredIDs)
        #expect(catalogIDs.map(\.rawValue) == AutomationCLIActionCatalog.generatedActionIDs)
        #expect(Set(AutomationCLIActionCatalog.all.map(\.path)).count == catalogIDs.count)

        for entry in AutomationCLIActionCatalog.all {
            let invocation = try CLIParser().parse(sampleArguments(for: entry))
            #expect(invocation.actionID == entry.id)
        }
    }

    @Test func producesTypedInvocationForAppList() throws {
        let invocation = try CLIParser().parse([
            "apps",
            "list",
            "--account-id",
            "account-1",
            "--cursor",
            "cursor-1",
            "--limit",
            "25"
        ])

        #expect(invocation.actionID == .listApps)
        #expect(invocation.format == .text)
        #expect(invocation.originalArguments == [
            "apps", "list", "--account-id", "account-1", "--cursor", "cursor-1", "--limit", "25"
        ])
    }

    @Test func resourceCommandsDefaultToListActions() throws {
        let accounts = try CLIParser().parse(["accounts"])
        let apps = try CLIParser().parse(["apps", "--account-id", "account-1"])
        let versions = try CLIParser().parse([
            "appVersion", "--account-id", "account-1", "--app-id", "app-1"
        ])
        let builds = try CLIParser().parse([
            "builds", "--account-id", "account-1", "--app-id", "app-1"
        ])
        let reviews = try CLIParser().parse([
            "reviews", "--account-id", "account-1", "--app-id", "app-1"
        ])

        #expect(accounts.actionID == .listAccounts)
        #expect(apps.actionID == .listApps)
        #expect(versions.actionID == .listAppVersions)
        #expect(builds.actionID == .listBuilds)
        #expect(reviews.actionID == .listCustomerReviews)
    }

    @Test func parsesAPIKeyAddition() throws {
        let invocation = try CLIParser().parse([
            "accounts", "add",
            "--name", "Example Team",
            "--key-id", "KEY123",
            "--issuer-id", "ISSUER123",
            "--private-key-file", "/secure/AuthKey_KEY123.p8",
        ])

        #expect(invocation.actionID == .addAccount)
        #expect(invocation.executionContext.mode == .execute)
    }

    @Test func APIKeyAdditionRequiresTheExpectedOptions() {
        do {
            _ = try CLIParser().parse([
                "accounts", "add", "--name", "", "--key-id", "KEY123", "--private-key-file", "key.p8"
            ])
            Issue.record("Expected API key addition validation to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("'--name' must be a nonempty string"))
            #expect(error.message.contains("dab accounts add"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func parsesAPIKeyRemovalAsAGuardedWrite() throws {
        let invocation = try CLIParser().parse([
            "accounts", "remove", "--account-id", "ABCDEFGHIJ"
        ])

        #expect(invocation.actionID == .removeAccount)
        #expect(invocation.executionContext.mode == .execute)
    }

    @Test func parsesAPIKeyVerification() throws {
        let invocation = try CLIParser().parse([
            "accounts", "verify", "--account-id", "ABCDEFGHIJ"
        ])

        #expect(invocation.actionID == .verifyAccount)
    }

    @Test func defaultsEveryCurrentCommandToText() throws {
        let commands = try [
            CLIParser().parse(["accounts", "list"]),
            CLIParser().parse(["apps", "list", "--account-id", "account-1"]),
            CLIParser().parse(["apps", "get", "--account-id", "account-1", "--app-id", "app-1"]),
            CLIParser().parse(["builds", "list", "--account-id", "account-1", "--app-id", "app-1"]),
            CLIParser().parse(["reviews", "list", "--account-id", "account-1", "--app-id", "app-1"])
        ]

        #expect(commands.allSatisfy { $0.format == .text })
    }

    @Test func acceptsExplicitJsonAndReviewLimit() throws {
        let invocation = try CLIParser().parse([
            "reviews",
            "list",
            "--account-id",
            "account-1",
            "--app-id",
            "app-1",
            "--limit",
            "25",
            "--format",
            "json"
        ])

        #expect(invocation.actionID == .listCustomerReviews)
        #expect(invocation.format == .json)
    }

    @Test func acceptsVerboseOutputForEveryCommandShape() throws {
        let invocations = try [
            CLIParser().parse(["accounts", "list", "--verbose"]),
            CLIParser().parse(["apps", "list", "--account-id", "account-1", "--verbose"]),
            CLIParser().parse(["apps", "get", "--account-id", "account-1", "--app-id", "app-1", "--verbose"]),
            CLIParser().parse(["appVersion", "create", "--account-id", "account-1", "--app-id", "app-1", "--platform", "iOS", "--version", "2.0", "--verbose"]),
            CLIParser().parse(["builds", "list", "--account-id", "account-1", "--app-id", "app-1", "--verbose"]),
            CLIParser().parse(["reviews", "list", "--account-id", "account-1", "--app-id", "app-1", "--verbose"])
        ]

        #expect(invocations.map { $0.verbose } == [true, true, true, true, true, true])
    }

    @Test func parsesCreateVersionAtTheRootResourcePath() throws {
        let invocation = try CLIParser().parse([
            "appVersion", "create",
            "--account-id", "account-1",
            "--app-id", "app-1",
            "--platform", "iOS",
            "--version", "2.0",
        ])

        #expect(invocation.actionID == .createAppVersion)
        #expect(invocation.executionContext.mode == .execute)
    }

    @Test func parsesVersionAndReviewReadCommands() throws {
        let versionList = try CLIParser().parse([
            "appVersion", "list",
            "--account-id", "account-1", "--app-id", "app-1",
            "--platform", "iOS", "--platform", "macOS",
            "--state", "READY_FOR_DISTRIBUTION",
            "--version", "1.2.3", "--version-id", "version-1",
            "--limit", "25", "--format", "json"
        ])
        let versionGet = try CLIParser().parse([
            "appVersion", "get",
            "--account-id", "account-1", "--app-id", "app-1", "--version-id", "version-1"
        ])
        let reviewGet = try CLIParser().parse([
            "reviews", "get", "--account-id", "account-1", "--review-id", "review-1"
        ])

        #expect(versionList.actionID == .listAppVersions)
        #expect(versionList.format == .json)
        #expect(versionGet.actionID == .getAppVersion)
        #expect(reviewGet.actionID == .getCustomerReview)
    }

    @Test func versionListRejectsAnInvalidState() {
        do {
            _ = try CLIParser().parse([
                "appVersion", "list", "--account-id", "account-1", "--app-id", "app-1",
                "--state", "not-a-state"
            ])
            Issue.record("Expected state validation to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("dab appVersion list"))
            #expect(error.message.contains("--state"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func missingRequiredOptionIncludesCommandUsage() {
        do {
            _ = try CLIParser().parse(["apps", "get", "--app-id", "app-1"])
            Issue.record("Expected parsing to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("Missing expected argument '--account-id <account-id>'"))
            #expect(error.message.contains("dab apps get"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsReviewLimitOutsideDocumentedRange() {
        do {
            _ = try CLIParser().parse([
                "reviews",
                "list",
                "--account-id",
                "account-1",
                "--app-id",
                "app-1",
                "--limit",
                "201"
            ])
            Issue.record("Expected validation to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("must be from 1 through 200"))
            #expect(error.message.contains("dab reviews list"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func rejectsAnEmptyPaginationCursor() {
        do {
            _ = try CLIParser().parse([
                "apps", "list", "--account-id", "account-1", "--cursor", "", "--limit", "25"
            ])
            Issue.record("Expected validation to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("must be a nonempty pagination token"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func nestedHelpDescribesOnlyRelevantCommand() {
        do {
            _ = try CLIParser().parse(["reviews", "list", "--help"])
            Issue.record("Expected help request.")
        } catch let help as CLIHelpRequest {
            #expect(help.message.contains("USAGE: dab reviews list"))
            #expect(help.message.contains("--limit"))
            #expect(!help.message.contains("accounts list"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func APIKeyAdditionHelpDocumentsThePrivateKeyFile() {
        do {
            _ = try CLIParser().parse(["accounts", "add", "--help"])
            Issue.record("Expected help request.")
        } catch let help as CLIHelpRequest {
            #expect(help.message.contains("USAGE: dab accounts add"))
            #expect(help.message.contains("--private-key-file"))
            #expect(help.message.contains("--issuer-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func APIKeyRemovalHelpOmitsGuardedWriteOptions() {
        do {
            _ = try CLIParser().parse(["accounts", "remove", "--help"])
            Issue.record("Expected help request.")
        } catch let help as CLIHelpRequest {
            #expect(help.message.contains("USAGE: dab accounts remove"))
            #expect(help.message.contains("--account-id"))
            #expect(!help.message.contains("--confirm"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func APIKeyVerificationHelpDocumentsTheAccountIdentifier() {
        do {
            _ = try CLIParser().parse(["accounts", "verify", "--help"])
            Issue.record("Expected help request.")
        } catch let help as CLIHelpRequest {
            #expect(help.message.contains("USAGE: dab accounts verify"))
            #expect(help.message.contains("--account-id"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func createVersionHelpShowsTheFlatCommand() {
        do {
            _ = try CLIParser().parse(["appVersion", "create", "--help"])
            Issue.record("Expected help request.")
        } catch let help as CLIHelpRequest {
            #expect(help.message.contains("USAGE: dab appVersion create"))
            #expect(help.message.contains("--platform"))
            #expect(help.message.contains("--confirm"))
            #expect(help.message.contains("iOS, macOS, tvOS, or visionOS"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func genericAndNestedVersionPathsHaveNoCompatibilityAlias() {
        for resourcePath in [["versions"], ["apps", "versions"], ["apps", "appVersion"]] {
            do {
                _ = try CLIParser().parse(resourcePath + [
                    "create", "--account-id", "account-1", "--app-id", "app-1",
                    "--platform", "iOS", "--version", "2.0"
                ])
                Issue.record("Expected \(resourcePath) to be unavailable.")
            } catch is CLIUsageError {
                // The action catalog specifies a direct move with no compatibility alias.
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test func rejectsRawPlatformValueForCreateVersion() {
        do {
            _ = try CLIParser().parse([
                "appVersion", "create",
                "--account-id", "account-1",
                "--app-id", "app-1",
                "--platform", "IOS",
                "--version", "2.0",
            ])
            Issue.record("Expected parsing to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("iOS, macOS, tvOS, or visionOS"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func helpSubcommandMatchesNestedHelpFlag() {
        func helpMessage(for arguments: [String]) -> String? {
            do {
                _ = try CLIParser().parse(arguments)
                return nil
            } catch let help as CLIHelpRequest {
                return help.message
            } catch {
                return nil
            }
        }

        let flagHelp = helpMessage(for: ["apps", "get", "--help"])
        let subcommandHelp = helpMessage(for: ["help", "apps", "get"])
        let normalizedHelp = flagHelp?.split(whereSeparator: \.isWhitespace).joined(separator: " ")

        #expect(flagHelp == subcommandHelp)
        #expect(normalizedHelp?.contains("values: json, text; default: text") == true)
        #expect(normalizedHelp?.contains("Commit the exact preview") == false)
    }

    @Test func readCommandsRejectWriteExecutionOptions() {
        do {
            _ = try CLIParser().parse([
                "accounts", "list", "--confirm", "fingerprint"
            ])
            Issue.record("Expected parsing to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("Unknown option '--confirm'"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func previewUsesPreviewExecutionContext() throws {
        let invocation = try CLIParser().parse([
            "appVersion", "create",
            "--account-id", "account-1",
            "--app-id", "app-1",
            "--platform", "iOS",
            "--version", "2.0",
            "--preview",
        ])

        #expect(invocation.executionContext == .init(mode: .preview))
    }

    @Test func previewRejectsExplicitExecutionFlags() {
        do {
            _ = try CLIParser().parse([
                "appVersion", "create",
                "--account-id", "account-1",
                "--app-id", "app-1",
                "--platform", "iOS",
                "--version", "2.0",
                "--preview",
                "--confirm", "fingerprint",
                "--idempotency-key", "key",
            ])
            Issue.record("Expected parsing to fail.")
        } catch let error as CLIUsageError {
            #expect(error.message.contains("'--preview' cannot be combined"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private func sampleArguments(for entry: AutomationCLIAction) -> [String] {
    switch entry.id {
    case .listAccounts:
        entry.path
    case .addAccount:
        entry.path + [
            "--name", "Primary", "--key-id", "key-1", "--private-key-file", "/tmp/key.p8"
        ]
    case .removeAccount, .verifyAccount:
        entry.path + ["--account-id", "account-1"]
    case .listApps:
        entry.path + ["--account-id", "account-1"]
    case .getApp:
        entry.path + ["--account-id", "account-1", "--app-id", "app-1"]
    case .listAppVersions, .listBuilds, .listCustomerReviews:
        entry.path + ["--account-id", "account-1", "--app-id", "app-1"]
    case .getAppVersion:
        entry.path + ["--account-id", "account-1", "--app-id", "app-1", "--version-id", "version-1"]
    case .createAppVersion:
        entry.path + ["--account-id", "account-1", "--app-id", "app-1", "--platform", "iOS", "--version", "2.0"]
    case .getCustomerReview:
        entry.path + ["--account-id", "account-1", "--review-id", "review-1"]
    default:
        fatalError("Add typed CLI sample arguments for \(entry.id.rawValue).")
    }
}
