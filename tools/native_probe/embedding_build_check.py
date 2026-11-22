"""Check fault fixture isolation and fail-closed native header reuse."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import embedding_build as build

ROOT = Path(__file__).resolve().parents[2]


class EmbeddingBuildCheck(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='embedding-build-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for name in ('main.mere', 'ic/m_step.mere', '.mere_modules/mgz/deflate.mere',
                     'tools/native_probe/embedding_api.mere', 'tools/native_probe/native_build_flags.py'):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)
        self.compiler = self.root / 'mere.exe'
        self.compiler.write_bytes(b'compiler')
        self.normal = self.root / 'normal'; self.normal.mkdir()
        self.output = self.root / 'faults'; self.output.mkdir()
        (self.normal / 'embedding.h').write_bytes(b'normal header')
        self.provenance = dict(header_recipe=build.header_recipe(self.root, self.compiler),
                               header_sha256=hashlib.sha256(b'normal header').hexdigest(),
                               setup_failure_injected=False, cleanup_failure_injected=False)
        self.save()

    def save(self):
        (self.normal / 'build-provenance.json').write_text(json.dumps(self.provenance))

    def reuse(self):
        build.reuse_header(self.normal, self.output, build.header_recipe(self.root, self.compiler))

    def test_matching_normal_header_is_reused_byte_for_byte(self):
        self.reuse()
        self.assertEqual((self.output / 'embedding.h').read_bytes(), b'normal header')

    def test_changed_compiler_or_imported_source_refuses_header_reuse(self):
        for name in ('mere.exe', 'main.mere', 'ic/m_step.mere', '.mere_modules/mgz/deflate.mere'):
            path = self.root / name
            original = path.read_bytes()
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'identity'):
                path.write_bytes(original + b'changed')
                self.reuse()
            path.write_bytes(original)

    def test_changed_exports_or_header_checksum_refuses_reuse(self):
        self.provenance['header_recipe']['exports_sha256'] = 'changed'
        self.save()
        with self.assertRaisesRegex(ValueError, 'identity'):
            self.reuse()
        self.provenance['header_recipe'] = build.header_recipe(self.root, self.compiler)
        self.save()
        (self.normal / 'embedding.h').write_bytes(b'tampered')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.reuse()

    def test_fault_build_cannot_supply_a_normal_header(self):
        for mode in ('setup_failure_injected', 'cleanup_failure_injected'):
            self.provenance[mode] = True
            self.save()
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, 'normal'):
                self.reuse()
            self.provenance[mode] = False

    def test_combined_fault_build_cannot_be_packaged_for_consumers(self):
        self.provenance.update(setup_failure_injected=True, cleanup_failure_injected=True, failure_checks=True)
        self.save()
        result = subprocess.run([sys.executable, str(ROOT / 'tools/native_probe/embedding_bundle.py'),
                                 '--library-dir', str(self.normal), '--prism-lib', str(self.root / 'unused.a'),
                                 '--output', str(self.root / 'bundle')], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('fixture cannot be packaged', result.stderr)
        self.assertFalse((self.root / 'bundle').exists())

    def test_normal_source_and_legacy_single_faults_retain_their_contracts(self):
        source = (ROOT / 'tools/native_probe/embedding_api.mere').read_text()
        self.assertEqual(build.failure_api(source, False, False), source)
        setup = build.failure_api(source, True, False)
        cleanup = build.failure_api(source, False, True)
        self.assertNotIn(build.FAULT_ENV, setup + cleanup)
        self.assertEqual(setup.count('fail "injected setup failure"'), 1)
        self.assertEqual(cleanup.count('fail "injected cleanup failure"'), 2)

    def test_combined_fixture_preserves_real_setup_and_both_teardown_calls(self):
        source = (ROOT / 'tools/native_probe/embedding_api.mere').read_text()
        combined = build.failure_api(source, True, True, selectable=True)
        self.assertIn('let _ = driver_setup env "" "(embedded)" in 0', combined)
        self.assertEqual(combined.count('sch_terminate_all world'), 2)
        self.assertEqual(combined.count(build.FAULT_ENV), 3)
        with self.assertRaisesRegex(ValueError, 'setup injection'):
            build.failure_api(source.replace('driver_setup env', 'changed_setup env'), True, True, selectable=True)
        with self.assertRaisesRegex(ValueError, 'cleanup injection'):
            build.failure_api(source.replace('sch_terminate_all world', 'changed_teardown world'), True, True, selectable=True)


if __name__ == '__main__':
    unittest.main()
