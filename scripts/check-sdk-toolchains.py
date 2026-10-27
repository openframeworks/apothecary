#!/usr/bin/env python3
"""Read declared toolchain/action pins; query official release metadata only."""
import argparse
from collections import defaultdict
from functools import lru_cache
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

APPLE = 'https://developer.apple.com/support/xcode/'
ANDROID = 'https://dl.google.com/android/repository/repository2-3.xml'
WINDOWS = 'https://learn.microsoft.com/en-us/windows/apps/windows-sdk/downloads'
VS_CHANNELS = {'17': 'https://aka.ms/vs/17/release/channel', '18': 'https://aka.ms/vs/stable/channel'}
NUMBER = r'\d+(?:\.\d+){0,3}'


def version(value):
    if not re.fullmatch(NUMBER, value):
        raise ValueError('Not a stable numeric version: ' + value)
    parts = tuple(map(int, value.split('.')))
    return parts + (0,) * (4 - len(parts))


def status(pin, latest):
    current, upstream = version(pin), version(latest)
    return ('Update available' if current < upstream else
            'Up to date' if current == upstream else 'Ahead of latest stable')


class Client:
    @lru_cache(maxsize=256)
    def text(self, url):
        headers = {'User-Agent': 'apothecary-sdk-version-check'}
        # Never send the GitHub token to Apple, Google, Microsoft or redirects.
        token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
        if urllib.parse.urlparse(url).hostname == 'api.github.com' and token:
            headers['Authorization'] = 'Bearer ' + token
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as response:
            data = response.read(5_000_001)
        if len(data) > 5_000_000:
            raise ValueError('Release metadata exceeds 5 MB')
        return data.decode('utf-8-sig')

    def json(self, url):
        return json.loads(self.text(url))


class Tables(HTMLParser):
    def __init__(self):
        super().__init__()
        self.rows, self.row, self.cell = [], None, None

    def handle_starttag(self, tag, attrs):
        if tag == 'tr':
            self.row = []
        elif tag in ('td', 'th') and self.row is not None:
            self.cell = []
        elif tag == 'br' and self.cell is not None:
            self.cell.append(' / ')

    def handle_data(self, data):
        if self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self.cell is not None:
            self.row.append(' '.join(''.join(self.cell).split()))
            self.cell = None
        elif tag == 'tr' and self.row is not None:
            self.rows.append(self.row)
            self.row = None


def apple_versions(text):
    table = Tables()
    table.feed(text)
    releases = {}
    for row in table.rows:
        match = re.fullmatch(r'Xcode (' + NUMBER + ')', row[0]) if row else None
        if match and len(row) >= 3:
            releases[match[1]] = row[2]
    if not releases:
        raise ValueError('No stable Xcode/SDK rows in Apple support table')
    return releases


def android_versions(text, prefix):
    releases = []
    for package in ET.fromstring(text).iter('remotePackage'):
        path = package.get('path', '')
        channel = package.find('channelRef')
        preview = package.find('revision/preview')
        if (path.startswith(prefix + ';') and
                (channel is None or channel.get('ref') == 'channel-0') and
                (preview is None or int(preview.text) == 0) and
                re.fullmatch(NUMBER, path.split(';', 1)[1])):
            releases.append(path.split(';', 1)[1])
    if not releases:
        raise ValueError('No stable Android ' + prefix + ' packages')
    return max(releases, key=version)


def windows_version(text):
    # Preview releases are a separate section below stable SDK downloads.
    text = re.split(r'<h2[^>]*>\s*Preview releases', text, flags=re.I)[0]
    releases = re.findall(r'Windows SDK for Windows (?:10|11) \((10\.0\.\d+\.\d+)\)', text)
    if not releases:
        raise ValueError('No stable Windows SDK releases in Microsoft downloads')
    return max(releases, key=version)


def load_workflows(root):
    files = sorted(set(root.glob('.github/workflows/*.yml')) |
                   set(root.glob('.github/workflows/*.yaml')) |
                   set(root.glob('.github/actions/**/action.yml')) |
                   set(root.glob('.github/actions/**/action.yaml')))
    # Use the same Ruby YAML reader dependency as release-build-plan.cjs.
    data = subprocess.check_output([
        'ruby', '-ryaml', '-rjson', '-e',
        'puts JSON.generate(ARGV.to_h { |f| [f, YAML.safe_load(File.read(f), aliases: true)] })',
        *map(str, files)], text=True)
    return {str(Path(file).relative_to(root)): doc for file, doc in json.loads(data).items()}


