# dab

`dab` is the command line interface for App Store Connect automation built on AppDabKit.

Contributors adding a CLI command for an AppDabKit action should follow [Adding a Typed CLI Command](Documentation/AddingCLICommand.md). Each CLI command uses named options and a typed action input.

## Build and test

```sh
swift build
swift test
swift run dab --help
```

## Accounts

The standalone CLI stores App Store Connect API keys in the user's macOS login Keychain under its own `AppDabCLI` service. These credentials stay local to this Mac rather than syncing through iCloud Keychain. The CLI does not require AppDab, an app group entitlement, or an AppDab signing certificate, including when launched with `swift run`.

Add an API key from its downloaded `.p8` file:

```sh
swift run dab accounts add \
  --name "Example Team" \
  --key-id KEY_ID \
  --issuer-id ISSUER_ID \
  --private-key-file /path/to/AuthKey_KEY_ID.p8
```

Then list accounts and apps:

```sh
swift run dab accounts list
swift run dab apps list --account-id ACCOUNT_ID
```

Read versions and reviews with either text or `--format json` output:

```sh
swift run dab appVersion list --account-id ACCOUNT_ID --app-id APP_ID
swift run dab appVersion list --account-id ACCOUNT_ID --app-id APP_ID --platform iOS --limit 25
swift run dab appVersion get --account-id ACCOUNT_ID --app-id APP_ID --version-id VERSION_ID
swift run dab reviews get --account-id ACCOUNT_ID --review-id REVIEW_ID
```

Version list filters (`--platform`, `--state`, `--version`, and `--version-id`) can be repeated. State values use App Store Connect names such as `READY_FOR_DISTRIBUTION`. List output includes a next page command when more results are available.

Mutation previews and audit records are stored in `~/Library/Application Support/AppDabCLI/dab-audit.sqlite`.

## Beta groups and TestFlight writes

List beta groups for an app or inspect one group:

```sh
dab betaGroups list --account-id ACCOUNT_ID --app-id APP_ID
dab betaGroups get --account-id ACCOUNT_ID --beta-group-id GROUP_ID
```

These commands use guarded previews. In an interactive terminal, `dab` asks for confirmation. In scripts, run with `--preview`, then use the displayed `--confirm` fingerprint and a unique `--idempotency-key` to commit. If the outcome is uncertain, repeat the command with `--reconcile` and the same fingerprint and key.

```sh
dab builds addTester --account-id ACCOUNT_ID --build-id BUILD_ID --tester-id TESTER_ID
dab builds removeTester --account-id ACCOUNT_ID --build-id BUILD_ID --tester-id TESTER_ID
dab builds addBetaGroup --account-id ACCOUNT_ID --build-id BUILD_ID --beta-group-id GROUP_ID
dab builds removeBetaGroup --account-id ACCOUNT_ID --build-id BUILD_ID --beta-group-id GROUP_ID
dab builds submitForBetaReview --account-id ACCOUNT_ID --build-id BUILD_ID --no-auto-notify
dab builds expire --account-id ACCOUNT_ID --build-id BUILD_ID
dab betaGroups create --account-id ACCOUNT_ID --app-id APP_ID --name "Early Access" --internal
dab betaGroups update --account-id ACCOUNT_ID --beta-group-id GROUP_ID --feedback-enabled false
dab betaGroups addBuild --account-id ACCOUNT_ID --beta-group-id GROUP_ID --build-id BUILD_ID
dab betaGroups removeBuild --account-id ACCOUNT_ID --beta-group-id GROUP_ID --build-id BUILD_ID
dab betaGroups addTester --account-id ACCOUNT_ID --beta-group-id GROUP_ID --tester-id TESTER_ID
dab betaGroups removeTester --account-id ACCOUNT_ID --beta-group-id GROUP_ID --tester-id TESTER_ID
dab betaGroups delete --account-id ACCOUNT_ID --beta-group-id GROUP_ID
```

Beta review submission enables automatic tester notification by default. Use `--no-auto-notify` to disable it.

## Beta tester invitations

Choose one scope when listing testers and one destination when inviting them:

```sh
dab betaTesters list --account-id ACCOUNT_ID --app-id APP_ID
dab betaTesters list --account-id ACCOUNT_ID --beta-group-id GROUP_ID
dab betaTesters invite --account-id ACCOUNT_ID --email tester@example.com --beta-group-id GROUP_ID
dab betaTesters sendInvitation --account-id ACCOUNT_ID --app-id APP_ID --tester-id TESTER_ID
```

## Build export compliance

Provide every compliance answer explicitly. When documents are required, include the purpose and a PDF or ZIP path:

```sh
dab builds setExportCompliance --account-id ACCOUNT_ID --app-id APP_ID --build-id BUILD_ID \
  --needs-documents true --available-on-french-store true \
  --contains-proprietary-cryptography false --contains-third-party-cryptography true \
  --purpose "Encryption for account security" --document-path ./compliance.pdf
```

The AppDab built in CLI uses AppDab’s shared Keychain account store instead. Both CLI variants run the same `AppDabAutomation` actions through `AppDabCLIKit`.
