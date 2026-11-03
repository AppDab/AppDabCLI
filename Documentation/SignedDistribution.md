# Signed CLI distribution

The official macOS package runs without App Sandbox and shares AppDab's existing API keys. It is a small `AppDabCLI.app` bundle containing the `dab` executable, a provisioning profile, and the Keychain access entitlement. Homebrew exposes the executable as a normal `dab` command through a symlink. The bundle does not provide a graphical interface.

## Credential storage

| Build | Keychain | Service | Access group |
| --- | --- | --- | --- |
| Signed package | Data protection Keychain, as used by AppDab | `AppDab` | `R7YA4RGA8U.app.AppDab.AppDab` |
| `swift build` or `swift run` | Local macOS login Keychain | `AppDabCLI` | None |

The signed bundle selects shared storage through its `AppDabSharedKeychain` Info.plist value. There is no command or environment override. A misconfigured shared package fails rather than falling back to separate credentials. Source builds continue working without an AppDab signing identity or provisioning profile.

Account additions and removals in the signed package affect the same credentials AppDab uses. Existing standalone accounts are not automatically copied or deleted. AppDab may need to reload its account list to reflect external changes. CLI audit records remain under `~/Library/Application Support/AppDabCLI`; this change shares credentials, not the app's audit database or preferences.

The standalone package has no sandbox, bookmark, or application group entitlement. Uploads and downloads accept supplied paths, subject to normal macOS permissions and privacy protections. Existing file validation and overwrite protection still apply.

## Signing prerequisites

Use the existing AppDab developer team and an explicit macOS identifier `app.AppDab.AppDabCLI`. Create a Developer ID provisioning profile authorizing that identifier and the shared Keychain group. Select the Developer ID Application certificate used to sign the package. The profile's authorized Keychain groups may include the team's wildcard group.

The profile is embedded at `Contents/embedded.provisionprofile`. The package script rejects expired profiles, another platform or developer team, an incompatible app identifier or Keychain group, and a signing certificate not authorized by the profile. Distribution requires a universal arm64 and x86_64 executable and a Developer ID Application identity. It never enables App Sandbox.

Certificates, private keys, downloaded profiles, and notarization credentials do not belong in Git. The profile and public signing certificate included in a distribution bundle are normal signing metadata.

## Build a distribution package

Run from a logged in macOS session with Xcode selected:

The scripts use Bash entry points and a shared Swift implementation in `scripts/distribution.swift`. They require only Xcode's Swift toolchain and the macOS command line tools, with no additional scripting runtime or packages. Each entry point accepts `--help`.

```sh
scripts/package_cli.sh \
  --version 1.0.0 \
  --identity 'Developer ID Application: YOUR NAME (R7YA4RGA8U)' \
  --profile /path/to/AppDabCLI_Developer_ID.provisionprofile \
  --output /tmp/appdab-cli-release \
  --notary-profile appdab-release
```

This builds both architectures with the resolved dependencies, constructs and signs the bundle with hardened runtime, verifies the signature and profile certificate, submits the archive for notarization, checks acceptance, staples the ticket, assesses the app with Gatekeeper, and recreates the final archive and checksum. Existing output versions are never overwritten.

Without `--notary-profile`, the script creates a signed package for local verification and explicitly reports that notarization is still required before distribution. `--notary-keychain` selects a nondefault Keychain containing the stored notarization credentials. Configure those credentials separately using `xcrun notarytool store-credentials`; no credential values are command inputs to this packaging script.

For a quick local proof, `--binary /path/to/dab` packages an already built executable. Distribution still requires both architectures. `--development` permits a development profile and native architecture for a local test only; it is incompatible with notarization and must not be published.

## Verify shared Keychain access

Configure an account in AppDab, then run:

```sh
scripts/verify_keychain_access.sh \
  --app /tmp/appdab-cli-release/AppDabCLI-1.0.0/AppDabCLI.app
```

The verification checks the signature, shared storage selection, and absence of App Sandbox. It reads accounts through a temporary symlink and compares only account identifiers in memory. It also verifies that a copy without Keychain authorization cannot read the shared store. It prints counts and outcomes, never account details or private keys, and does not modify credentials or contact App Store Connect.

Add `--previous-app /path/to/older/AppDabCLI.app` to verify that account access persists across an upgrade. `--allow-empty` is available for a Mac without configured accounts, but an empty result does not demonstrate access to an existing AppDab account.

Run the automated tests with:

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

The generator extracts the archive, verifies its expected version and bundle identity, validates the code signature and stapled ticket, and pins the archive checksum. It expects the archive to be published as `AppDabCLI-1.0.0.zip` in the repository's `v1.0.0` GitHub release. Publish the generated cask in the intended Homebrew tap after publishing that exact archive. A tap and public release are separate publishing steps; this branch does not create either automatically.

The **Signed CLI release candidate** workflow is manually dispatched with a version. It tests, builds, signs, notarizes, and uploads the zip, checksum, and generated cask as workflow artifacts. It does not create a GitHub release or change a Homebrew tap. Configure these repository secrets before running it:

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
