#!/usr/bin/env python3
"""Build a signed CLI app wrapper without enabling App Sandbox."""
import argparse
import datetime
import fnmatch
import hashlib
import json
import pathlib
import plistlib
import re
import shutil
import subprocess
import tempfile

TEAM = 'R7YA4RGA8U'
BUNDLE_ID = 'app.AppDab.AppDabCLI'
ACCESS_GROUP = TEAM + '.app.AppDab.AppDab'
REPO = pathlib.Path(__file__).resolve().parents[1]


def run(*arguments, **kwargs):
    return subprocess.run([str(a) for a in arguments], check=True, **kwargs)


def validate_profile(profile, development=False, now=None):
    now = now or datetime.datetime.now(datetime.timezone.utc)
    expires = profile['ExpirationDate'].replace(tzinfo=datetime.timezone.utc)
    entitlements = profile.get('Entitlements', {})
    if expires <= now:
        raise ValueError('Provisioning profile has expired.')
    if 'OSX' not in profile.get('Platform', []):
        raise ValueError('A macOS provisioning profile is required.')
    if TEAM not in profile.get('TeamIdentifier', []):
        raise ValueError('The profile must belong to the AppDab developer team.')
    identifier = entitlements.get('com.apple.application-identifier', '')
    if not identifier or not fnmatch.fnmatchcase(TEAM + '.' + BUNDLE_ID, identifier):
        raise ValueError('The profile does not authorize the CLI bundle identifier.')
    if not any(fnmatch.fnmatchcase(ACCESS_GROUP, group) for group in entitlements.get('keychain-access-groups', [])):
        raise ValueError('The profile does not authorize the AppDab Keychain access group.')
    if not development and not profile.get('ProvisionsAllDevices', False):
        raise ValueError('A Developer ID provisioning profile is required for distribution; use --development only for local tests.')


