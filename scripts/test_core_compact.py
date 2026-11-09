#!/usr/bin/env python3
"""Outcome, compatibility, and fault tests for standard v1 and compact v2."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
import unittest

PARSER = argparse.ArgumentParser()
PARSER.add_argument('release_root', type=Path)
PARSER.add_argument('--suite', choices=['all', 'contract', 'security', 'transaction'], default='all')
ARGS = PARSER.parse_args()
SOURCE = ARGS.release_root.resolve()


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def field(text, key, value):
    result, count = re.subn(r'^' + re.escape(key) + r':[^\r\n]*', key + ': ' + value, text, count=1, flags=re.M)
    if count != 1:
        raise AssertionError('fixture field is absent: ' + key)
    return result


class Fixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='p2t2c-compact-test-')
        self.root = Path(self.temp.name)
        runtime_names = {'runs', 'cache', 'install', 'upgrade', 'docs-migrate', 'documents', 'prepared', '.documents-lock'}
        shutil.copytree(SOURCE / '.p2t2c', self.root / '.p2t2c',
                        ignore=lambda directory, names: runtime_names.intersection(names)
                        if Path(directory) == SOURCE / '.p2t2c' else set())
        shutil.copytree(SOURCE / 'docs/sot', self.root / 'docs/sot')
        for directory in ['docs/proposals', 'docs/specs']:
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        self.cli = self.root / '.p2t2c/bin/p2t2c'

    def tearDown(self):
        self.temp.cleanup()

    def run_cli(self, *args, code=0, env=None):
        proc = subprocess.run([str(self.cli), *args, '--json'], cwd=self.root,
                              env={**os.environ, **(env or {})}, text=True, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, code, (args, proc.stdout, proc.stderr))
        self.assertNotIn('Use of uninitialized', proc.stderr)
        self.assertNotIn('Wide character', proc.stderr)
        return json.loads(proc.stdout) if proc.stdout else None

    def compact(self, slug='sample', ready=False):
        identity = 'SP-20261109-' + slug
        out = self.run_cli('create', '--id', identity, '--shape', 'compact')
        path = self.root / out['record']
        if ready:
            text = field(path.read_text(), 'work_status', 'in_progress')
            text = text.replace('Known blockers: present', 'Known blockers: none')
            text = text.replace('Summary: pending', 'Summary: Fixture outcome checked.')
            path.write_text(text)
        return identity, path

    def snapshot(self, root=None):
        root = root or self.root
        return {str(p.relative_to(root)): (digest(p), p.stat().st_mode & 0o777)
                for p in root.rglob('*') if p.is_file() and not p.is_symlink()}

    def standard_ready(self, identity, risk='R1'):
        args = ['create', '--id', identity]
        truth = 'docs/sot/governance/P2T2C_GOVERNANCE.md'
        if risk == 'R2':
            args += ['--risk', risk, '--truth-ref', truth]
        out = self.run_cli(*args)
        proposal = self.root / out['proposal']
        if risk == 'R2':
            text = proposal.read_text()
            for key, value in [('status', 'approved'), ('decision', 'approved'),
                               ('decision_ref', 'user:fixture'), ('truth_digest', digest(self.root / truth))]:
                text = field(text, key, value)
            proposal.write_text(text)
        design = self.root / out['design']
        design.write_text(field(design.read_text(), 'status', 'ready'))
        tasks = self.root / out['tasks']
        text = field(tasks.read_text(), 'status', 'in_progress').replace('- [ ]', '- [x]')
        tasks.write_text(text.replace('Summary: pending', 'Summary: Fixture outcome checked.'))
        return out

    def prepare(self, identity, source, spec='101-expanded', risk='R1'):
        prepared = self.root / '.p2t2c/prepared' / identity
        prepared.mkdir(parents=True)
        body = source.read_text()
        state = re.search(r'^work_status: (\w+)$', body, re.M)[1]
        source_digest = digest(source)
        for template, name in [('SP_TEMPLATE.md', 'proposal.md'), ('design.md', 'design.md'), ('tasks.md', 'tasks.md')]:
            text = (self.root / '.p2t2c/templates/core' / template).read_text()
            text = text.replace('SP-YYYYMMDD-short-title', identity).replace('NNN-short-title', spec)
            if name == 'proposal.md' and risk == 'R2':
                for key, value in [('risk', 'R2'), ('status', 'proposed'), ('decision', 'pending'),
                                   ('truth_ref', 'docs/sot/product/NEW.md')]:
                    text = field(text, key, value)
            if name == 'tasks.md':
                text = field(text, 'status', state)
                # Preserve facts, while giving standard one explicit obligation.
                for label in ['Tests', 'Verify', 'Known blockers', 'Dangerous operations', 'Authorization ref', 'Summary']:
                    value = re.search(r'^- ' + label + r': (.+)$', body, re.M)[1]
                    text = re.sub(r'^- ' + label + r': .+$', '- ' + label + ': ' + value, text, flags=re.M)
                task_section = re.search(r'^## (?:Tasks|任务)\n(.*?)(?=^## |\Z)', body, re.M | re.S)
                if task_section:
                    text = re.sub(r'(^## (?:Tasks|任务)\n).*?(?=^## |\Z)',
                                  lambda m: m[1] + task_section[1], text, count=1, flags=re.M | re.S)
                text += '\nEvidence retained: fixture://original-check\n'
            (prepared / name).write_text(text)
        (prepared / 'source.sha256').write_text(source_digest + '\n')
        return str(prepared.relative_to(self.root)), source_digest

    def interrupt(self, args, stage):
        proc = subprocess.run([str(self.cli), *args, '--json'], cwd=self.root,
                              env={**os.environ, 'P2T2C_TEST_DOCUMENT_EXIT_AT': stage},
                              text=True, capture_output=True, timeout=30)
        self.assertEqual(proc.returncode, 91, (stage, proc.stdout, proc.stderr))

    def paused_archive(self, identity):
        log = self.root / 'pause.log'
        stream = log.open('w')
        proc = subprocess.Popen([str(self.cli), 'archive', '--proposal', identity, '--json'], cwd=self.root,
                                env={**os.environ, 'P2T2C_TEST_DOCUMENT_PAUSE_AT': 'before_commit',
                                     'P2T2C_TEST_DOCUMENT_PAUSE_MS': '1500'}, stdout=subprocess.PIPE,
                                stderr=stream, text=True)
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if 'P2T2C_TEST_MARKER:document_before_commit' in log.read_text():
                return proc, stream
            if proc.poll() is not None:
                break
            time.sleep(0.02)
        proc.kill(); proc.wait(); stream.close()
        self.fail('archive did not reach the controlled concurrency point: ' + log.read_text())


class ContractTests(Fixture):
    def test_compact_one_record_and_idempotent_creation(self):
        identity, path = self.compact()
        self.assertEqual(list((self.root / 'docs/specs').iterdir()), [])
        path.write_text(path.read_text() + '\nA user-owned description.\n')
        before = self.snapshot()
        out = self.run_cli('create', '--id', identity, '--shape', 'compact')
        self.assertTrue(out['idempotent'])
        self.assertEqual(out['state'], 'existing')
        self.assertEqual(self.snapshot(), before)
        self.assertNotIn('tasks', out)
        self.assertNotIn('design', out)
        self.assertEqual(out['source_digest'], digest(path))
        self.run_cli('validate-docs')

    def test_standard_default_and_pending_r2(self):
        out = self.run_cli('create', '--id', 'SP-20261109-standard')
        self.assertEqual(out['shape'], 'standard')
        self.assertEqual(out['document_schema_version'], 1)
        self.assertEqual({p.name for p in (self.root / 'docs/specs' / out['spec']).iterdir()}, {'design.md', 'tasks.md'})
        out = self.run_cli('create', '--id', 'SP-20261109-r2', '--risk', 'R2', '--truth-ref', 'docs/sot/product/NEW.md')
        text = (self.root / out['proposal']).read_text()
        self.assertIn('status: proposed', text)
        self.assertIn('decision: pending', text)
        self.assertFalse((self.root / 'docs/sot/product/NEW.md').exists())
        self.run_cli('archive', '--proposal', 'SP-20261109-r2', code=4)
        self.run_cli('create', '--id', 'SP-20261109-invalid', '--shape', 'compact', '--risk', 'R2', code=4)
        self.run_cli('validate-docs')

    def test_compact_completion_gates_and_not_run(self):
        identity, path = self.compact(ready=True)
        baseline = path.read_text()
        bad = [('work_status: in_progress', 'work_status: planned'), ('status: approved', 'status: proposed'),
               ('Tests: not_run', 'Tests: failed'), ('Verify: not_run', 'Verify: critical'),
               ('Known blockers: none', 'Known blockers: present'), ('Dangerous operations: none', 'Dangerous operations: pending'),
               ('Summary: Fixture outcome checked.', 'Summary: pending')]
        for old, new in bad:
            with self.subTest(new=new):
                path.write_text(baseline.replace(old, new, 1))
                before = path.read_bytes()
                self.run_cli('archive', '--proposal', identity, code=4)
                self.assertEqual(path.read_bytes(), before)
        path.write_text(baseline)
        out = self.run_cli('archive', '--proposal', identity)
        self.assertEqual(out['state'], 'completed')
        self.assertEqual(out['tests'], 'not_run')
        self.assertTrue(self.run_cli('archive', '--proposal', identity)['idempotent'])

    def test_optional_tasks_fences_and_deferral(self):
        identity, path = self.compact(ready=True)
        baseline = path.read_text()
        path.write_text(baseline + '\n```markdown\n## Tasks\n- [ ] Example only\n## Completion\n- Tests: failed\n```\n')
        self.run_cli('validate-docs', '--proposal', identity, '--ready')
        path.write_text(baseline + '\n## Tasks\n\n- [ ] Necessary unfinished work\n')
        self.run_cli('archive', '--proposal', identity, code=4)
        path.write_text(baseline + '\n## Tasks\n\n- [-] Deferred without a decision\n')
        self.run_cli('validate-docs', '--proposal', identity, code=4)
        path.write_text(baseline + '\n## Tasks\n\n- [-] Deferred with scope decision ref:user:fixture\n')
        self.run_cli('archive', '--proposal', identity)

    def test_declared_metadata_cannot_fall_back_to_legacy(self):
        identity, path = self.compact()
        path.write_text(path.read_text().removeprefix('---\n'))
        self.run_cli('validate-docs', code=4)
        self.run_cli('validate-docs', '--proposal', identity, code=4)

    def test_mixed_formats_unknown_versions_and_target_isolation(self):
        identity, path = self.compact(ready=True)
        self.run_cli('create', '--id', 'SP-20261109-standard')
        (self.root / 'docs/proposals/SP-20200101-history.md').write_text('# SP-20200101-history\n\nPreserved legacy proposal.\n')
        self.run_cli('validate-docs')
        bad = self.root / 'docs/proposals/SP-20261109-unknown.md'
        bad.write_text(path.read_text().replace(identity, 'SP-20261109-unknown').replace('schema_version: 2', 'schema_version: 99'))
        before = self.snapshot()
        self.run_cli('validate-docs', '--proposal', identity)
        self.run_cli('validate-docs', code=4)
        self.assertEqual(before, self.snapshot())
        self.run_cli('archive', '--proposal', identity)

    def test_v1_archive_json_contract(self):
        out = self.standard_ready('SP-20261109-existing')
        self.run_cli('archive', '--spec', out['spec'], '--record-digest', '0' * 64, code=4)
        result = self.run_cli('archive', '--spec', out['spec'], '--record-digest', digest(self.root / out['tasks']))
        self.assertEqual(set(result), {'schema_version', 'action', 'state', 'spec', 'tasks', 'proposal', 'design', 'tests', 'verify'})
        self.assertEqual(result['schema_version'], 1)
        self.assertTrue(self.run_cli('archive', '--spec', out['spec'])['idempotent'])

    def test_archive_precondition_preserves_new_record_content(self):
        identity, path = self.compact(ready=True)
        checked = self.run_cli('validate-docs', '--proposal', identity)['record_digest']
        path.write_text(path.read_text() + '\nNew evidence reference added after the external check.\n')
        before = path.read_bytes()
        self.run_cli('archive', '--proposal', identity, '--record-digest', checked, code=4)
        self.assertEqual(path.read_bytes(), before)
        self.run_cli('archive', '--proposal', identity, '--record-digest', digest(path))

    def test_proposal_selector_recovers_detached_standard_tasks(self):
        identity='SP-20261109-detached'
        out=self.standard_ready(identity)
        path=self.root/out['tasks']
        before=digest(path)
        path.rename(path.parent/'.p2t2c-doc-original-fixture')
        result=self.run_cli('archive','--proposal',identity,'--record-digest',before)
        self.assertEqual(result['state'],'completed')
        self.assertIn('status: completed',path.read_text())

    def test_historical_v1_proposal_reference_remains_readable(self):
        identity='SP-20261109-current'
        out=self.standard_ready(identity)
        historical='SP-20261108-earlier'
        source=self.root/out['proposal']
        (source.parent/(historical+'.md')).write_text(source.read_text().replace(identity,historical))
        self.run_cli('validate-docs')
        self.run_cli('archive','--proposal',historical,code=4)
        self.run_cli('archive','--spec',out['spec'])

    def test_active_r2_freshness_and_completed_history(self):
        identity = 'SP-20261109-bound'
        out = self.standard_ready(identity, 'R2')
        self.run_cli('archive', '--spec', out['spec'])
        active = 'SP-20261109-active'
        self.standard_ready(active, 'R2')
        truth = self.root / 'docs/sot/governance/P2T2C_GOVERNANCE.md'
        truth.write_text(truth.read_text() + '\nCurrent source revision.\n')
        manifest = self.root / 'docs/sot/manifest.yaml'
        manifest.write_text(re.sub(r'sha256: "[a-f0-9]{64}"', 'sha256: "' + digest(truth) + '"', manifest.read_text(), count=1))
        self.run_cli('validate-docs', '--proposal', active)
        self.run_cli('validate-docs', '--proposal', active, '--ready', code=4)
        self.run_cli('archive', '--proposal', active, code=4)
        self.assertTrue(self.run_cli('archive', '--proposal', identity)['idempotent'])

    def test_expansion_preserves_identity_progress_and_valid_results(self):
        identity, path = self.compact(ready=True)
        path.write_text(path.read_text().replace('Known blockers: none', 'Known blockers: present') +
                        '\n## Tasks\n\n- [x] Completed step\n- [ ] Pending step\n')
        prepared, source_hash = self.prepare(identity, path)
        out = self.run_cli('expand', '--proposal', identity, '--prepared', prepared)
        self.assertEqual(out['shape'], 'standard')
        self.assertEqual(out['proposal'], str(path.relative_to(self.root)))
        self.assertIn('schema_version: 1', path.read_text())
        tasks = (self.root / out['tasks']).read_text()
        self.assertIn('- [x] Completed step', tasks)
        self.assertIn('- [ ] Pending step', tasks)
        self.assertIn('Tests: not_run', tasks)
        before = self.snapshot()
        self.assertTrue(self.run_cli('expand', '--proposal', identity, '--prepared', prepared)['idempotent'])
        self.assertEqual(before, self.snapshot())
        self.run_cli('archive', '--proposal', identity, code=4)
        self.run_cli('validate-docs')

    def test_expansion_rejects_stale_candidates_and_progress_loss(self):
        identity, path = self.compact(ready=True)
        path.write_text(path.read_text() + '\n## Tasks\n\n- [x] Existing completed work\n')
        prepared, source_hash = self.prepare(identity, path)
        self.run_cli('expand', '--proposal', identity, '--prepared', prepared, '--source-digest', '0' * 64, code=4)
        task = self.root / prepared / 'tasks.md'
        original = task.read_text()
        task.write_text(original.replace('Existing completed work', 'Different work'))
        self.run_cli('expand', '--proposal', identity, '--prepared', prepared, code=4)
        self.assertEqual(digest(path), source_hash)
        self.assertFalse((self.root / 'docs/specs/101-expanded').exists())
        task.write_text(original)
        self.run_cli('expand', '--proposal', identity, '--prepared', prepared)

    def test_expansion_can_enter_pending_r2(self):
        identity, path = self.compact(ready=True)
        prepared, _ = self.prepare(identity, path, risk='R2')
        out = self.run_cli('expand', '--proposal', identity, '--prepared', prepared)
        self.assertIn('decision: pending', path.read_text())
        self.assertIn('risk: R2', path.read_text())
        self.run_cli('archive', '--spec', out['spec'], code=4)


class SecurityTests(Fixture):
    def test_paths_links_and_existing_directory_are_preserved(self):
        identity, path = self.compact(ready=True)
        outside = self.root / 'outside.md'; outside.write_text('User-owned data\n')
        expected = outside.read_bytes()
        path.unlink(); path.symlink_to(outside)
        self.run_cli('archive', '--proposal', identity, code=4)
        self.assertEqual(outside.read_bytes(), expected)
        path.unlink(); os.link(outside, path)
        self.run_cli('validate-docs', '--proposal', identity, code=4)
        self.assertEqual(outside.read_bytes(), expected)
        self.run_cli('create', '--id', '../outside', '--shape', 'compact', code=4)
        directory = self.root / 'docs/specs/099-owned';directory.mkdir()
        self.run_cli('create', '--id', 'SP-20261109-collision', '--spec', '099-owned', code=4)
        self.assertTrue(directory.is_dir())
        self.assertEqual(list(directory.iterdir()), [])

    def test_archive_never_invokes_project_commands(self):
        identity, path = self.compact(ready=True)
        shim = self.root / 'shim';shim.mkdir();sentinel = self.root / 'project-command-ran'
        for name in ['make', 'npm', 'pnpm', 'yarn', 'git']:
            p = shim / name;p.write_text('#!/bin/sh\ntouch "' + str(sentinel) + '"\nexit 99\n');p.chmod(0o755)
        self.run_cli('archive', '--proposal', identity, env={'PATH': str(shim) + ':' + os.environ['PATH']})
        self.assertFalse(sentinel.exists())
        self.assertFalse((self.root / 'docs/closure').exists())
        self.assertFalse((self.root / '.p2t2c/runs').exists())

    def test_target_runtime_preflight_includes_completed_compact(self):
        old = self.root / 'old-runtime'
        (old / '.p2t2c/bin').mkdir(parents=True)
        (old / '.p2t2c/lib/P2T2C').mkdir(parents=True)
        (old / '.p2t2c/bin/p2t2c_documents.pl').write_text('old engine\n')
        (old / '.p2t2c/lib/P2T2C/Documents.pm').write_text('old v1\n')
        (old / '.p2t2c/manifest.yaml').write_text('version: "0.15.0"\n')
        self.run_cli('create', '--id', 'SP-20261109-standard')
        self.run_cli('compatibility', '--runtime', str(old))
        identity, path = self.compact(ready=True)
        self.run_cli('archive', '--proposal', identity)
        before = self.snapshot()
        out = self.run_cli('compatibility', '--runtime', str(old), code=4)
        self.assertIn(identity, out['error'])
        self.assertEqual(before, self.snapshot())

    def test_unrelated_pending_transaction_does_not_affect_target(self):
        a, path_a = self.compact('first', ready=True)
        b, path_b = self.compact('second', ready=True)
        original = path_a.read_bytes()
        self.interrupt(['archive', '--proposal', a], 'after_detach_1')
        self.run_cli('validate-docs', '--proposal', b)
        self.run_cli('archive', '--proposal', b)
        self.assertFalse(path_a.exists())
        self.run_cli('recover', '--proposal', a)
        self.assertEqual(path_a.read_bytes(), original)
        self.assertIn('work_status: completed', path_b.read_text())


class TransactionTests(Fixture):
    def test_concurrent_mutators_after_stale_pid_lock_have_one_owner(self):
        stale = self.root / '.p2t2c/.documents-lock';stale.mkdir()
        (stale / 'owner').write_text('99999999\n')
        program = r'''use P2T2C::Documents;
            open my $ready,'>', $ARGV[0] or die $!;close $ready;
            select undef,undef,undef,0.01 until -f 'start-lock-test';
            my $lock=P2T2C::Documents::acquire_lock();
            select undef,undef,undef,0.8;
            P2T2C::Documents::release_lock($lock);'''
        children = [subprocess.Popen(['perl', '-I.p2t2c/lib', '-e', program, 'lock-ready-' + str(i)],
                                     cwd=self.root, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                    for i in range(2)]
        deadline = time.monotonic() + 5
        while len(list(self.root.glob('lock-ready-*'))) != 2 and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertEqual(len(list(self.root.glob('lock-ready-*'))), 2)
        (self.root / 'start-lock-test').touch()
        outputs = [p.communicate(timeout=10) for p in children]
        self.assertEqual(sum(p.returncode == 0 for p in children), 1, outputs)
        self.assertTrue(any('another document mutation' in error for _, error in outputs), outputs)
        self.assertFalse(stale.exists())

    def test_compact_archive_recovers_at_each_boundary(self):
        for i, stage in enumerate(['prepared', 'after_detach_1', 'after_write_1', 'before_commit', 'after_commit']):
            with self.subTest(stage=stage):
                identity, path = self.compact('archive-' + str(i), ready=True)
                before = path.read_bytes()
                self.interrupt(['archive', '--proposal', identity], stage)
                snapshot = self.snapshot()
                self.run_cli('validate-docs', '--proposal', identity, code=4)
                self.assertEqual(snapshot, self.snapshot())
                self.run_cli('recover', '--proposal', identity)
                if stage != 'after_commit':
                    self.assertEqual(path.read_bytes(), before)
                self.run_cli('archive', '--proposal', identity)
                self.assertIn('work_status: completed', path.read_text())
        self.run_cli('validate-docs')

    def test_standard_creation_recovers_without_duplicate_allocation(self):
        for i, stage in enumerate(['prepared', 'after_directory', 'after_write_1', 'after_write_2', 'after_write_3', 'before_commit', 'after_commit']):
            with self.subTest(stage=stage):
                identity = 'SP-20261109-create-' + str(i)
                self.interrupt(['create', '--id', identity], stage)
                journals = sorted((self.root / '.p2t2c/documents' / identity).glob('*/journal.json'))
                reserved = json.loads(journals[-1].read_text())['specs_ref']
                out = self.run_cli('create', '--id', identity)
                self.assertEqual('docs/specs/' + out['spec'], reserved)
        self.run_cli('validate-docs')

    def test_expansion_recovers_and_keeps_source_and_id(self):
        for i, stage in enumerate(['prepared', 'after_directory', 'after_write_1', 'after_write_2', 'after_detach_3', 'after_write_3', 'before_commit', 'after_commit']):
            with self.subTest(stage=stage):
                identity, path = self.compact('expand-' + str(i), ready=True)
                before = path.read_bytes()
                prepared, _ = self.prepare(identity, path, spec=str(201 + i) + '-expanded')
                self.interrupt(['expand', '--proposal', identity, '--prepared', prepared], stage)
                self.run_cli('recover', '--proposal', identity)
                if stage != 'after_commit':
                    self.assertEqual(path.read_bytes(), before)
                self.run_cli('expand', '--proposal', identity, '--prepared', prepared)
                self.assertIn('schema_version: 1', path.read_text())
        self.run_cli('validate-docs')

    def test_failure_rolls_back_without_claiming_completion(self):
        identity, path = self.compact(ready=True)
        before = path.read_bytes()
        self.run_cli('archive', '--proposal', identity, code=4,
                     env={'P2T2C_TEST_DOCUMENT_FAIL_AT': 'before_commit'})
        self.assertEqual(before, path.read_bytes())
        self.run_cli('validate-docs', '--proposal', identity)

    def test_open_original_inode_edit_is_restored(self):
        identity, path = self.compact(ready=True)
        with path.open('ab', buffering=0) as held:
            proc, stream = self.paused_archive(identity)
            held.write(b'\nConcurrent original user note.\n')
            stdout, _ = proc.communicate(timeout=10);stream.close()
        self.assertEqual(proc.returncode, 4, stdout)
        self.assertEqual(json.loads(stdout)['state'], 'blocked')
        self.assertIn('Concurrent original user note.', path.read_text())
        self.assertIn('work_status: in_progress', path.read_text())
        self.run_cli('validate-docs')

    def test_visible_candidate_edit_is_preserved_and_blocks_recovery(self):
        identity, path = self.compact(ready=True)
        proc, stream = self.paused_archive(identity)
        with path.open('ab') as f:
            f.write(b'\nConcurrent visible user note.\n')
        stdout, _ = proc.communicate(timeout=10);stream.close()
        self.assertEqual(proc.returncode, 4, stdout)
        self.assertEqual(json.loads(stdout)['state'], 'blocked')
        snapshot = path.read_bytes()
        self.assertIn(b'Concurrent visible user note.', snapshot)
        self.run_cli('recover', '--proposal', identity, code=4)
        self.assertEqual(path.read_bytes(), snapshot)
        self.run_cli('validate-docs', '--proposal', identity, code=4)

    def test_parent_swap_never_writes_outside_target(self):
        identity, path = self.compact(ready=True)
        proc, stream = self.paused_archive(identity)
        outside = self.root / 'outside';outside.mkdir()
        victim = outside / path.name;victim.write_text('Unrelated user file\n')
        before = victim.read_bytes()
        parent = path.parent;parked = self.root / 'parked-proposals'
        parent.rename(parked);parent.symlink_to(outside, target_is_directory=True)
        stdout, _ = proc.communicate(timeout=10);stream.close()
        self.assertEqual(proc.returncode, 4, stdout)
        self.assertEqual(victim.read_bytes(), before)
        self.assertTrue(any(parked.glob('.p2t2c-document-*-original')))

    def test_pending_document_transaction_blocks_layout_migration(self):
        identity, path = self.compact(ready=True)
        self.interrupt(['archive', '--proposal', identity], 'prepared')
        before = self.snapshot()
        self.run_cli('docs-migrate', '--dry-run', code=4)
        self.assertEqual(before, self.snapshot())


if __name__ == '__main__':
    groups = {'contract': ContractTests, 'security': SecurityTests, 'transaction': TransactionTests}
    selected = list(groups.values()) if ARGS.suite == 'all' else [groups[ARGS.suite]]
    suite = unittest.TestSuite(unittest.defaultTestLoader.loadTestsFromTestCase(group) for group in selected)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    raise SystemExit(0 if result.wasSuccessful() else 1)
