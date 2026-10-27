#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('sdk', Path(__file__).resolve().parents[1] / 'check-sdk-toolchains.py')
sdk = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sdk)

APPLE = '''<table><tr><th>Xcode Version</th><th>Host</th><th>SDKs</th></tr>
<tr><td>Xcode 27.2 RC</td><td>macOS</td><td>iOS 27.2</td></tr>
<tr><td>Xcode 27.1</td><td>macOS</td><td>iOS 27.1<br>macOS 27</td></tr>
<tr><td>Xcode 16.2</td><td>macOS</td><td>iOS 18.2<br>macOS 15.2</td></tr></table>'''
ANDROID = '''<sdk-repository>
<remotePackage path="ndk;31.0.1"><revision><preview>1</preview></revision><channelRef ref="channel-0"/></remotePackage>
<remotePackage path="ndk;30.0.2"><revision/><channelRef ref="channel-0"/></remotePackage>
<remotePackage path="ndk;32.0.1"><revision/><channelRef ref="channel-1"/></remotePackage>
<remotePackage path="ndk;29.0.3"><revision/><channelRef ref="channel-0"/></remotePackage>
<remotePackage path="build-tools;37.0.0"><revision/><channelRef ref="channel-0"/></remotePackage>
</sdk-repository>'''
WINDOWS = '''<h2>Windows 11</h2><strong>Windows SDK for Windows 11 (10.0.28000.2957)</strong>
<h2 id="preview">Preview releases</h2>Windows SDK for Windows 11 (10.0.99999.0)'''


class Client:
    def text(self, url):
        return {sdk.APPLE: APPLE, sdk.ANDROID: ANDROID, sdk.WINDOWS: WINDOWS}[url]

    def json(self, url):
        if url in sdk.VS_CHANNELS.values():
            return {'info': {'productMilestoneIsPreRelease': 'False', 'productDisplayVersion': '17.14.43'}}
        return [{'tag_name': 'v8.0.0-rc1', 'prerelease': True}, {'tag_name': 'v7.0.1'},
                {'tag_name': 'v8.0.0', 'draft': True}, {'tag_name': 'v6.1.0'}]


class TestProviders(unittest.TestCase):
    def test_apple_stable_and_sdk_mapping(self):
        values = sdk.apple_versions(APPLE)
        self.assertEqual(max(values, key=sdk.version), '27.1')
        self.assertEqual(values['16.2'], 'iOS 18.2 / macOS 15.2')
        with self.assertRaises(ValueError):
            sdk.apple_versions('<p>layout changed</p>')

    def test_android_preview_channels_and_numeric_order(self):
        self.assertEqual(sdk.android_versions(ANDROID, 'ndk'), '30.0.2')
        self.assertEqual(sdk.android_versions(ANDROID, 'build-tools'), '37.0.0')
        with self.assertRaises(ValueError):
            sdk.android_versions('<empty/>', 'ndk')

    def test_windows_preview_section(self):
        self.assertEqual(sdk.windows_version(WINDOWS), '10.0.28000.2957')
        with self.assertRaises(ValueError):
            sdk.windows_version('<p>unknown layout</p>')

    def test_action_pins(self):
        self.assertEqual(sdk.action_status('v7', '7.0.1'), 'Floating major; patch not pinned')
        self.assertEqual(sdk.action_status('v7.0', '7.0.1'), 'Floating minor; patch not pinned')
        self.assertEqual(sdk.action_status('v6', '7.0.1'), 'Update available')
        self.assertEqual(sdk.action_status('v7.0.1', '7.0.1'), 'Up to date')
        self.assertEqual(sdk.action_status('v7.1.0', '7.0.1'), 'Ahead of latest stable')
        self.assertEqual(sdk.action_status('a' * 40, '7.0.1'), 'Commit pinned; review manually')
        self.assertEqual(sdk.action_status('main', '7.0.1'), 'Branch/custom ref; review manually')
        self.assertEqual(sdk.action_release(Client(), 'actions/checkout')[0], '7.0.1')

    def test_action_pagination_and_no_releases(self):
        class Pages:
            def json(self, url):
                if url.endswith('&page=1'):
                    return [{'tag_name': 'v6.0.0'}] * 100
                return [{'tag_name': 'v7.0.1'}]
        self.assertEqual(sdk.action_release(Pages(), 'owner/action')[0], '7.0.1')
        class Empty:
            def json(self, url):
                return []
        self.assertIsNone(sdk.action_release(Empty(), 'owner/fork'))


