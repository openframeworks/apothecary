import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('checker', Path(__file__).parents[1] / 'check-upstream-versions.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


class VersionChecks(unittest.TestCase):
    def test_stable_tags_only(self):
        for value in ['v1.2.3-rc1', 'v1.2.3-beta', 'master', 'deadbeef', 'v1.2.3-dev']:
            self.assertIsNone(checker.version(value, r'v?(\d+(?:\.\d+)+)'))
        self.assertGreater(checker.version('1.10'), checker.version('1.9.9'))
        self.assertEqual(checker.version('1.2'), checker.version('1.2.0'))

    def test_project_tag_formats(self):
        self.assertEqual(checker.version('VER-2-14-3', r'VER-(\d+(?:-\d+)+)'), (2, 14, 3, 0))
        self.assertEqual(checker.version('curl-8_22_0', r'curl-(\d+(?:_\d+)+)'), (8, 22, 0, 0))

    def test_prereleases_drafts_and_semantic_order(self):
        entry = dict(repo='owner/project', pattern=r'v?(\d+(?:\.\d+)+)')
        data = [dict(tag_name='v2.0.0', prerelease=True), dict(tag_name='v3.0.0', draft=True),
                dict(tag_name='v1.9.0', html_url='https://example.com/1.9'),
                dict(tag_name='v1.10.0', html_url='https://example.com/1.10')]
        with patch.object(checker, 'api', return_value=data):
            choices = list(checker.candidates(entry))
        self.assertEqual(max(choices, key=lambda row: checker.version(row[0], entry['pattern']))[0], 'v1.10.0')

    def test_release_pagination_includes_older_pages(self):
        entry = dict(repo='owner/project', pattern=r'v?(\d+(?:\.\d+)+)')
        page = [dict(tag_name='v1.0.0', html_url='https://example.com/1')] * 100
        with patch.object(checker, 'api', side_effect=[page, [dict(tag_name='v2.0.0', html_url='https://example.com/2')]]) as api:
            choices = list(checker.candidates(entry))
            self.assertIn(('v2.0.0', 'https://example.com/2'), choices)
            self.assertIn('page=2', api.call_args.args[0])

    def test_formula_is_read_without_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'formula.sh').write_text('VER="1.2.3"\nexit 99\n')
            with patch.object(checker, 'ROOT', root):
                self.assertEqual(checker.current(dict(formula='formula.sh')), ('1.2.3', (1, 2, 3, 0)))
                (root / 'formula.sh').write_text('VER=$(exit 99)\n')
                with self.assertRaises(ValueError):
                    checker.current(dict(formula='formula.sh'))

    def test_tag_fallback_and_link(self):
        entry = dict(repo='owner/project', pattern=r'v?(\d+(?:\.\d+)+)')
        with patch.object(checker, 'api', side_effect=[[], [dict(name='v1.2.0'), dict(name='v9.0.0-rc1')]]):
            self.assertEqual(list(checker.candidates(entry)), [('v1.2.0', 'https://github.com/owner/project/tree/v1.2.0')])

    def test_gitlab_release_link_fallback(self):
        entry = dict(repo='cairo/cairo', provider='gitlab', pattern=r'(\d+(?:\.\d+)+)')
        with patch.object(checker, 'api', return_value=[dict(tag_name='1.18.4')]):
            self.assertEqual(list(checker.candidates(entry))[0][1], 'https://gitlab.freedesktop.org/cairo/cairo/-/tags/1.18.4')

    def test_numeric_development_series_are_excluded(self):
        entry = dict(repo='gstreamer/gstreamer', provider='gitlab',
                     pattern=r'(\d+(?:\.\d+)+)', even_components=[1])
        with patch.object(checker, 'api', return_value=[dict(tag_name='1.29.2'), dict(tag_name='1.28.2')]):
            self.assertEqual([tag for tag, _ in checker.candidates(entry)], ['1.28.2'])
        entry['even_components'] = [1, 2]
        self.assertIsNone(checker.stable_version(entry, '1.18.3'))
        self.assertIsNotNone(checker.stable_version(entry, '1.18.4'))

    def test_official_archive_filters_release_candidates_and_signatures(self):
        entry = dict(provider='archive', url='https://archive.mesa3d.org/',
                     pattern=r'(\d+(?:\.\d+)+)', filename_pattern=r'mesa-(\d+\.\d+\.\d+)\.tar\.xz')
        index = '<a href="mesa-26.2.4.tar.xz">release</a><a href="mesa-27.0.0-rc1.tar.xz">rc</a><a href="mesa-26.2.4.tar.xz.sig">sig</a>'
        with patch.object(checker, 'archive_index', return_value=index):
            self.assertEqual(list(checker.candidates(entry)), [('26.2.4', 'https://archive.mesa3d.org/mesa-26.2.4.tar.xz')])

    def test_failed_check_is_reported(self):
        entry = dict(name='example', repo='owner/project', formula='unused', pattern='unused')
        with patch.object(checker, 'current', return_value=('1.0', (1, 0, 0, 0))), patch.object(checker, 'candidates', side_effect=RuntimeError('HTTP 503')):
            results, errors, skipped = checker.check([entry])
        self.assertFalse(results)
        self.assertIn('HTTP 503', checker.report(results, errors, skipped))

    def test_failure_cannot_close_issue(self):
        issue = dict(number=17, body=checker.MARKER)
        with patch.object(checker, 'api', side_effect=[[issue], {}]) as api:
            checker.publish('owner/project', 'failure report', False, True)
            self.assertEqual(api.call_args.args[1], {'body': 'failure report'})

    def test_clean_check_closes_issue(self):
        issue = dict(number=17, body=checker.MARKER)
        with patch.object(checker, 'api', side_effect=[[issue], {}]) as api:
            checker.publish('owner/project', 'clean report', False, False)
            self.assertEqual(api.call_args.args[1], {'state': 'closed'})

    def test_unchanged_report_does_not_write(self):
        issue = dict(number=17, body=checker.MARKER + '\nreport')
        with patch.object(checker, 'api', return_value=[issue]) as api:
            checker.publish('owner/project', issue['body'], True, False)
            self.assertEqual(api.call_count, 1)


if __name__ == '__main__':
    unittest.main()
