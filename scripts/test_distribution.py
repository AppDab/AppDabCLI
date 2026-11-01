import datetime
import unittest
import pathlib
import stat
import tempfile
import zipfile

from package_cli import validate_profile
from generate_homebrew_cask import render, validate_archive_paths


class DistributionTests(unittest.TestCase):
    def profile(self):
        return {
            'ExpirationDate': datetime.datetime(2099, 1, 1),
            'Platform': ['OSX'], 'TeamIdentifier': ['R7YA4RGA8U'],
            'ProvisionsAllDevices': True,
            'Entitlements': {
                'com.apple.application-identifier': 'R7YA4RGA8U.app.AppDab.AppDabCLI',
                'keychain-access-groups': ['R7YA4RGA8U.*'],
            },
        }

    def test_rejects_profile_for_another_app_or_team_or_keychain_group(self):
        for change in ['app', 'team', 'group']:
            with self.subTest(change=change):
                profile = self.profile()
                if change == 'app':
                    profile['Entitlements']['com.apple.application-identifier'] = 'R7YA4RGA8U.app.Other'
                elif change == 'team':
                    profile['TeamIdentifier'] = ['ANOTHERTEAM']
                else:
                    profile['Entitlements']['keychain-access-groups'] = ['R7YA4RGA8U.app.Other']
                with self.assertRaises(ValueError):
                    validate_profile(profile)

    def test_development_profile_cannot_be_used_for_distribution(self):
        profile = self.profile()
        profile['ProvisionsAllDevices'] = False
        with self.assertRaises(ValueError):
            validate_profile(profile)
        validate_profile(profile, development=True)

    def test_expired_and_non_mac_profiles_are_rejected(self):
        expired = self.profile()
        expired['ExpirationDate'] = datetime.datetime(2000, 1, 1)
        ios = self.profile()
        ios['Platform'] = ['iOS']
        for profile in [expired, ios]:
            with self.assertRaises(ValueError):
                validate_profile(profile, development=True)

    def test_explicit_shared_group_authorization_is_accepted(self):
        profile = self.profile()
        profile['Entitlements']['keychain-access-groups'] = ['R7YA4RGA8U.app.AppDab.AppDab']
        validate_profile(profile)

    def test_cask_inputs_cannot_inject_ruby_or_invalid_checksums(self):
        with self.assertRaises(ValueError):
            render('1.0.0"; system("bad")', 'a' * 64)
        with self.assertRaises(ValueError):
            render('1.0.0', 'missing')
        cask = render('1.2.3', 'a' * 64)
        self.assertIn('version "1.2.3"', cask)
        self.assertIn('Contents/MacOS/dab', cask)

    def test_cask_archive_cannot_write_outside_its_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = pathlib.Path(directory) / 'bad.zip'
            for filename in ['../outside', '/outside', 'Other.app/file']:
                with self.subTest(filename=filename):
                    with zipfile.ZipFile(archive, 'w') as zipped:
                        zipped.writestr(filename, 'fixture')
                    with self.assertRaises(ValueError):
                        validate_archive_paths(archive)

    def test_internal_resource_links_are_allowed_and_escaping_links_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = pathlib.Path(directory) / 'links.zip'
            for target, allowed in [('Contents/Resources/Locales.bundle', True), ('../../outside', False), ('/outside', False)]:
                with self.subTest(target=target):
                    member = zipfile.ZipInfo('AppDabCLI.app/Locales.bundle')
                    member.external_attr = (stat.S_IFLNK | 0o777) << 16
                    with zipfile.ZipFile(archive, 'w') as zipped:
                        zipped.writestr(member, target)
                    if allowed:
                        validate_archive_paths(archive)
                    else:
                        with self.assertRaises(ValueError):
                            validate_archive_paths(archive)


if __name__ == '__main__':
    unittest.main()
