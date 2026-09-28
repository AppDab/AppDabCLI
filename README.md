# dab

`dab` is the command line interface for App Store Connect automation built on AppDabKit.

## Build and test

```sh
swift build
swift test
swift run dab --help
```

## Accounts

The standalone CLI stores App Store Connect API keys in the user’s Keychain under its own `AppDabCLI` service. It does not require AppDab, an app group entitlement, or an AppDab signing certificate.

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
swift run dab apps versions list --account-id ACCOUNT_ID --app-id APP_ID
swift run dab apps versions list --account-id ACCOUNT_ID --app-id APP_ID --platform iOS --limit 25
swift run dab apps versions get --account-id ACCOUNT_ID --app-id APP_ID --version-id VERSION_ID
swift run dab reviews get --account-id ACCOUNT_ID --review-id REVIEW_ID
```

Version list filters (`--platform`, `--state`, `--version`, and `--version-id`) can be repeated. State values use App Store Connect names such as `READY_FOR_DISTRIBUTION`. List output includes a next page command when more results are available.

Mutation previews and audit records are stored in `~/Library/Application Support/AppDabCLI/dab-audit.sqlite`.

The AppDab built in CLI uses AppDab’s shared Keychain account store instead. Both CLI variants run the same `AppDabAutomation` actions through `AppDabCLIKit`.
