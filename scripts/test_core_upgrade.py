#!/usr/bin/env python3
"""Exercise a real frozen 0.15 installation through 0.16 replacement paths."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import time
import unittest

from test_core_compact import Fixture, SOURCE, digest, field

ARCHIVE = Path(__file__).resolve().parent / 'fixtures/p2t2c-0.15.0-release-roots.tar.gz'
ARCHIVE_SHA256 = '258735e9f92a321e148a3a83af4503194f5709f815ecbb8c971572cac480e52f'


class UpgradeTests(Fixture):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='p2t2c-v015-upgrade-')
        self.base = Path(self.temp.name)
        self.assertEqual(digest(ARCHIVE), ARCHIVE_SHA256)
        frozen = self.base / 'frozen';frozen.mkdir()
        with tarfile.open(ARCHIVE) as archive:
            for member in archive.getmembers():
                self.assertFalse(Path(member.name).is_absolute())
                self.assertNotIn('..', Path(member.name).parts)
                self.assertTrue(member.isfile() or member.isdir())
            archive.extractall(frozen)
        manifest = (SOURCE / '.p2t2c/manifest.yaml').read_text()
        release_name = 'P2T2C_CN' if 'language: "zh-CN"' in manifest else 'P2T2C_EN'
        self.old = frozen / release_name
        self.root = self.base / 'project';self.root.mkdir()
        self.command(['bash', str(self.old / '.p2t2c/bin/p2t2c_install.sh'), '--apply', '--target', str(self.root)])
        self.cli = self.root / '.p2t2c/bin/p2t2c'
        self.assertEqual((self.root / '.p2t2c/VERSION').read_text().strip(), '0.15.0')

    def command(self, args, code=0, cwd=None, env=None):
        result = subprocess.run(args, cwd=cwd or self.root, env={**os.environ, **(env or {})},
                                text=True, capture_output=True, timeout=180)
        self.assertEqual(result.returncode, code, (args, result.stdout[-5000:], result.stderr[-5000:]))
        return result

    def old_active_work(self):
        identity = 'SP-20261109-existing-v1';spec = '001-existing-v1'
        directory = self.root / 'docs/specs' / spec;directory.mkdir()
        for template, output in [('SP_TEMPLATE.md', self.root / 'docs/proposals' / (identity + '.md')),
                                 ('design.md', directory / 'design.md'), ('tasks.md', directory / 'tasks.md')]:
            text = (self.root / '.p2t2c/templates/core' / template).read_text()
            text = text.replace('SP-YYYYMMDD-short-title', identity).replace('NNN-short-title', spec)
            if template == 'design.md':text = field(text, 'status', 'ready')
            if template == 'tasks.md':
                text = field(text, 'status', 'in_progress').replace('- [ ]', '- [x]')
                text = text.replace('Summary: pending', 'Summary: Existing v1 result checked.')
            output.write_text(text)
        return identity, spec

    def upgrade(self):
        before = {p for p in (self.root / '.p2t2c/upgrade').glob('*') if p.is_dir()} if (self.root / '.p2t2c/upgrade').exists() else set()
        self.command(['bash', str(SOURCE / '.p2t2c/bin/p2t2c_upgrade.sh'), '--apply', '--source', str(SOURCE)])
        self.assertEqual((self.root / '.p2t2c/VERSION').read_text().strip(), '0.16.0-rc.1')
        created = {p for p in (self.root / '.p2t2c/upgrade').glob('*') if p.is_dir()} - before
        self.assertEqual(len(created), 1)
        return created.pop()

    def test_upgrade_preserves_project_records_and_finishes_old_work(self):
        identity, spec = self.old_active_work()
        custom = self.root / 'docs/sot/product';custom.mkdir()
        (custom / 'OWNED.md').write_text('# Project-owned rule\n')
        (self.root / 'AGENTS.md').write_text('Project-owned entry point.\n')
        protected = [self.root / '.p2t2c/project_config.yaml', custom / 'OWNED.md', self.root / 'AGENTS.md',
                     self.root / 'docs/proposals' / (identity + '.md'),
                     self.root / 'docs/specs' / spec / 'design.md', self.root / 'docs/specs' / spec / 'tasks.md']
        before = {str(p): p.read_bytes() for p in protected}
        self.upgrade()
        self.assertEqual({str(p): p.read_bytes() for p in protected}, before)
        self.run_cli('validate-docs')
        self.assertEqual(self.run_cli('archive', '--spec', spec)['state'], 'completed')
        compact_id, _ = self.compact(ready=True)
        self.run_cli('archive', '--proposal', compact_id)
        self.run_cli('validate-docs')

    def test_supported_downgrade_and_rollback_reject_completed_compact(self):
        operation = self.upgrade()
        identity, path = self.compact(ready=True)
        self.run_cli('archive', '--proposal', identity)
        before = self.snapshot()
        for args in [
            ['--dry-run', '--source', str(self.old)],
            ['--apply', '--source', str(self.old)],
            ['--rollback', str(operation)],
        ]:
            result = subprocess.run(['bash', str(SOURCE / '.p2t2c/bin/p2t2c_upgrade.sh'), *args],
                                    cwd=self.root, text=True, capture_output=True, timeout=180)
            self.assertNotEqual(result.returncode, 0, result.stdout[-2000:])
            self.assertIn(identity, result.stdout + result.stderr)
            self.assertEqual(self.snapshot(), before)
        self.assertIn('work_status: completed', path.read_text())

    def test_supported_rollback_restores_v015_and_keeps_project_work(self):
        identity, spec = self.old_active_work()
        invalid = self.root / '.p2t2c/upgrade/empty';invalid.mkdir(parents=True)
        before_invalid = self.snapshot()
        result = subprocess.run(['bash', str(SOURCE / '.p2t2c/bin/p2t2c_upgrade.sh'), '--rollback', str(invalid)],
                                cwd=self.root, text=True, capture_output=True, timeout=30)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('rollback transaction inventory', result.stdout + result.stderr)
        self.assertEqual(before_invalid, self.snapshot())
        original = self.snapshot()
        operation = self.upgrade()
        self.command(['bash', str(SOURCE / '.p2t2c/bin/p2t2c_upgrade.sh'), '--rollback', str(operation)])
        self.assertEqual((self.root / '.p2t2c/VERSION').read_text().strip(), '0.15.0')
        after = self.snapshot()
        for path, expected in original.items():
            self.assertEqual(after.get(path), expected, path)
        self.assertFalse((self.root / '.p2t2c/lib/P2T2C/DocumentActions.pm').exists())
        self.run_cli('archive', '--spec', spec)

    def test_runtime_lock_serializes_documents_and_releases_on_signal(self):
        script = self.base / 'p2t2c_upgrade.sh'
        marker = self.base / 'child.pid'
        script.write_text('#!/bin/bash\nprintf "%s\\n" "$$" > "' + str(marker) + '"\nsleep 2\n')
        guard = SOURCE / '.p2t2c/bin/p2t2c_runtime_guard.pl'
        proc = subprocess.Popen(['perl', str(guard), str(self.root), str(SOURCE), str(script)],
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        deadline = time.monotonic() + 10
        while not marker.exists() and proc.poll() is None and time.monotonic() < deadline:time.sleep(0.02)
        self.assertTrue(marker.exists())
        result = self.command([str(SOURCE / '.p2t2c/bin/p2t2c'), 'create', '--id', 'SP-20261109-locked', '--json'], code=4)
        self.assertIn('another document mutation', result.stdout)
        proc.terminate();stdout, stderr = proc.communicate(timeout=15)
        self.assertEqual(proc.returncode, 143, (stdout, stderr))
        self.assertFalse((self.root / '.p2t2c/.documents-lock').exists())
        child = int(marker.read_text())
        with self.assertRaises(ProcessLookupError):os.kill(child, 0)


if __name__ == '__main__':
    result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(UpgradeTests))
    raise SystemExit(0 if result.wasSuccessful() else 1)