def walk(value):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def action_release(client, repo):
    # Releases are ordered by date; fetch every page rather than trusting the
    # first release (which can be a patch for an older major).
    for endpoint in ('releases', 'tags'):
        versions = []
        for page in range(1, 21):
            batch = client.json(f'https://api.github.com/repos/{repo}/{endpoint}?per_page=100&page={page}')
            if not isinstance(batch, list):
                raise ValueError('Expected a GitHub release/tag list')
            for row in batch:
                tag = row.get('tag_name', row.get('name', ''))
                if not row.get('draft') and not row.get('prerelease') and re.fullmatch('v?' + NUMBER, tag):
                    versions.append((tag.removeprefix('v'), row.get('html_url') or f'https://github.com/{repo}/tree/{tag}'))
            if len(batch) < 100:
                break
        else:
            raise ValueError('Action release pagination exceeds 20 pages')
        if versions:
            return max(versions, key=lambda row: version(row[0]))
    return None


def action_status(ref, latest):
    if not re.fullmatch('v?' + NUMBER, ref):
        return 'Commit pinned; review manually' if re.fullmatch('[a-fA-F0-9]{40}', ref) else 'Branch/custom ref; review manually'
    pin = ref.removeprefix('v')
    parts = len(pin.split('.'))
    if parts < 3 and version(pin)[:parts] == version(latest)[:parts]:
        return 'Floating major; patch not pinned' if parts == 1 else 'Floating minor; patch not pinned'
    return status(pin, latest)


def markdown(rows, title):
    lines = [f'### {title}', '', '| Tool / action | Declared pin | Latest stable | Status | Pin source |',
             '| --- | --- | --- | --- | --- |']
    def cell(value):
        return str(value).replace('|', '\\|').replace('\n', ' ')
    lines += ['| ' + ' | '.join(map(cell, row)) + ' |' for row in rows]
    return '\n'.join(lines) + '\n'


