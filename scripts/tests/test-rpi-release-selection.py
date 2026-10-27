#!/usr/bin/env python3
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import unittest

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rpi', ROOT / 'scripts/select-rpi-release.py')
rpi = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rpi)
MATRIX = {'include': [{'arch': arch} for arch in ('armv6l', 'armv7l', 'aarch64')]}


class Selection(unittest.TestCase):
    def publish(self, **overrides):
        args = dict(arch='armv6l', publish=True, event='workflow_dispatch',
                    repository='openframeworks/apothecary', ref='refs/heads/bleeding')
        args.update(overrides)
        return rpi.select(MATRIX, **args)

    def test_default_and_architecture_selection(self):
        selected, publish = rpi.select(MATRIX)
        self.assertEqual(selected, MATRIX)
        self.assertFalse(publish)
        for arch in ('armv6l', 'armv7l', 'aarch64'):
            selected, publish = rpi.select(MATRIX, arch)
            self.assertEqual(selected['include'], [{'arch': arch}])
            self.assertFalse(publish)

    def test_manual_publication_only_selects_armv6(self):
        for ref in ('refs/heads/bleeding', 'refs/heads/master', 'refs/tags/v0.12.2'):
            selected, publish = self.publish(ref=ref)
            self.assertTrue(publish)
            self.assertEqual(selected['include'], [{'arch': 'armv6l'}])

    def test_diagnostics_can_be_selected_with_publication(self):
        self.assertTrue(self.publish(pi_zero_test=True)[1])
        self.assertFalse(rpi.select(MATRIX, 'armv6l', pi_zero_test=True)[1])

    def test_reject_invalid_publication_requests(self):
        for args in ({'arch': 'all'}, {'arch': 'armv7l'}, {'arch': 'aarch64'},
                     {'event': 'pull_request'}, {'event': 'push'},
                     {'repository': 'owner/fork'}, {'ref': 'refs/heads/feature'},
                     {'ref': 'refs/pull/679/merge'}):
            with self.subTest(args=args), self.assertRaises(ValueError):
                self.publish(**args)

    def test_empty_plan_and_invalid_diagnostic_selection(self):
        with self.assertRaises(ValueError):
            rpi.select({'include': []}, 'armv6l')
        with self.assertRaises(ValueError):
            rpi.select(MATRIX, 'all', pi_zero_test=True)
        with self.assertRaises(ValueError):
            rpi.select(MATRIX, 'unknown')

    def test_automatic_and_manual_release_policy(self):
        for event, repo, ref, manual, expected in (
                ('push', 'openframeworks/apothecary', 'refs/heads/bleeding', False, True),
                ('push', 'openframeworks/apothecary', 'refs/heads/master', False, True),
                ('push', 'openframeworks/apothecary', 'refs/tags/v0.12.2', False, True),
                ('push', 'owner/fork', 'refs/heads/bleeding', False, False),
                ('push', 'openframeworks/apothecary', 'refs/heads/feature', False, False),
                ('pull_request', 'openframeworks/apothecary', 'refs/pull/679/merge', True, False),
                ('workflow_dispatch', 'openframeworks/apothecary', 'refs/heads/bleeding', False, False),
                ('workflow_dispatch', 'openframeworks/apothecary', 'refs/heads/bleeding', True, True)):
            self.assertEqual(rpi.publication_allowed(event, repo, ref, manual), expected)

    def test_actual_workflow_publication_guards(self):
        workflow = ROOT / '.github/workflows/build-linux-rpi.yml'
        config = json.loads(subprocess.check_output([
            'ruby', '-ryaml', '-rjson', '-e',
            'puts JSON.generate(YAML.load_file(ARGV[0]))', str(workflow)], text=True))
        trigger = config.get('on', config.get('true'))  # YAML 1.1 treats `on` as true.
        self.assertFalse(trigger['workflow_dispatch']['inputs']['publish_armv6l']['default'])
        jobs = config['jobs']
        self.assertIn('steps.select.outputs.manual_publish', jobs['pre-check']['outputs']['manual_publish'])
        build = jobs['build-linux-rpi']
        self.assertNotIn('PUBLISH_RELEASE', build['env'])
        self.assertIn('steps.select.outputs.publish_release', jobs['pre-check']['outputs']['publish_release'])
        steps = build['steps']
        by_name = {step.get('name'): step for step in steps}
        for name in ('Update Release', 'Package modular libraries', 'Upload modular libraries'):
            self.assertEqual(by_name[name]['if'], "needs.pre-check.outputs.publish_release == 'true'")
        names = [step.get('name') for step in steps]
        self.assertLess(names.index('Require Pi Zero runtime compatibility'), names.index('Update Release'))
        self.assertNotIn('continue-on-error', by_name['Require Pi Zero runtime compatibility'])
        self.assertIn('exit 1', by_name['Require Pi Zero runtime compatibility']['run'])
        self.assertIn("github.event_name == 'push'", by_name['Record final release outputs']['if'])
        self.assertTrue(by_name['Update Release']['with']['fail_on_unmatched_files'])


if __name__ == '__main__':
    unittest.main()
