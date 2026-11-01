#!/usr/bin/env python3
"""Generate a cask from an already notarized AppDabCLI archive."""
import argparse
import hashlib
import pathlib
import plistlib
import re
import stat
import subprocess
import tempfile
import zipfile


def render(version, sha256):
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('Version must contain three numeric components.')
    if not re.fullmatch(r'[0-9a-f]{64}', sha256):
        raise ValueError('Invalid archive SHA256.')
    return '''cask "appdab-cli" do
  version "VERSION"
  sha256 "CHECKSUM"

  url "https://github.com/AppDab/AppDabCLI/releases/download/v#{version}/AppDabCLI-#{version}.zip"
  name "AppDab CLI"
  desc "App Store Connect automation with shared AppDab credentials"
  homepage "https://github.com/AppDab/AppDabCLI"

  depends_on macos: ">= :sequoia"

  app "AppDabCLI.app"
  binary "#{appdir}/AppDabCLI.app/Contents/MacOS/dab", target: "dab"
end
'''.replace('VERSION', version).replace('CHECKSUM', sha256)


def validate_archive_paths(archive):
    with zipfile.ZipFile(archive) as zipped:
        for member in zipped.infolist():
            path = pathlib.PurePosixPath(member.filename)
            if path.is_absolute() or '..' in path.parts or not path.parts or path.parts[0] not in ['AppDabCLI.app', '__MACOSX']:
                raise ValueError('Unexpected archive path.')
            if stat.S_ISLNK(member.external_attr >> 16):
                target = pathlib.PurePosixPath(zipped.read(member).decode('utf-8'))
                if target.is_absolute():
                    raise ValueError('Archive symlink leaves the bundle.')
                parts = list(path.parent.parts)
                for component in target.parts:
                    if component == '..':
                        if len(parts) <= 1:
                            raise ValueError('Archive symlink leaves the bundle.')
                        parts.pop()
                    elif component != '.':
                        parts.append(component)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--version', required=True)
    parser.add_argument('--archive', required=True, help='Final notarized and stapled zip')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    archive = pathlib.Path(args.archive).resolve(strict=True)
    expected = 'AppDabCLI-' + args.version + '.zip'
    if archive.name != expected:
        parser.error('Archive filename must be ' + expected)
    validate_archive_paths(archive)
    with tempfile.TemporaryDirectory(prefix='appdab-cask-check-') as temporary:
        subprocess.run(['ditto', '-x', '-k', str(archive), temporary], check=True)
        app = pathlib.Path(temporary) / 'AppDabCLI.app'
        info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
        if info.get('CFBundleShortVersionString') != args.version or info.get('CFBundleIdentifier') != 'app.AppDab.AppDabCLI' or info.get('AppDabSharedKeychain') is not True:
            parser.error('The archive does not contain the expected CLI release.')
        subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
        subprocess.run(['xcrun', 'stapler', 'validate', str(app)], check=True)
    content = render(args.version, hashlib.sha256(archive.read_bytes()).hexdigest())
    output = pathlib.Path(args.output)
    if output.exists():
        parser.error('Refusing to overwrite an existing cask.')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content)
    print('Generated:', output)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error))
