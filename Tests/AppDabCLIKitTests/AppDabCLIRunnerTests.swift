import AppDabAutomation
@testable import AppDabCLIKit
import AppDabKitTestSupport
import ConnectAccounts
import Foundation
import Testing

struct AppDabCLIRunnerTests {
    @Test func invalidArgumentsRespectJSONFormat() async throws {
        for format in [["--format", "json"], ["--format=json"]] {
            for arguments in [
                ["apps", "get"],
                ["reviews", "list", "--account-id", "a", "--app-id", "b", "--limit", "201"],
            ] {
                let result = await makeRunner().run(arguments: arguments + format)
                let json = try JSONSerialization.jsonObject(with: Data(result.standardError.utf8)) as? [String: [String: String]]
                #expect(result.exitCode == 2)
                #expect(result.standardOutput.isEmpty)
                #expect(json?["error"]?["code"] == "invalid_arguments")
            }
        }
    }

    @Test func typedWriteRendersNativeOutput() async {
        let provider = CreateVersionDataProvider()
        let runner = CLIRunner(
            executor: makeCreateVersionExecutor(provider: provider),
            interaction: TestCLIInteraction(responses: ["y"]),
        )
        let result = await runner.run(arguments: createVersionArguments())
        #expect(await provider.createAttempts == 1)
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Created Version"))
    }

    @Test func reconciliationFailureNamesReconciliation() async {
        let result = await makeRunner().run(arguments: createVersionArguments() + [
            "--confirm", "missing", "--idempotency-key", "missing", "--reconcile",
        ])
        #expect(result.standardError.hasPrefix("Could not reconcile the previous write."))
    }