def package(args):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', args.version):
        raise ValueError('Version must contain three numeric components, such as 1.0.0.')
    if args.development and args.notary_profile:
        raise ValueError('Development packages cannot be submitted for notarization.')
    profile_path = pathlib.Path(args.profile).resolve(strict=True)
    decoded = run('security', 'cms', '-D', '-i', profile_path, capture_output=True)
    profile = plistlib.loads(decoded.stdout)
    validate_profile(profile, args.development)
    output = pathlib.Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    destination = output / ('AppDabCLI-' + args.version)
    archive = output / ('AppDabCLI-' + args.version + '.zip')
    if destination.exists() or archive.exists():
        raise ValueError('The output version already exists; choose an empty output directory.')
    if args.binary:
        binary = pathlib.Path(args.binary).resolve(strict=True)
    else:
        scratch = REPO / '.build' / 'distribution-build'
        flags = ['--configuration', 'release', '--arch', 'arm64', '--arch', 'x86_64', '--scratch-path', str(scratch), '--force-resolved-versions']
        run('swift', 'build', '--product', 'dab', '-j', '4', *flags, cwd=REPO)
        result = run('swift', 'build', '--show-bin-path', *flags, capture_output=True, text=True, cwd=REPO)
        binary = pathlib.Path(result.stdout.strip()) / 'dab'
    architectures = run('lipo', '-archs', binary, capture_output=True, text=True).stdout.split()
    if not args.development and not {'arm64', 'x86_64'}.issubset(architectures):
        raise ValueError('Distribution requires a universal arm64 and x86_64 executable.')
    with tempfile.TemporaryDirectory(prefix='.cli-package-', dir=output) as temporary:
        stage = pathlib.Path(temporary)
        app = stage / 'AppDabCLI.app'
        contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True)
        shutil.copy2(binary, contents / 'MacOS' / 'dab')
        resources = contents / 'Resources'
        resources.mkdir()
        for bundle in binary.parent.glob('*.bundle'):
            shutil.copytree(bundle, resources / bundle.name)
            # SwiftPM accessors may use the bundle root or its resource directory.
            (app / bundle.name).symlink_to('Contents/Resources/' + bundle.name)
        info = plistlib.loads((REPO / 'Distribution/Info.plist').read_bytes())
        info.update(CFBundleShortVersionString=args.version, CFBundleVersion=args.version)
        (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
        shutil.copy2(profile_path, contents / 'embedded.provisionprofile')
        signing = ['codesign', '--force', '--sign', args.identity, '--options', 'runtime', '--entitlements', str(REPO / 'Distribution/AppDabCLI.entitlements')]
        if not args.development:
            signing.append('--timestamp')
        run(*signing, app)
        run('codesign', '--verify', '--strict', '--verbose=2', app)
        prefix = str(stage / 'signer-')
        run('codesign', '--display', '--extract-certificates=' + prefix, app, capture_output=True)
        signer = pathlib.Path(prefix + '0').read_bytes()
        allowed = profile.get('DeveloperCertificates', [])
        if signer not in allowed:
            raise ValueError('The signing certificate is not authorized by the provisioning profile.')
        details = run('codesign', '--display', '--verbose=4', app, capture_output=True, text=True).stderr
        if not args.development and 'Authority=Developer ID Application:' not in details:
            raise ValueError('Distribution requires a Developer ID Application signing identity.')
        emitted = run('codesign', '--display', '--entitlements', ':-', app, capture_output=True)
        actual = plistlib.loads(emitted.stdout)
        if actual.get('com.apple.security.app-sandbox', False):
            raise ValueError('The standalone CLI must not enable App Sandbox.')
        if actual.get('keychain-access-groups') != [ACCESS_GROUP]:
            raise ValueError('Unexpected signed Keychain access groups.')
        run('ditto', '-c', '-k', '--keepParent', app, archive)
        try:
            if args.notary_profile:
                notary = ['xcrun', 'notarytool', 'submit', str(archive), '--keychain-profile', args.notary_profile, '--wait', '--output-format', 'json']
                if args.notary_keychain:
                    notary += ['--keychain', args.notary_keychain]
                submission = json.loads(run(*notary, capture_output=True, text=True).stdout)
                if submission.get('status') != 'Accepted':
                    raise ValueError('Notarization was not accepted. Submission: ' + str(submission.get('id')))
                run('xcrun', 'stapler', 'staple', app)
                run('xcrun', 'stapler', 'validate', app)
                run('spctl', '--assess', '--type', 'execute', '--verbose=2', app)
                archive.unlink()
                run('ditto', '-c', '-k', '--keepParent', app, archive)
            (output / (archive.name + '.sha256')).write_text(hashlib.sha256(archive.read_bytes()).hexdigest() + '  ' + archive.name + '\n')
            destination.mkdir()
            shutil.move(str(app), destination / app.name)
        except BaseException:
            archive.unlink(missing_ok=True)
            raise
    print('Package:', destination / 'AppDabCLI.app')
    print('Archive:', archive)
    if args.development:
        print('Development proof only. This package is not suitable for distribution.')
    elif not args.notary_profile:
        print('Signed but not notarized. Supply --notary-profile before distribution.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--identity', required=True, help='Signing identity name or SHA1 hash')
    parser.add_argument('--profile', required=True, help='macOS provisioning profile path')
    parser.add_argument('--output', default=str(REPO / '.build/distribution'))
    parser.add_argument('--binary', help='Use an existing executable instead of building universal release binaries')
    parser.add_argument('--development', action='store_true', help='Allow a device limited profile and native architecture for local proof')
    parser.add_argument('--notary-profile', help='Previously stored notarytool credentials profile')
    parser.add_argument('--notary-keychain', help='Keychain containing the notarytool profile')
    args = parser.parse_args()
    try:
        package(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        if isinstance(error, subprocess.CalledProcessError) and error.stderr:
            detail = error.stderr.decode(errors='replace') if isinstance(error.stderr, bytes) else error.stderr
            parser.exit(1, detail + '\n' + str(error) + '\n')
        parser.exit(1, str(error) + '\n')


if __name__ == '__main__':
    main()
