# Signed CLI distribution

This guide is for maintainers producing official AppDab CLI releases. Building, testing, and using the CLI from source does not require signing credentials or membership in AppDab's Apple Developer team; follow the [README](../README.md#build-and-test) for that workflow.

The signed macOS package runs without App Sandbox and shares AppDab's existing API keys. It is an `AppDabCLI.app` bundle containing the `dab` executable, a provisioning profile, and the Keychain access entitlement. The generated Homebrew cask installs this bundle and exposes its executable as a normal `dab` command through a symlink. The bundle does not provide a graphical interface.

## Credential storage

| Build | Keychain | Service | Access group |
| --- | --- | --- | --- |
| Signed package | Data protection Keychain, as used by AppDab | `AppDab` | `R7YA4RGA8U.app.AppDab.AppDab` |
| `swift build` or `swift run` | Local macOS login Keychain | `AppDabCLI` | None |

The signed bundle selects shared storage through its `AppDabSharedKeychain` Info.plist value. There is no command or environment override. A misconfigured shared package fails rather than falling back to separate credentials. Source builds continue working without an AppDab signing identity or provisioning profile.

Account additions and removals in the signed package affect the same credentials AppDab uses. Existing standalone accounts are not automatically copied or deleted. AppDab may need to reload its account list to reflect external changes. CLI audit records remain under `~/Library/Application Support/AppDabCLI/dab-audit.sqlite`.

The standalone package has no sandbox, bookmark, or application group entitlement. Uploads and downloads accept supplied paths, subject to normal macOS permissions and privacy protections. Existing file validation and overwrite protection still apply.

## Signing prerequisites

Official releases require access to AppDab's Apple Developer team (`R7YA4RGA8U`), a Developer ID Application signing identity with its private key installed in the signing Keychain, and a macOS Developer ID provisioning profile for `app.AppDab.AppDabCLI`. The profile must authorize both the signing certificate and the shared Keychain group `R7YA4RGA8U.app.AppDab.AppDab`; the team's wildcard group is also accepted.

These identifiers are fixed in the packaging scripts, entitlements, and `CLIKeychainConfiguration`. An independently signed fork needs its own identifiers and provisioning configuration. A different developer team cannot grant access to AppDab's shared credentials.

The profile is embedded at `Contents/embedded.provisionprofile`. The package script rejects expired profiles, another platform or developer team, an incompatible app identifier or Keychain group, and a signing certificate not authorized by the profile. Distribution requires a universal arm64 and x86_64 executable and a Developer ID Application identity. It never enables App Sandbox.

Certificates, private keys, downloaded profiles, and notarization credentials do not belong in Git. The profile and public signing certificate included in a distribution bundle are normal signing metadata.

## Build a distribution package

Run from the repository root in a logged in macOS session with Xcode selected. The CLI requires macOS 15 or later and Swift 6.1 or later.

The scripts use Bash entry points and a shared Swift implementation in `scripts/distribution.swift`. They require only Xcode's Swift toolchain and the macOS command line tools, with no additional scripting runtime or packages. Each entry point accepts `--help`.

Replace the signing identity and provisioning profile path below with the installed identity and downloaded profile for the AppDab team. `appdab-release` names a stored `notarytool` credentials profile, not a provisioning profile. Configure it before packaging using `xcrun notarytool store-credentials appdab-release` and follow the prompts.

```sh
scripts/package_cli.sh \
  --version 1.0.0 \
  --identity 'Developer ID Application: YOUR NAME (R7YA4RGA8U)' \
  --profile /path/to/AppDabCLI_Developer_ID.provisionprofile \
  --output /tmp/appdab-cli-release \
  --notary-profile appdab-release
```

This builds both architectures with the resolved dependencies, constructs and signs the bundle with hardened runtime, verifies the signature and profile certificate, submits the archive for notarization, checks acceptance, staples the ticket, assesses the app with Gatekeeper, and recreates the final archive and checksum. Existing output versions are never overwritten.

