#!/usr/bin/env python3
"""Select a Raspberry Pi build and validate explicit ARMv6 publication."""
import json
import os


def publication_allowed(event, repository, ref, manual_publish):
    release_ref = ref in ('refs/heads/bleeding', 'refs/heads/master') or ref.startswith('refs/tags/')
    return (repository == 'openframeworks/apothecary' and release_ref and
            (event == 'push' or (event == 'workflow_dispatch' and manual_publish)))


def select(matrix, arch='all', pi_zero_test=False, publish=False,
           event='', repository='', ref=''):
    if arch not in ('all', 'armv6l', 'armv7l', 'aarch64'):
        raise ValueError('Unknown Raspberry Pi architecture: ' + arch)
    if pi_zero_test and arch != 'armv6l':
        raise ValueError('Pi Zero diagnostics require arch=armv6l')
    if publish:
        if event != 'workflow_dispatch' or arch != 'armv6l':
            raise ValueError('Manual ARMv6 publication requires workflow_dispatch and arch=armv6l')
        if repository != 'openframeworks/apothecary':
            raise ValueError('Release publication requires the upstream repository')
        if ref not in ('refs/heads/bleeding', 'refs/heads/master') and not ref.startswith('refs/tags/'):
            raise ValueError('Publish from bleeding, master or a release tag after merging the PR')
    rows = matrix['include']
    if arch != 'all':
        rows = [row for row in rows if row['arch'] == arch]
    if not rows:
        raise ValueError('Requested architecture is absent from the build plan')
    return {**matrix, 'include': rows}, publish


def main():
    matrix, publish = select(
        json.loads(os.environ['BUILD_MATRIX']), os.environ.get('RPI_ARCH', 'all'),
        os.environ.get('PI_ZERO_TEST') == 'true', os.environ.get('PUBLISH_ARMV6L') == 'true',
        os.environ.get('GITHUB_EVENT_NAME', ''), os.environ.get('GITHUB_REPOSITORY', ''),
        os.environ.get('GITHUB_REF', ''))
    with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
        output.write('matrix=' + json.dumps(matrix) + '\n')
        output.write('manual_publish=' + str(publish).lower() + '\n')
        allowed = publication_allowed(os.environ.get('GITHUB_EVENT_NAME', ''),
                                      os.environ.get('GITHUB_REPOSITORY', ''),
                                      os.environ.get('GITHUB_REF', ''), publish)
        output.write('publish_release=' + str(allowed).lower() + '\n')


if __name__ == '__main__':
    main()