class TestDiscovery(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        (self.root / '.github/workflows').mkdir(parents=True)
        (self.root / 'scripts').mkdir()
        (self.root / 'apothecary').mkdir()
        (self.root / '.github/workflows/build.yml').write_text('''name: fixture
env:
  VS_VER: 17
jobs:
  build:
    env:
      DEVELOPER_DIR: /Applications/Xcode_16.2.app/Contents/Developer
    steps:
      - uses: actions/checkout@v6.0.2
      - uses: actions/cache/restore@v7
      - uses: ./local
      - uses: docker://alpine:3.20
      - run: |
          uses: pretend/not-an-action@v1
''')
        (self.root / 'scripts/build-matrices.json').write_text(json.dumps({
            '.github/workflows/build-android.yml': {'build-android-platforms': {
                'NDK': ['29.0.3'], 'SDK': ['37.0.0']}}}))
        (self.root / 'apothecary/apothecary').write_text('WIN10_INSTALLED_SDK_2022=10.0.20348.0\nWIN10_INSTALLED_SDK_2026=10.0.XXXXX.0\n')

    def test_real_yaml_discovery_and_report(self):
        result = sdk.collect(self.root, Client())
        text = result['markdown']
        self.assertEqual(result['errors'], 0)
        self.assertEqual(result['updates'], 4)  # Xcode, NDK, SDK, checkout.
        self.assertEqual(result['checks'], 8)
        self.assertIn('iOS 18.2 / macOS 15.2', text)
        self.assertIn('Placeholder; not a usable SDK pin', text)
        self.assertIn('Major selected; installed patch follows runner', text)
        self.assertIn('2 distinct external references; 2 local/Docker references excluded', text)
        self.assertNotIn('pretend/not-an-action', text)

    def test_provider_failure_is_visible_and_other_checks_continue(self):
        class Broken(Client):
            def text(self, url):
                if url == sdk.ANDROID:
                    raise OSError('HTTP 503')
                return super().text(url)
        result = sdk.collect(self.root, Broken())
        self.assertEqual(result['errors'], 1)
        self.assertIn('HTTP 503', result['markdown'])
        self.assertIn('actions/checkout', result['markdown'])

    def test_literal_xcode_matrix_and_ndk_fallback(self):
        path = self.root / '.github/workflows/build.yml'
        text = path.read_text().replace('/Applications/Xcode_16.2.app/Contents/Developer',
                                        '/Applications/${{ matrix.xcode }}/Contents/Developer')
        path.write_text(text + '\nextra:\n  include:\n    - xcode: Xcode_16.2.app\n    - xcode: Xcode_27.1.app\n')
        engine = self.root / 'apothecary/apothecary'
        engine.write_text(engine.read_text() + 'export NDK_VERSION="${NDK_VERSION:-"27.2.12479018"}"\n')
        result = sdk.collect(self.root, Client())
        self.assertEqual(result['errors'], 0)
        self.assertIn('Xcode 16.2; iOS 18.2', result['markdown'])
        self.assertIn('Xcode 27.1; iOS 27.1', result['markdown'])
        self.assertIn('Android NDK engine fallback | 27.2.12479018', result['markdown'])
        self.assertNotIn('Dynamic/nonliteral selection', result['markdown'])


if __name__ == '__main__':
    unittest.main()
