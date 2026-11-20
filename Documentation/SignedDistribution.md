# Signed CLI releases

## Setup

Use the AppDab team's Developer ID Application signing identity and a Developer ID provisioning profile for `app.AppDab.AppDabCLI` that authorizes the shared Keychain group `R7YA4RGA8U.app.AppDab.AppDab`.

Store notarization credentials once:

```sh
xcrun notarytool store-credentials appdab-release
```

## Build and verify locally

Run from the repository root with Xcode selected. Replace the version, signing identity, and profile path as needed.

```sh
swift test --force-resolved-versions
scripts/test_distribution.sh

scripts/package_cli.sh \
  --version 1.0.0 \
  --identity 'Developer ID Application: YOUR NAME (R7YA4RGA8U)' \
  --profile /path/to/AppDabCLI_Developer_ID.provisionprofile \
  --output /tmp/appdab-cli-release \
  --notary-profile appdab-release

scripts/verify_keychain_access.sh \
  --app /tmp/appdab-cli-release/AppDabCLI-1.0.0/AppDabCLI.app

scripts/generate_homebrew_cask.sh \
  --version 1.0.0 \
  --archive /tmp/appdab-cli-release/AppDabCLI-1.0.0.zip \
  --output /tmp/appdab-cli-release/appdab-cli.rb
```

The package command builds both architectures, signs, notarizes, and creates the ZIP and checksum. Use a fresh output directory for each attempt. Keychain verification requires an account configured in AppDab; add `--previous-app /path/to/older/AppDabCLI.app` to check access across versions.

## Build with GitHub Actions

Publishing a GitHub release with a tag such as `v1.0.0` starts **Release**. It builds, signs, and notarizes the CLI, then attaches the ZIP and checksum to that release. After the upload succeeds, the workflow uses the generated cask from the workflow artifact to open a pull request in `AppDab/homebrew-tap`.

For a candidate build, run the same workflow manually from the Actions tab with a version such as `1.0.0`. Download the files from the workflow artifacts.

Required repository secrets:

| Secret | Value |
| --- | --- |
| `APPDAB_DEVELOPER_ID_P12_BASE64` | Base64 encoded signing certificate and private key export |
| `APPDAB_DEVELOPER_ID_P12_PASSWORD` | Export password |
| `APPDAB_DEVELOPER_ID_IDENTITY` | Signing identity name or certificate SHA1 |
| `APPDAB_CLI_DEVELOPER_ID_PROFILE_BASE64` | Base64 encoded Developer ID provisioning profile |
| `APPDAB_NOTARY_KEY_BASE64` | Base64 encoded notarization API private key |
| `APPDAB_NOTARY_KEY_ID` | API key identifier |
| `APPDAB_NOTARY_ISSUER_ID` | API issuer identifier |
| `APPDAB_HOMEBREW_TAP_TOKEN` | Fine-grained personal access token scoped to `AppDab/homebrew-tap` with write access to Contents and Pull requests |

## Publish

1. Publish the GitHub release and wait for **Release** to attach the ZIP and checksum.
2. Review and merge the pull request for `Casks/appdab-cli.rb` in `AppDab/homebrew-tap`.