    @Test func rendersAccountTableByDefault() async {
        let result = await makeRunner().run(arguments: ["accounts", "list"])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput == """
        Accounts (1)

        Name     Account ID
        Primary  account-1
        """)
        #expect(result.standardError.isEmpty)
    }

    @Test func APIKeyVerificationUsesTheSharedAutomationResponse() async {
        let result = await makeRunner().run(arguments: [
            "accounts", "verify", "--account-id", "account-1",
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput == "API key Primary is valid.\n\nAccount ID: account-1")
        #expect(result.standardError.isEmpty)
    }

    @Test func rendersAppTableWithUsefulIdentifiers() async {
        let result = await makeRunner().run(arguments: ["apps", "list", "--account-id", "account-1"])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Apps (1 of 1)"))
        #expect(result.standardOutput.contains("English (United States) (en-US)"))
        #expect(result.standardOutput.contains("app-1"))
    }

    @Test func rendersAppDetailsAndVersions() async {
        let result = await makeRunner().run(arguments: [
            "apps", "get", "--account-id", "account-1", "--app-id", "app-1",
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("AppDab\n\nApp ID:"))
        #expect(result.standardOutput.contains("Bundle ID:"))
        #expect(result.standardOutput.contains("Primary Locale:  English (United States) (en-US)"))
        #expect(result.standardOutput.contains("Content Rights:"))
        #expect(result.standardOutput.contains("Versions (1)"))
        #expect(result.standardOutput.contains("1.2.3    IOS       READY_FOR_SALE  1970-01-01T00:03:20Z  version-1"))
    }

    @Test func primaryLocaleTextKeepsUnknownIdentifiersReadable() {
        #expect(PrimaryLocaleTextFormatter.format("en-US") == "English (United States) (en-US)")
        #expect(PrimaryLocaleTextFormatter.format("xx-ZZ") == "xx-ZZ")
    }

    @Test func rendersReviewBodyAndResponseAsReadableBlocks() async {
        let result = await makeRunner().run(arguments: [
            "reviews", "list", "--account-id", "account-1", "--app-id", "app-1",
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Showing 1 of 1 review"))
        #expect(result.standardOutput.contains("★★★★★ 5/5  Great"))
        #expect(result.standardOutput.contains("Taylor · USA"))
        #expect(result.standardOutput.contains("Love it"))
        #expect(result.standardOutput.contains("Response (PUBLISHED)"))
        #expect(result.standardOutput.contains("Thank you!"))
        #expect(result.standardOutput.contains("response-1"))
    }

    @Test func readsAnAuthoritativeVersionInTextAndJSON() async throws {
        let arguments = [
            "appVersion", "get", "--account-id", "account-1",
            "--app-id", "app-1", "--version-id", "version-1",
        ]
        let text = await makeRunner().run(arguments: arguments)
        let json = await makeRunner().run(arguments: arguments + ["--format", "json"])
        let envelope = try JSONSerialization.jsonObject(with: Data(json.standardOutput.utf8)) as? [String: Any]
        let data = envelope?["data"] as? [String: Any]
        let version = data?["version"] as? [String: Any]

        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("Version\n\nVersion:"))
        #expect(text.standardOutput.contains("Version ID:"))
        #expect(text.standardOutput.contains("version-1"))
        #expect(json.exitCode == 0)
        #expect(envelope?["action"] as? String == "get_app_version")
        #expect(version?["versionID"] as? String == "version-1")
    }

    @Test func listsVersionsWithIdentifiersAndAnEmptyState() async {
        let arguments = ["appVersion", "list", "--account-id", "account-1", "--app-id", "app-1"]
        let populated = await makeRunner().run(arguments: arguments)
        let empty = await makeRunner(dataProvider: .init(returnsEmptyCollections: true)).run(arguments: arguments)

        #expect(populated.exitCode == 0)
        #expect(populated.standardOutput.contains("Versions (1 of 1)"))
        #expect(populated.standardOutput.contains("1.2.3"))
        #expect(populated.standardOutput.contains("version-1"))
        #expect(empty.exitCode == 0)
        #expect(empty.standardOutput.contains("No versions found."))
    }

    @Test func listsBuildsInTextAndSharedJsonWithoutChangingTheAppScope() async throws {
        let arguments = ["builds", "list", "--account-id", "account-1", "--app-id", "app-1"]
        let text = await makeRunner().run(arguments: arguments)
        let json = await makeRunner().run(arguments: arguments + ["--format", "json"])
        let empty = await makeRunner(dataProvider: .init(returnsEmptyCollections: true)).run(arguments: arguments)
        let envelope = try JSONSerialization.jsonObject(with: Data(json.standardOutput.utf8)) as? [String: Any]
        let data = envelope?["data"] as? [String: Any]
        let builds = data?["builds"] as? [[String: Any]]

        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("Builds (1 of 1)"))
        #expect(text.standardOutput.contains("build-1"))
        #expect(json.exitCode == 0)
        #expect(envelope?["action"] as? String == "list_builds")
        #expect(data?["appID"] as? String == "app-1")
        #expect(builds?.first?["buildID"] as? String == "build-1")
        #expect(empty.standardOutput.contains("No builds found."))
    }

    @Test func readsOneBuildInTextAndSharedJSON() async throws {
        let arguments = ["builds", "get", "--account-id", "account-1", "--build-id", "build-1"]
        let text = await makeRunner().run(arguments: arguments)
        let json = await makeRunner().run(arguments: arguments + ["--format", "json"])
        let envelope = try JSONSerialization.jsonObject(with: Data(json.standardOutput.utf8)) as? [String: Any]
        let data = envelope?["data"] as? [String: Any]
        let build = data?["build"] as? [String: Any]

        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("Build"))
        #expect(text.standardOutput.contains("42"))
        #expect(text.standardOutput.contains("build-1"))
        #expect(json.exitCode == 0)
        #expect(envelope?["action"] as? String == "get_build")
        #expect(build?["buildID"] as? String == "build-1")
    }

    @Test func readsAReviewWithItsPublishedResponse() async throws {
        let arguments = ["reviews", "get", "--account-id", "account-1", "--review-id", "review-1"]
        let text = await makeRunner().run(arguments: arguments)
        let json = await makeRunner().run(arguments: arguments + ["--format", "json"])
        let envelope = try JSONSerialization.jsonObject(with: Data(json.standardOutput.utf8)) as? [String: Any]
        let data = envelope?["data"] as? [String: Any]
        let review = data?["review"] as? [String: Any]

        #expect(text.exitCode == 0)
        #expect(text.standardOutput.contains("Love it"))
        #expect(text.standardOutput.contains("Thank you!"))
        #expect(json.exitCode == 0)
        #expect(envelope?["action"] as? String == "get_customer_review")
        #expect(review?["reviewID"] as? String == "review-1")
    }

    @Test func rendersACopyableContinuationCommand() async {
        let result = await makeRunner().run(arguments: [
            "reviews", "list", "--account-id", "account-1", "--app-id", "app-1", "--limit", "1",
        ])

        #expect(result.standardOutput.contains("""
        Next page command:
        dab reviews list \\
          --account-id account-1 \\
          --app-id app-1 \\
          --cursor next-review \\
          --limit 1
        """))
    }

    @Test func rendersClearEmptyState() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(returnsEmptyCollections: true))

        let result = await runner.run(arguments: ["accounts", "list"])

        #expect(result.standardOutput == "Accounts (0)\n\nNo accounts found. Add one with `dab accounts add`, then run this command again.")
    }

    @Test func includesTheAppContinuationCursorInJsonOutput() async throws {
        let result = await makeRunner().run(arguments: [
            "apps", "list", "--account-id", "account-1", "--limit", "1", "--format", "json",
        ])
        let json = try JSONSerialization.jsonObject(with: Data(result.standardOutput.utf8)) as? [String: Any]
        let data = json?["data"] as? [String: Any]

        let apps = data?["apps"] as? [[String: Any]]
        #expect(apps?.first?["primaryLocale"] as? String == "en-US")
        let pagination = data?["pagination"] as? [String: Any]
        #expect(pagination?["nextCursor"] as? String == "next-app")
    }

    @Test func preservesExplicitJsonOutput() async {
        let result = await makeRunner().run(arguments: ["accounts", "list", "--format", "json"])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("\"accounts\""))
        #expect(result.standardOutput.contains("\"accountID\""))
        #expect(!result.standardOutput.contains("Accounts (1)"))
    }

    @Test func previewsCreateVersionInTheDefaultTextFormat() async {
        let result = await makePreviewRunner().run(arguments: [
            "appVersion", "create",
            "--account-id", "account-1",
            "--app-id", "app-1",
            "--platform", "iOS",
            "--version", "2.0",
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Preview"))
        #expect(result.standardOutput.contains("Create version 2.0 for iOS on AppDab."))
        #expect(result.standardOutput.contains("Confirmation fingerprint:"))
        #expect(result.standardOutput.contains("No changes have been made."))
        #expect(result.standardOutput.contains("Commit command:"))
        #expect(result.standardOutput.contains("--idempotency-key preview-key"))
    }

    @Test func interactiveConfirmationCommitsThePreviewedVersion() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: [" yes "])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments())

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Created Version"))
        #expect(await provider.createAttempts == 1)
        #expect(interaction.standardError.contains("Create version 2.0 for iOS on AppDab."))
        #expect(interaction.standardError.contains("Proceed? [y/N]"))
    }

    @Test func rejectedInteractiveConfirmationDoesNotCreateTheVersion() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["no"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments())

        #expect(result == .init(exitCode: 0, standardOutput: "Cancelled. No changes made."))
        #expect(await provider.createAttempts == 0)
    }

    @Test func endOfInputCancelsInteractiveConfirmation() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction()
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments())

        #expect(result == .init(exitCode: 0, standardOutput: "Cancelled. No changes made."))
        #expect(await provider.createAttempts == 0)
    }

    @Test func invalidInteractiveConfirmationRepeatsThePrompt() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["perhaps", "y"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        _ = await runner.run(arguments: createVersionArguments())

        #expect(interaction.standardError.contains("Please enter y or n."))
        #expect(interaction.standardError.components(separatedBy: "Proceed? [y/N]").count == 3)
        #expect(await provider.createAttempts == 1)
    }

    @Test func noninteractiveAndJSONWritesRemainPreviews() async {
        let noninteractiveProvider = CreateVersionDataProvider()
        let noninteractive = TestCLIInteraction(isInteractive: false, responses: ["y"])
        let noninteractiveRunner = makeInteractiveRunner(
            provider: noninteractiveProvider,
            interaction: noninteractive,
        )
        let jsonProvider = CreateVersionDataProvider()
        let jsonInteraction = TestCLIInteraction(responses: ["y"])
        let jsonRunner = makeInteractiveRunner(provider: jsonProvider, interaction: jsonInteraction)

        let noninteractiveResult = await noninteractiveRunner.run(arguments: createVersionArguments())
        let jsonResult = await jsonRunner.run(arguments: createVersionArguments() + ["--format", "json"])

        #expect(noninteractiveResult.standardOutput.contains("Preview"))
        #expect(jsonResult.standardOutput.contains("\"plan\""))
        #expect(noninteractive.standardError.isEmpty)
        #expect(jsonInteraction.standardError.isEmpty)
        #expect(await noninteractiveProvider.createAttempts == 0)
        #expect(await jsonProvider.createAttempts == 0)
    }

    @Test func explicitPreviewDoesNotPrompt() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments() + ["--preview"])

        #expect(result.standardOutput.contains("Preview"))
        #expect(interaction.standardError.isEmpty)
        #expect(await provider.createAttempts == 0)
    }

    @Test func expiredInteractivePreviewDoesNotCreateTheVersion() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = makeInteractiveRunner(
            provider: provider,
            interaction: interaction,
            previewLifetime: 0,
        )

        let result = await runner.run(arguments: createVersionArguments())

        #expect(result.exitCode == 1)
        #expect(result.standardError.contains("preview has expired"))
        #expect(!result.standardError.contains("preview_expired"))
        #expect(await provider.createAttempts == 0)
    }

    @Test func interactiveConfirmationPrintsAReadableSafelyQuotedRecoveryCommand() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)
        let arguments = createVersionArguments(version: "2.0'; echo unexpected")

        _ = await runner.run(arguments: arguments)

        #expect(interaction.standardError.contains("Recovery command, if the outcome is indeterminate:"))
        #expect(interaction.standardError.contains("appVersion create \\"))
        #expect(interaction.standardError.contains("  --confirm "))
        #expect(interaction.standardError.contains("  --idempotency-key interactive-key \\"))
        #expect(interaction.standardError.contains("  --reconcile"))
        #expect(interaction.standardError.contains(#"'2.0'"'"'; echo unexpected'"#))
        #expect(await provider.createAttempts == 1)
    }

    @Test func indeterminateInteractiveWriteExplainsHowToRecover() async {
        let provider = CreateVersionDataProvider(failure: .afterCreating)
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments())

        #expect(result.exitCode == 1)
        #expect(result.standardError.contains("The write may have succeeded."))
        #expect(!result.standardError.contains("indeterminate_outcome"))
        #expect(interaction.standardError.contains("Recovery command, if the outcome is indeterminate:"))
        #expect(interaction.standardError.contains("Run the recovery command above before retrying."))
        #expect(await provider.createAttempts == 1)
    }

    @Test func explicitIndeterminateWritePrintsAReconciliationCommand() async throws {
        let provider = CreateVersionDataProvider(failure: .afterCreating)
        let executor = makeCreateVersionExecutor(provider: provider)
        let arguments = createVersionArguments()
        let input = try CreateAppVersionInput(
            accountID: "account-1", appID: "app-1",
            platform: #require(PlatformArgument(argument: "iOS")).value, version: "2.0",
        )
        let plan = try await executor.preview(CreateAppVersionAction.self, input: input)
        let runner = CLIRunner(executor: executor)

        let result = await runner.run(arguments: arguments + [
            "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "recover-key",
        ])

        #expect(result.exitCode == 1)
        #expect(result.standardError.contains("Could not create version 2.0 for iOS."))
        #expect(result.standardError.contains("The write may have succeeded."))
        #expect(result.standardError.contains("Recovery command:"))
        #expect(result.standardError.contains("--confirm \(plan.confirmationFingerprint)"))
        #expect(result.standardError.contains("--idempotency-key recover-key"))
        #expect(result.standardError.contains("  --reconcile"))
    }

    @Test func typedCommitProducesJSONReceiptAndReplaysWithoutAnotherMutation() async throws {
        let provider = CreateVersionDataProvider()
        let executor = makeCreateVersionExecutor(provider: provider)
        let input = try CreateAppVersionInput(
            accountID: "account-1", appID: "app-1",
            platform: #require(PlatformArgument(argument: "iOS")).value, version: "2.0",
        )
        let plan = try await executor.preview(CreateAppVersionAction.self, input: input)
        let runner = CLIRunner(executor: executor)
        let arguments = createVersionArguments() + [
            "--format", "json", "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "json-commit-key",
        ]

        let first = await runner.run(arguments: arguments)
        let replay = await runner.run(arguments: arguments)
        let json = try #require(JSONSerialization.jsonObject(with: Data(first.standardOutput.utf8)) as? [String: Any])

        #expect(first.exitCode == 0)
        #expect(replay.exitCode == 0)
        #expect(json["receipt"] != nil)
        #expect((json["data"] as? [String: [String: Any]])?["version"]?["version"] as? String == "2.0")
        #expect(await provider.createAttempts == 1)
    }

    @Test func reconciliationWithoutAMutationRendersItsSummary() async throws {
        let provider = CreateVersionDataProvider(failure: .beforeCreating)
        let executor = makeCreateVersionExecutor(provider: provider)
        let arguments = createVersionArguments()
        let input = try CreateAppVersionInput(
            accountID: "account-1", appID: "app-1",
            platform: #require(PlatformArgument(argument: "iOS")).value, version: "2.0",
        )
        let plan = try await executor.preview(CreateAppVersionAction.self, input: input)
        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await executor.commitResult(
                CreateAppVersionAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: "reconcile-key",
            )
        }
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = CLIRunner(executor: executor, interaction: interaction)

        let result = await runner.run(arguments: arguments + [
            "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "reconcile-key",
            "--reconcile",
        ])

        #expect(result == .init(
            exitCode: 0,
            standardOutput: "Reconciliation confirmed that no mutation was applied.",
        ))
        #expect(interaction.standardError.isEmpty)
        #expect(await provider.createAttempts == 0)
    }

    @Test func reconciliationRendersTheNativeVersionAfterAResponseIsLost() async throws {
        let provider = CreateVersionDataProvider(failure: .afterCreating)
        let executor = makeCreateVersionExecutor(provider: provider)
        let input = try CreateAppVersionInput(
            accountID: "account-1", appID: "app-1",
            platform: #require(PlatformArgument(argument: "iOS")).value, version: "2.0",
        )
        let plan = try await executor.preview(CreateAppVersionAction.self, input: input)
        await #expect(throws: AutomationExecutionError.indeterminate) {
            try await executor.commitResult(
                CreateAppVersionAction.self, input: input,
                confirmationFingerprint: plan.confirmationFingerprint,
                idempotencyKey: "lost-response-key",
            )
        }

        let result = await CLIRunner(executor: executor).run(arguments: createVersionArguments() + [
            "--confirm", plan.confirmationFingerprint,
            "--idempotency-key", "lost-response-key",
            "--reconcile",
        ])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("Created Version"))
        #expect(result.standardOutput.contains("2.0"))
        #expect(await provider.createAttempts == 1)
    }

    @Test func explicitCommitDoesNotPrompt() async {
        let provider = CreateVersionDataProvider()
        let interaction = TestCLIInteraction(responses: ["y"])
        let runner = makeInteractiveRunner(provider: provider, interaction: interaction)

        let result = await runner.run(arguments: createVersionArguments() + [
            "--confirm", "unknown",
            "--idempotency-key", "key",
        ])

        #expect(result.exitCode == 1)
        #expect(interaction.standardError.isEmpty)
        #expect(await provider.createAttempts == 0)
    }

    @Test func returnsCommandSpecificUsageWithExitCodeTwo() async {
        let result = await makeRunner().run(arguments: ["apps", "get", "--app-id", "app-1"])

        #expect(result.exitCode == 2)
        #expect(result.standardError.contains("Missing expected argument '--account-id <account-id>'"))
        #expect(result.standardError.contains("Usage: dab apps get"))
    }

    @Test func displaysTopLevelHelpForNoArguments() async {
        let result = await makeRunner().run(arguments: [])

        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("USAGE: dab <subcommand>"))
        #expect(result.standardOutput.contains("accounts"))
        #expect(result.standardOutput.contains("apps"))
        #expect(result.standardError.isEmpty)
    }

    @Test func rendersCompactActionableTextErrorsByDefault() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .accountNotFound("missing")))

        let result = await runner.run(arguments: ["apps", "list", "--account-id", "missing"])

        #expect(result.exitCode == 1)
        #expect(result.standardError == "Could not list apps.\n\nCould not find account missing.")
    }

    @Test func rendersNetworkGuidanceAndVerboseDiagnostics() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .network("The Internet connection appears to be offline.")))

        let compactResult = await runner.run(arguments: ["apps", "list", "--account-id", "account-1"])
        let verboseResult = await runner.run(arguments: ["apps", "list", "--account-id", "account-1", "--verbose"])

        #expect(compactResult.standardError == "Could not list apps.\n\nApp Store Connect could not be reached. Check your Internet connection and try again.")
        #expect(!compactResult.standardError.contains("network_error"))
        #expect(verboseResult.standardError.contains("Code: network_error"))
        #expect(verboseResult.standardError.contains("Diagnostic: The Internet connection appears to be offline."))
    }

    @Test func rendersSeparateAuthenticationAndPermissionGuidance() async {
        let authenticationRunner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .authentication("HTTP status code 401")))
        let permissionRunner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .permissionDenied("HTTP status code 403")))

        let authenticationResult = await authenticationRunner.run(arguments: ["apps", "list", "--account-id", "account-1"])
        let permissionResult = await permissionRunner.run(arguments: ["apps", "list", "--account-id", "account-1"])

        #expect(authenticationResult.standardError.contains("Sign in again or check your App Store Connect credentials."))
        #expect(permissionResult.standardError.contains("does not have access to perform this action."))
    }

    @Test func preservesStableJsonServiceErrorsWhenRequested() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .accountNotFound("missing")))

        let result = await runner.run(arguments: [
            "apps", "list", "--account-id", "missing", "--format", "json",
        ])

        #expect(result.exitCode == 1)
        #expect(result.standardError.contains("\"code\" : \"account_not_found\""))
        #expect(result.standardError.contains("\"message\" : \"Could not find account missing.\""))
    }

    @Test func preservesStructuredErrorEnvelopeWhenVerboseJsonIsRequested() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .network("Timed out")))

        let result = await runner.run(arguments: [
            "apps", "list", "--account-id", "account-1", "--format", "json", "--verbose",
        ])

        #expect(result.exitCode == 1)
        #expect(result.standardOutput.isEmpty)
        #expect(result.standardError.contains("\"code\" : \"network_error\""))
        #expect(result.standardError.contains("\"message\" : \"Timed out\""))
        #expect(!result.standardError.contains("Diagnostic:"))
    }

    @Test func preservesJsonServiceErrorsForEqualsFormatSyntax() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(appError: .accountNotFound("missing")))

        let result = await runner.run(arguments: [
            "apps", "list", "--account-id", "missing", "--format=json",
        ])

        #expect(result.exitCode == 1)
        #expect(result.standardError.contains("\"code\" : \"account_not_found\""))
    }

    @Test func keepsOutOfRangeReviewRatingsConsistentWithRenderedStars() async {
        let runner = makeRunner(dataProvider: MockAutomationDataProvider(reviewRating: 6))

        let result = await runner.run(arguments: [
            "reviews", "list", "--account-id", "account-1", "--app-id", "app-1",
        ])

        #expect(result.standardOutput.contains("★★★★★ 5/5  Great"))
        #expect(!result.standardOutput.contains("6/5"))
    }

    @Test func addsAnsiStylingOnlyForEligibleTerminal() async {
        let richRunner = makeRunner(outputCapabilities: .init(
            standardOutputIsTerminal: true,
            standardErrorIsTerminal: true,
            environment: ["TERM": "xterm-256color"],
        ))
        let noColorRunner = makeRunner(outputCapabilities: .init(
            standardOutputIsTerminal: true,
            standardErrorIsTerminal: true,
            environment: ["TERM": "xterm-256color", "NO_COLOR": ""],
        ))

        let richResult = await richRunner.run(arguments: ["accounts", "list"])
        let noColorResult = await noColorRunner.run(arguments: ["accounts", "list"])

        #expect(richResult.standardOutput.contains("\u{001B}[1;36mAccounts (1)\u{001B}[0m"))
        #expect(!noColorResult.standardOutput.contains("\u{001B}"))
        #expect(noColorResult.standardOutput == "Accounts (1)\n\nName     Account ID\nPrimary  account-1")
    }

    @Test func jsonOutputUsesSharedResponseEnvelope() async {
        let result = await makeRunner().run(arguments: ["accounts", "list", "--format", "json"])

        #expect(result.standardOutput.contains("\"action\" : \"list_accounts\""))
        #expect(result.standardOutput.contains("\"summary\" : \"Found 1 accounts.\""))
        #expect(result.standardOutput.contains("\"data\""))
    }

    private func makeRunner(
        dataProvider: MockAutomationDataProvider = .init(),
        outputCapabilities: CLIOutputCapabilities = .plain,
    ) -> CLIRunner {
        CLIRunner(
            executor: Executor(dataProvider: dataProvider),
            outputCapabilities: outputCapabilities,
        )
    }

    private func makePreviewRunner() -> CLIRunner {
        let auditStore = AutomationSQLiteAuditStore(
            databaseURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("AppDabCLIPreviewTests-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("audit.sqlite"),
        )
        return .init(
            executor: Executor(dataProvider: MockAutomationDataProvider(), auditStore: auditStore),
            makeIdempotencyKey: { "preview-key" },
        )
    }

    private func makeInteractiveRunner(
        provider: CreateVersionDataProvider,
        interaction: TestCLIInteraction,
        previewLifetime: TimeInterval = 600,
    ) -> CLIRunner {
        let executor = makeCreateVersionExecutor(
            provider: provider,
            previewLifetime: previewLifetime,
        )
        return .init(
            executor: executor,
            interaction: interaction,
            makeIdempotencyKey: { "interactive-key" },
        )
    }

    private func makeCreateVersionExecutor(
        provider: CreateVersionDataProvider,
        previewLifetime: TimeInterval = 600,
    ) -> Executor {
        .init(
            dataProvider: provider,
            auditStore: AutomationSQLiteAuditStore(databaseURL: temporaryDatabaseURL()),
            previewLifetime: previewLifetime,
            now: { Date(timeIntervalSince1970: 1000) },
            makePlanID: { "interactive-plan" },
        )
    }

    private func createVersionArguments(version: String = "2.0") -> [String] {
        [
            "appVersion", "create",
            "--account-id", "account-1",
            "--app-id", "app-1",
            "--platform", "iOS",
            "--version", version,
        ]
    }

    private func temporaryDatabaseURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("AppDabCLIRunnerTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("audit.sqlite")
    }
}

private let testAPIKeyPrivateKey = """
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgXLIb52lZvzsMngXL
0EJWPAa5MyFmpzcoNOAzaYE2jrOhRANCAARR/+DkLl1GciqakguB9lmOrtqOwgG9
RQ9q7R8H5CAqcwN5PKnG/2xVsNjWb+dRGTzZU/SIivE146uLT6d+G61j
-----END PRIVATE KEY-----
"""