def collect(root, client):
    workflows = load_workflows(root)
    engine = (root / 'apothecary/apothecary').read_text()
    tools, actions, errors = [], [], []

    def check(label, operation):
        try:
            operation()
        except Exception as error:
            errors.append(f'{label}: {type(error).__name__}: {error}')

    def apple():
        releases = apple_versions(client.text(APPLE))
        latest = max(releases, key=version)
        found = False
        for file, doc in workflows.items():
            pins = {str(node['DEVELOPER_DIR']) for node in walk(doc) if 'DEVELOPER_DIR' in node}
            # Resolve this literal matrix field without evaluating expressions.
            matrix_path = '/Applications/${{ matrix.xcode }}/Contents/Developer'
            if matrix_path in pins:
                selections = {str(node['xcode']) for node in walk(doc)
                              if isinstance(node.get('xcode'), str) and
                              re.fullmatch(r'Xcode_' + NUMBER + r'\.app', node['xcode'])}
                if selections:
                    pins.remove(matrix_path)
                    pins.update('/Applications/' + selected + '/Contents/Developer' for selected in selections)
            for pin in sorted(pins):
                found = True
                match = re.fullmatch(r'/Applications/Xcode_(' + NUMBER + r')\.app/Contents/Developer', pin)
                if not match:
                    tools.append(('Apple Xcode', pin, f'[{latest}]({APPLE})', 'Dynamic/nonliteral selection; review manually', file))
                    continue
                selected = match[1]
                if selected not in releases:
                    raise ValueError(f'Xcode {selected} SDK mapping missing from Apple table ({file})')
                tools.append(('Apple Xcode and bundled SDKs', f'Xcode {selected}; {releases[selected]}',
                              f'[Xcode {latest}]({APPLE}); {releases[latest]}', status(selected, latest), file))
        if not found:
            raise ValueError('No DEVELOPER_DIR pins discovered')
    check('Apple SDKs / Xcode', apple)

    def android():
        metadata = client.text(ANDROID)
        matrix = json.loads((root / 'scripts/build-matrices.json').read_text())
        entries = matrix['.github/workflows/build-android.yml']['build-android-platforms']
        for variable, prefix, label in [('NDK', 'ndk', 'Android NDK'), ('SDK', 'build-tools', 'Android SDK Build Tools')]:
            latest = android_versions(metadata, prefix)
            for pin in entries[variable]:
                tools.append((label, pin, f'[{latest}]({ANDROID})', status(pin, latest), f'scripts/build-matrices.json ({variable})'))
        defaults = re.findall(r'export NDK_VERSION=.*?:-"([0-9.]+)"', engine)
        for pin in sorted(set(defaults), key=version):
            latest = android_versions(metadata, 'ndk')
            tools.append(('Android NDK engine fallback', pin, f'[{latest}]({ANDROID})',
                          status(pin, latest), 'apothecary/apothecary (NDK_VERSION default; CI matrix overrides)'))
    check('Android SDK / NDK', android)

    def windows():
        latest = windows_version(client.text(WINDOWS))
        pins = re.findall(r'^(WIN(?:10|11)_INSTALLED_SDK_\d+)=(\S+)', engine, re.M)
        if not pins:
            raise ValueError('No engine Windows SDK pins discovered')
        for name, pin in pins:
            result = status(pin, latest) if re.fullmatch(NUMBER, pin) else 'Placeholder; not a usable SDK pin'
            tools.append(('Windows SDK default ' + name, pin, f'[{latest}]({WINDOWS})', result, 'apothecary/apothecary'))
    check('Windows SDK', windows)

    def visual_studio():
        pins = defaultdict(set)
        for file, doc in workflows.items():
            for node in walk(doc):
                if 'VS_VER' in node and re.fullmatch(r'\d+', str(node['VS_VER'])):
                    pins[str(node['VS_VER'])].add(file)
        if not pins:
            raise ValueError('No Visual Studio major selections discovered')
        for major, files in sorted(pins.items()):
            url = VS_CHANNELS.get(major, f'https://aka.ms/vs/{major}/release/channel')
            info = client.json(url)['info']
            if str(info.get('productMilestoneIsPreRelease', '')).lower() != 'false':
                raise ValueError('Microsoft channel is not explicitly stable')
            latest = info['productDisplayVersion']
            version(latest)
            tools.append(('Visual Studio compiler host', 'VS major ' + major,
                          f'[{latest}]({url})', 'Major selected; installed patch follows runner', ', '.join(sorted(files))))
    check('Microsoft Visual Studio channels', visual_studio)

    refs = defaultdict(set)
    skipped = 0
    for file, doc in workflows.items():
        for node in walk(doc):
            ref = node.get('uses')
            if not isinstance(ref, str):
                continue
            match = re.fullmatch(r'([\w.-]+/[\w.-]+)(/[^@]+)?@([^\s@]+)', ref)
            if match:
                refs[(match[1], match[2] or '', match[3])].add(file)
            else:
                skipped += 1
    release_cache = {}
    for (repo, path, pin), files in sorted(refs.items()):
        def action(repo=repo, path=path, pin=pin, files=files):
            if repo not in release_cache:
                release_cache[repo] = action_release(client, repo)
            release = release_cache[repo]
            latest, result = ('No stable release/tag', 'Review custom/fork reference manually') if release is None else (
                f'[{release[0]}]({release[1]})', action_status(pin, release[0]))
            actions.append((repo + path, pin, latest, result, ', '.join(sorted(files))))
        check('Action ' + repo + path + '@' + pin, action)

    text = markdown(tools, 'Apple, Android and Microsoft toolchains') + '\n' + markdown(actions, 'GitHub Actions')
    text += ('\nApple SDKs are mapped from the selected Xcode release, not deployment minimums. '
             'Visual Studio major and runner labels do not pin an installed compiler patch. '
             'A newer release is informational and does not establish runner or build compatibility. '
             'Commit-pinned forks require manual review; replacing them may lose patches.\n')
    text += f'\nAction coverage: {len(refs)} distinct external references; {skipped} local/Docker references excluded.\n'
    if errors:
        text += '\n### Toolchain/action checks that failed\n\n' + '\n'.join('- ' + e.replace('\n', ' ') for e in errors) + '\n'
    rows = tools + actions
    return {'markdown': text, 'checks': len(rows), 'errors': len(errors),
            'updates': sum(row[3] == 'Update available' for row in rows)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    print(json.dumps(collect(args.root.resolve(), Client())))


if __name__ == '__main__':
    main()
