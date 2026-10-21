"""Personal bar integrations preserve layout while using honest payload identity."""
import json
import subprocess
import unittest
import test_shibumi_suite as fixture
from shibumi_suite.cli import command_install, command_repair, command_status, load_install_state, command_activate, command_deactivate, command_uninstall
from shibumi_suite.model import plugin_payload_digest
from shibumi_suite.admission import preflight_lifecycle_state
from shibumi_suite.model import Suite
from pathlib import Path


class PersonalLifecycleTests(unittest.TestCase):
    setUp = fixture.SuiteLifecycleTests.setUp
    tearDown = fixture.SuiteLifecycleTests.tearDown
    args = staticmethod(fixture.SuiteLifecycleTests.args)
    install = fixture.SuiteLifecycleTests.install

    def test_user_layout_install_allows_independent_calendar(self):
        command_install(self.args(user_layout=True), self.suite, self.paths, self.runtime)
        config = json.loads(self.paths.config_file.read_text())
        config['bar']['layout']['center'] = [{'id': 'local.calendar', 'format': 'HH:mm'}]
        self.paths.config_file.write_text(json.dumps(config))
        self.assertEqual(command_status(self.suite, self.paths), 0)

    def test_repair_retains_custom_layout_and_replaces_dirty_payload(self):
        self.install()
        config = json.loads(self.paths.config_file.read_text())
        config['bar']['layout']['center'] = [{'id': 'local.calendar', 'format': 'HH:mm'}]
        config['bar']['centerAnchor'] = 'local.calendar'
        config['plugins'].append({'id': 'local.custom', 'secret': 'fixture-only'})
        self.paths.config_file.write_text(json.dumps(config))
        bar = self.paths.plugin_dir / 'hancore.shibumi.bar'
        (bar / 'Bar.qml').write_text((bar / 'Bar.qml').read_text() + '\n// local drift\n')
        command_repair(self.args(keep_layout=True), self.suite, self.paths, self.runtime)
        result = json.loads(self.paths.config_file.read_text())
        self.assertEqual(result['bar'], config['bar'])
        self.assertIn({'id': 'local.custom', 'secret': 'fixture-only'}, result['plugins'])
        state = load_install_state(self.paths, self.suite)
        self.assertEqual(plugin_payload_digest(bar), state['pluginDigests']['hancore.shibumi.bar'])
        self.assertEqual(command_status(self.suite, self.paths), 0)

    def test_user_layout_survives_lifecycle_without_stale_payload(self):
        command_install(self.args(user_layout=True), self.suite, self.paths, self.runtime)
        command_deactivate(self.args(), self.suite, self.paths, self.runtime)
        command_activate(self.args(user_layout=True), self.suite, self.paths, self.runtime)
        config = json.loads(self.paths.config_file.read_text())
        config['bar']['layout']['center'] = [{'id': 'local.calendar'}]
        self.paths.config_file.write_text(json.dumps(config))
        self.assertEqual(command_status(self.suite, self.paths), 0)
        command_uninstall(self.args(), self.suite, self.paths, self.runtime)
        self.assertFalse((self.paths.plugin_dir / 'hancore.shibumi.bar').exists())
        self.assertEqual(json.loads(self.paths.config_file.read_text())['customRoot'], {'preserve': True})

    def test_upstream_dirty_payload_is_admitted_only_for_backed_up_repair(self):
        original = self.root / 'upstream'
        subprocess.run(['git', 'clone', '-q', '--no-checkout', str(Path(__file__).resolve().parents[1]), str(original)], check=True)
        subprocess.run(['git', '-C', str(original), 'checkout', '-q', '--detach', '7a6c853b1947d303bad9a5b640c224c01b669106'], check=True)
        upstream = Suite.load(original)
        command_install(self.args(), upstream, self.paths, self.runtime)
        bar = self.paths.plugin_dir / 'hancore.shibumi.bar' / 'Bar.qml'
        bar.write_text(bar.read_text() + '\n// preserved historical override\n')
        subprocess.run(['git', 'init', '-q', str(self.source)], check=True)
        subprocess.run(['git', '-C', str(self.source), 'add', '.'], check=True)
        subprocess.run(['git', '-C', str(self.source), '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'fixture'], check=True)
        preflight_lifecycle_state(self.paths, self.suite, allow_payload_repair=True)
        command_repair(self.args(keep_layout=True), self.suite, self.paths, self.runtime)
        preflight_lifecycle_state(self.paths, self.suite)
        archived = list((self.paths.state_dir / 'backups').rglob('Bar.qml'))
        self.assertTrue(any('preserved historical override' in p.read_text() for p in archived))


if __name__ == '__main__':
    unittest.main()
