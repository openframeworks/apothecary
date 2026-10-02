#!/usr/bin/env python3
"""Report newer stable releases; optionally maintain one tracking issue."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
MARKER = '<!-- apothecary-upstream-versions -->'
TITLE = 'Apothecary libraries have newer upstream releases'


def api(path, payload=None, method=None, gitlab=False):
    host = 'https://gitlab.freedesktop.org/api/v4/' if gitlab else 'https://api.github.com/'
    headers = {'User-Agent': 'apothecary-upstream-versions', 'Accept': 'application/json'}
    token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
    if token and not gitlab:
        headers['Authorization'] = 'Bearer ' + token
    data = None if payload is None else json.dumps(payload).encode()
    if data is not None:
        headers['Content-Type'] = 'application/json'
    request = urllib.request.Request(host + path, data=data, headers=headers, method=method)
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            if method == 'POST' or error.code not in (429, 500, 502, 503, 504) or attempt == 2:
                raise RuntimeError(f'{host + path}: HTTP {error.code}') from error
        except urllib.error.URLError as error:
            if method == 'POST' or attempt == 2:
                raise RuntimeError(f'{host + path}: {error.reason}') from error
        time.sleep(2 ** attempt)


def version(value, pattern=r'(\d+(?:\.\d+)+)'):
    match = re.fullmatch(pattern, value)
    if not match:
        return None
    numeric = next(group for group in match.groups() if group is not None)
    parts = tuple(int(part) for part in re.split(r'[._-]', numeric))
    return parts + (0,) * max(0, 4 - len(parts))


def stable_version(entry, tag):
    numeric = version(tag, entry['pattern'])
    if numeric and any(numeric[index] % 2 for index in entry.get('even_components', [])):
        return None
    return numeric


def archive_index(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'apothecary-upstream-versions'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return response.read(2_000_001).decode('utf-8')
    except urllib.error.URLError as error:
        raise RuntimeError(f'{url}: {error.reason}') from error


def current(entry):
    text = (ROOT / entry['formula']).read_text()
    variable = entry.get('variable', 'VER')
    match = re.search(r'^' + re.escape(variable) + r'=[\"\']?([^\"\'\s#]+)', text, re.M)
    if not match:
        raise ValueError(f'No literal {variable} assignment')
    raw = match[1]
    numeric = version(raw, entry.get('current_pattern', r'(\d+(?:\.\d+)+)'))
    if numeric is None:
        raise ValueError(f'Unsupported pinned version: {raw}')
    return raw, numeric


def candidates(entry):
    if entry.get('provider') == 'archive':
        index = archive_index(entry['url'])
        if len(index.encode('utf-8')) > 2_000_000:
            raise ValueError('Archive index exceeds 2 MB')
        for filename in set(re.findall(r'href="([^"/]+)"', index)):
            match = re.fullmatch(entry['filename_pattern'], filename)
            if match and stable_version(entry, match[1]):
                yield match[1], urllib.parse.urljoin(entry['url'], filename)
        return
    repo = entry['repo']
    gitlab = entry.get('provider') == 'gitlab'
    prefix = 'projects/' + urllib.parse.quote(repo, safe='') if gitlab else 'repos/' + repo
    releases = []
    # Walk all release pages: API ordering is not semantic version ordering.
    for page in range(1, 101):
        batch = api(f'{prefix}/releases?per_page=100&page={page}', gitlab=gitlab)
        releases.extend(item for item in batch if not item.get('prerelease') and not item.get('draft')
                        and not item.get('upcoming_release'))
        if len(batch) < 100:
            break
    else:
        raise ValueError('Release pagination exceeded 100 pages')
    releases = [item for item in releases if stable_version(entry, item['tag_name'])]
    if releases:
        for item in releases:
            url = item.get('html_url') or item.get('_links', {}).get('self')
            if not url:
                url = f'https://gitlab.freedesktop.org/{repo}/-/tags/{urllib.parse.quote(item["tag_name"], safe="")}'
            yield item['tag_name'], url
        return
    # Projects without GitHub Releases still publish stable version tags.
    for page in range(1, 101):
        batch = api(f'{prefix}/repository/tags?per_page=100&page={page}' if gitlab
                    else f'{prefix}/tags?per_page=100&page={page}', gitlab=gitlab)
        for item in batch:
            tag = item['name']
            if stable_version(entry, tag):
                url = (f'https://gitlab.freedesktop.org/{repo}/-/tags/' if gitlab
                       else f'https://github.com/{repo}/tree/') + urllib.parse.quote(tag, safe='')
                yield tag, url
        if len(batch) < 100:
            return
    raise ValueError('Tag pagination exceeded 100 pages')


def check(entries):
    results, errors, skipped = [], [], []
    for entry in entries:
        if 'skip' in entry:
            skipped.append((entry['name'], entry['skip']))
            continue
        print('Checking ' + entry['name'], file=sys.stderr, flush=True)
        try:
            pinned, pinned_version = current(entry)
            available = list(candidates(entry))
            if not available:
                raise ValueError('No matching stable upstream release tags')
            tag, url = max(available, key=lambda item: version(item[0], entry['pattern']))
            results.append((entry['name'], pinned, tag, url,
                            version(tag, entry['pattern']) > pinned_version))
        except (ValueError, RuntimeError, OSError, KeyError) as error:
            errors.append((entry['name'], str(error)))
    return results, errors, skipped


def report(results, errors, skipped):
    rows = [row for row in results if row[-1]]
    body = [MARKER, '', 'A scheduled check compared formula pins with upstream stable releases.',
            'A newer release may require a different supported branch, patches, checksums or platform changes.',
            'This report does not change formulas.', '', '| Library | Pinned | Latest stable upstream |',
            '| --- | --- | --- |']
    body.extend(f'| {name} | {pin} | [{tag}]({url}) |' for name, pin, tag, url, _ in rows)
    if not rows:
        body.append('| — | — | No newer releases detected among successful checks |')
    if errors:
        body += ['', '### Checks that failed', '']
        body.extend(f'- {name}: {error}' for name, error in errors)
    body += ['', '<details><summary>Coverage and exclusions</summary>', '',
             f'{len(results)} successful checks; {len(errors)} failed; {len(skipped)} explicitly excluded.', '']
    body.extend(f'- {name}: {reason}' for name, reason in skipped)
    body += ['', '</details>', '', 'Workflow: `.github/workflows/upstream-versions.yml`.']
    return '\n'.join(body) + '\n'


def publish(repository, body, has_updates, has_errors):
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', repository):
        raise ValueError('A valid owner/repository is required for --file-issue')
    existing = []
    page = 1
    while True:
        batch = api(f'repos/{repository}/issues?state=open&per_page=100&page={page}')
        existing.extend(issue for issue in batch if not issue.get('pull_request')
                        and MARKER in (issue.get('body') or ''))
        if len(batch) < 100:
            break
        page += 1
    if len(existing) > 1:
        raise ValueError('Multiple tracking issues found; refusing to edit an arbitrary issue')
    if has_updates or has_errors:
        if existing:
            issue = existing[0]
            if issue['body'] != body:
                api(f'repos/{repository}/issues/{issue["number"]}', {'body': body}, 'PATCH')
        else:
            api(f'repos/{repository}/issues', {'title': TITLE, 'body': body}, 'POST')
    elif existing:
        # Never close the report when one or more upstream checks failed.
        api(f'repos/{repository}/issues/{existing[0]["number"]}', {'state': 'closed'}, 'PATCH')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--file-issue', action='store_true', help='Create/update/close the tracking issue')
    parser.add_argument('--repository', default=os.environ.get('GITHUB_REPOSITORY', ''))
    parser.add_argument('--only', nargs='+', help='Read-only check of selected library names')
    args = parser.parse_args()
    if args.only and args.file_issue:
        parser.error('--only cannot maintain the full tracking issue')
    entries = json.loads((ROOT / 'scripts/upstream-versions.json').read_text())
    tracked = subprocess.check_output(['git', 'ls-files', 'apothecary/formulas/*.sh'], cwd=ROOT, text=True)
    formulas = {path for path in tracked.splitlines() if re.search(r'^FORMULA_TYPES=', (ROOT / path).read_text(), re.M)}
    configured = {entry['formula'] for entry in entries}
    if formulas != configured or len(configured) != len(entries):
        raise ValueError(f'Registry must cover each formula once: missing={sorted(formulas-configured)}, stale={sorted(configured-formulas)}')
    if args.only:
        entries = [entry for entry in entries if entry['name'] in args.only]
        if {entry['name'] for entry in entries} != set(args.only):
            parser.error('Unknown library in --only')
    results, errors, skipped = check(entries)
    body = report(results, errors, skipped)
    print(body)
    summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if summary:
        with open(summary, 'a') as output:
            output.write(body)
    if args.file_issue:
        publish(args.repository, body, any(row[-1] for row in results), bool(errors))
    return bool(errors)


if __name__ == '__main__':
    sys.exit(main())