For version `1.0.0`, the output directory contains:

- `AppDabCLI-1.0.0/AppDabCLI.app`: the signed bundle.
- `AppDabCLI-1.0.0.zip`: the archive to publish.
- `AppDabCLI-1.0.0.zip.sha256`: the archive checksum.

Without `--notary-profile`, the script creates a signed package for local verification and explicitly reports that notarization is still required before distribution. `--notary-keychain` selects a nondefault Keychain containing the stored notarization credentials. Configure those credentials separately using `xcrun notarytool store-credentials`; no credential values are command inputs to this packaging script.

For a quick local proof, `--binary /path/to/dab` packages an already built executable. Distribution still requires both architectures. `--development` permits a development profile and native architecture for a local test only; it is incompatible with notarization and must not be published.

## Verify shared Keychain access

This is a local maintainer check that needs a signed package and an account already configured in AppDab on the same Mac. After packaging, run:

```sh
scripts/verify_keychain_access.sh \
  --app /tmp/appdab-cli-release/AppDabCLI-1.0.0/AppDabCLI.app
```

The verification checks the signature, shared storage selection, and absence of App Sandbox. It reads accounts through a temporary symlink and compares only account identifiers in memory. It also verifies that a copy without Keychain authorization cannot read the shared store. It prints counts and outcomes, never account details or private keys, and does not modify credentials or contact App Store Connect.

Add `--previous-app /path/to/older/AppDabCLI.app` to verify that account access persists across an upgrade. `--allow-empty` is available for a Mac without configured accounts, but an empty result does not demonstrate access to an existing AppDab account.

Contributors can run the automated tests without signing credentials or configured AppDab accounts:

```sh
swift test --force-resolved-versions
scripts/test_distribution.sh
```

## Homebrew and publishing

Generate the cask only from a final notarized archive:

```sh
scripts/generate_homebrew_cask.sh \
  --version 1.0.0 \
  --archive /tmp/appdab-cli-release/AppDabCLI-1.0.0.zip \
  --output /tmp/appdab-cli-release/appdab-cli.rb
```

The generator extracts the archive, verifies its expected version and bundle identity, validates the code signature and stapled ticket, and pins the archive checksum. A cask is Homebrew's installation definition for the signed bundle.

To publish version `1.0.0`:

1. Upload `AppDabCLI-1.0.0.zip` and its checksum to the `v1.0.0` GitHub release in `AppDab/AppDabCLI`.
2. Add the generated `appdab-cli.rb` to the Homebrew tap used to distribute the CLI. Its download URL points to that GitHub release.
3. Keep the published archive identical to the one used to generate the cask; replacing it changes the checksum and causes installation to fail.

## GitHub Actions release workflow

Repository maintainers can run **Signed CLI release candidate** from GitHub's Actions tab with a version such as `1.0.0`. It tests, builds, signs, notarizes, and uploads the zip, checksum, and generated cask as workflow artifacts. Download those artifacts and follow the publishing steps above. Configure these repository secrets before running it:

| Secret | Value |
| --- | --- |
| `APPDAB_DEVELOPER_ID_P12_BASE64` | Base64 encoded Developer ID Application certificate and private key export |
| `APPDAB_DEVELOPER_ID_P12_PASSWORD` | Password protecting that export |
| `APPDAB_DEVELOPER_ID_IDENTITY` | Signing identity name or certificate SHA1 |
| `APPDAB_CLI_DEVELOPER_ID_PROFILE_BASE64` | Base64 encoded Developer ID provisioning profile |
| `APPDAB_NOTARY_KEY_BASE64` | Base64 encoded notarization API private key |
| `APPDAB_NOTARY_KEY_ID` | API key identifier |
| `APPDAB_NOTARY_ISSUER_ID` | API issuer identifier |

The workflow uses a temporary signing Keychain and removes its signing inputs after completion. Provisioning profiles and certificates must be renewed before expiration. Repeat the signed account continuity check when changing signing identity, profile, or bundle packaging.
