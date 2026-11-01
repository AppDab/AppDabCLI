#!/usr/bin/env python3
"""Read only verification of a signed CLI's shared Keychain access."""
import argparse
import json
import pathlib
import plistlib
import shutil
import subprocess
import tempfile

GROUP = 'R7YA4RGA8U.app.AppDab.AppDab'


def accounts(executable):
    result = subprocess.run([str(executable), 'accounts', 'list', '--format', 'json'], capture_output=True, text=True, timeout=30)
    if result.returncode:
        raise RuntimeError('Signed CLI account lookup failed: ' + result.stderr.strip())
    # Account identifiers are compared in memory; no credentials or account details are printed.
    return {account['accountID'] for account in json.loads(result.stdout)['data']['accounts']}


def inspect(app):
    subprocess.run(['codesign', '--verify', '--strict', str(app)], check=True)
    result = subprocess.run(['codesign', '--display', '--entitlements', ':-', str(app)], capture_output=True, check=True)
    entitlements = plistlib.loads(result.stdout)
    if entitlements.get('com.apple.security.app-sandbox', False):
        raise RuntimeError('The standalone package is unexpectedly sandboxed.')
    if GROUP not in entitlements.get('keychain-access-groups', []):
        raise RuntimeError('The shared Keychain entitlement is missing.')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('AppDabSharedKeychain') is not True:
        raise RuntimeError('The package does not select shared Keychain storage.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', required=True)
    parser.add_argument('--previous-app', help='An earlier signed package to check account continuity')
    parser.add_argument('--allow-empty', action='store_true', help='Allow a Mac with no configured AppDab accounts')
    args = parser.parse_args()
    app = pathlib.Path(args.app).resolve(strict=True)
    inspect(app)
    with tempfile.TemporaryDirectory(prefix='appdab-keychain-check-') as temporary:
        root = pathlib.Path(temporary)
        link = root / 'dab'
        link.symlink_to(app / 'Contents/MacOS/dab')
        identifiers = accounts(link)
        if not args.allow_empty and not identifiers:
            raise RuntimeError('No shared accounts found. Configure an account in AppDab before verifying sharing.')
        if args.previous_app:
            previous = pathlib.Path(args.previous_app).resolve(strict=True)
            inspect(previous)
            link.unlink()
            link.symlink_to(previous / 'Contents/MacOS/dab')
            if accounts(link) != identifiers:
                raise RuntimeError('Shared accounts changed between package versions.')
        unentitled = root / 'Unentitled.app'
        shutil.copytree(app, unentitled, symlinks=True)
        (unentitled / 'Contents/embedded.provisionprofile').unlink()
        empty = root / 'empty.entitlements'
        empty.write_bytes(plistlib.dumps({}))
        subprocess.run(['codesign', '--force', '--sign', '-', '--entitlements', str(empty), str(unentitled)], check=True, capture_output=True)
        rejected = subprocess.run([str(unentitled / 'Contents/MacOS/dab'), 'accounts', 'list', '--format', 'json'], capture_output=True, timeout=30)
        if rejected.returncode == 0:
            raise RuntimeError('A shared mode package without Keychain authorization unexpectedly succeeded.')
    print('PASS: signed unsandboxed CLI, symlink invocation, shared account count ' + str(len(identifiers)) + ', and rejection without authorization.')
    if args.previous_app:
        print('PASS: shared accounts remain available across package versions.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
