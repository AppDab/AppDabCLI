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
## Beta build localization

Update a build localization's What to Test text with its localization identifier:

```sh
dab betaBuildLocalizations update --account-id ACCOUNT_ID --localization-id LOCALIZATION_ID --whats-new "Test the new flow"
```
## Beta app testing settings

Use `betaAppTesting` for app level TestFlight localizations, review details, and the license agreement:

```sh
dab betaAppTesting listLocalizations --account-id ACCOUNT_ID --app-id APP_ID
dab betaAppTesting createLocalization --account-id ACCOUNT_ID --app-id APP_ID --locale en-US
dab betaAppTesting updateLocalization --account-id ACCOUNT_ID --app-id APP_ID --localization-id LOCALIZATION_ID \
  --description "Try the new flow" --feedback-email beta@example.com \
  --marketing-url https://example.com --privacy-policy-url https://example.com/privacy \
  --tvos-privacy-policy "Privacy policy text"
dab betaAppTesting deleteLocalization --account-id ACCOUNT_ID --app-id APP_ID --localization-id LOCALIZATION_ID
dab betaAppTesting getReviewDetail --account-id ACCOUNT_ID --app-id APP_ID
dab betaAppTesting updateReviewDetail --help
dab betaAppTesting getLicenseAgreement --account-id ACCOUNT_ID --app-id APP_ID
dab betaAppTesting updateLicenseAgreement --account-id ACCOUNT_ID --app-id APP_ID --agreement-text "Terms"
```

The localization and review detail updates require their complete field sets. Use `--help` on either update command to see every required option.

The AppDab built in CLI uses AppDab’s shared Keychain account store instead. Both CLI variants run the same `AppDabAutomation` actions through `AppDabCLIKit`.

## Screenshots and app previews

Manage screenshots and Apple's [app previews](https://developer.apple.com/app-store/app-previews/) for an existing App Store version localization using `screenshots` and `appPreviews`. Start with `list` to see placement IDs, processing states, valid placement groups, and Apple's media requirements.

```sh
dab screenshots list --account-id ACCOUNT --version-id VERSION --locale en-US
dab screenshots get --account-id ACCOUNT --version-id VERSION --locale en-US --placement-id PLACEMENT
dab screenshots upload --account-id ACCOUNT --version-id VERSION --locale en-US --placement-group GROUP --file ./screen.png --preview
dab appPreviews upload --account-id ACCOUNT --version-id VERSION --locale en-US --placement-group GROUP --file ./preview.mov --preview-frame-time-code 00:00:01:00 --wait --timeout 300 --preview
dab screenshots download --account-id ACCOUNT --version-id VERSION --locale en-US --placement-id PLACEMENT --destination ./download.png --preview
dab screenshots remove --account-id ACCOUNT --version-id VERSION --locale en-US --placement-id PLACEMENT --preview
dab screenshots reorder --account-id ACCOUNT --version-id VERSION --locale en-US --placement-group GROUP --placement-ids SECOND FIRST THIRD --preview
```

The same six commands are available for `appPreviews`. Add `--format json` for structured output. `list` accepts an optional `--placement-group` filter. Ordering requires every placement in that group exactly once. Removal detaches a placement without deleting the underlying reusable asset. Downloads require a new destination file and fail if Apple has not yet supplied downloadable media. Apple may provide an HLS playlist for an app preview; use a `.m3u8` destination in that case. The playlist streams from Apple and requires Internet access for playback.

Writes show a preview. To commit, repeat the exact command without `--preview`, adding `--confirm FINGERPRINT --idempotency-key UNIQUE_KEY` from the preview. Interactive text sessions can confirm directly. Upload normally finishes after transfer completion and placement creation; `--wait` also waits for processing and, for app previews, download availability, up to `--timeout` seconds.

If an upload is interrupted, repeat the original command with the same confirmation fingerprint and idempotency key and add `--reconcile`. Durable checkpoints resume a known asset and reconcile placement creation. A crash or lost response before the asset ID was recorded remains unresolved to avoid duplicate uploads. Inspect App Store Connect before starting a new operation in that case. Failed uploads never automatically delete assets. Keep the original local file unchanged until recovery finishes.

For example, recover an interrupted preview upload using the same options, fingerprint, and key as the original commit:

```sh
dab appPreviews upload --account-id ACCOUNT --version-id VERSION --locale en-US --placement-group GROUP --file ./preview.mov --preview-frame-time-code 00:00:01:00 --wait --timeout 300 --confirm FINGERPRINT --idempotency-key UPLOAD_KEY --reconcile
```

Successful download replay verifies the destination file's size and SHA256 fingerprint. If it is missing or changed, the replay reports an error instead of claiming the file is still present.
