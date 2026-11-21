"""Check build-cache invalidation and the relocatable reference archive layout."""
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

import reference_cache_key as cache


class ReferenceCacheCheck(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='reference-cache-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for name in cache.DEFINITIONS:
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(cache.ROOT / name, target)
        self.inputs = dict(RUBY_SOURCE_REF='a' * 40, REF_RUBY_VERSION='4.0.9', RUST_VERSION='1.85.0',
                           RUNNER_OS='macOS', RUNNER_ARCH='ARM64')
        self.native = dict(ImageOS='macos26', ImageVersion='image', clang='clang', sdk='sdk',
                           openssl_prefix='/openssl', libyaml_prefix='/yaml', libraries='versions')

    def key(self):
        return cache.cache_key(self.root, self.inputs, self.native)

    def test_scheduling_and_other_workflow_changes_retain_the_cache(self):
        before = self.key()
        workflow = self.root / '.github/workflows/ci.yml'
        workflow.parent.mkdir(parents=True)
        workflow.write_text('shards: 4\n')
        self.assertEqual(self.key(), before)
        workflow.write_text('shards: 8\nembedding: combined\n')
        self.assertEqual(self.key(), before)

    def test_every_build_and_archive_definition_invalidates_the_cache(self):
        before = self.key()
        for name in cache.DEFINITIONS:
            path = self.root / name
            original = path.read_bytes()
            with self.subTest(name=name):
                path.write_bytes(original + b'\n# changed\n')
                self.assertNotEqual(self.key(), before)
                path.write_bytes(original)

    def test_source_versions_platform_and_native_changes_invalidate_the_cache(self):
        before = self.key()
        for values in (self.inputs, self.native):
            for name in list(values):
                original = values[name]
                with self.subTest(name=name):
                    values[name] += '-changed'
                    self.assertNotEqual(self.key(), before)
                    values[name] = original
        self.native['CFLAGS'] = '-O1'
        self.assertNotEqual(self.key(), before)

    def test_key_is_deterministic_and_bounded(self):
        key = self.key()
        self.assertEqual(key, cache.cache_key(self.root, dict(reversed(list(self.inputs.items()))),
                                            dict(reversed(list(self.native.items())))))
        self.assertLessEqual(len(key), 512)

    def test_archive_restores_runtime_extensions_build_context_and_fixtures(self):
        binary = self.root / '.reference-ruby/bin/ruby'
        binary.parent.mkdir(parents=True)
        binary.write_text('#!/bin/sh\nprintf %s libruby-static.a\n')
        binary.chmod(0o755)
        names = ['.ruby-tests/.ext/include/arch/ruby/config.h', '.ruby-tests/.ext/arch/-test-/probe.bundle',
                 '.ruby-tests/Makefile', '.ruby-tests/libruby-static.a',
                 '.ruby-tests/enc/unicode/data/UnicodeData.txt', '.ruby-tests/exe/gem']
        for name in names:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(name)
        subprocess.run(['sh', str(cache.ROOT / 'unittest/package_reference.sh'), str(self.root)], check=True)
        restored = self.root / 'relocated'
        restored.mkdir()
        with tarfile.open(self.root / 'reference-runtime.tar.gz') as archive:
            self.assertTrue(all(not name.startswith('/') and '..' not in Path(name).parts
                                for name in archive.getnames()))
            archive.extractall(restored)
        for name in names:
            self.assertEqual((restored / name).read_text(), name)
        self.assertEqual(subprocess.check_output([str(restored / '.reference-ruby/bin/ruby')], text=True),
                         'libruby-static.a')


if __name__ == '__main__':
    unittest.main()
