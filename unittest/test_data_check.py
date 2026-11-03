#!/usr/bin/env python3
"""Check verified data installation without depending on the network."""
import hashlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import test_data as data


class TestDataCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='mere-test-data-')
        self.addCleanup(self.temp.cleanup)
        self.source = Path(self.temp.name)
        (self.source / 'common.mk').write_text('UNICODE_VERSION = 17.0.0\n')
        (self.source / 'bin').mkdir()
        (self.source / 'bin/gem').write_text('require "rubygems/gem_runner"\n')
        self.payload = b'# CaseFolding-17.0.0.txt\n0041; C; 0061; # LATIN CAPITAL LETTER A\n'
        self.payloads = [self.payload, b'# SpecialCasing-17.0.0.txt\nfixture data\n']
        self.entries = [dict(path='enc/unicode/data/17.0.0/ucd/' + name,
                             url='https://www.unicode.org/Public/17.0.0/ucd/' + name,
                             bytes=len(payload), sha256=hashlib.sha256(payload).hexdigest())
                        for name, payload in zip(('CaseFolding.txt', 'SpecialCasing.txt'), self.payloads)]
        self.addCleanup(patch.stopall)
        patch.object(data, 'FILES', self.entries).start()

    def fetch(self, url, timeout):
        self.assertEqual(timeout, 30)
        index = [entry['url'] for entry in self.entries].index(url)
        return io.BytesIO(self.payloads[index])

    def test_download_is_verified_and_cached_without_network(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=self.fetch) as request:
            info = data.prepare(self.source)
        self.assertEqual(info['files'], self.entries)
        self.assertEqual(request.call_count, 2)
        self.assertEqual((self.source / 'exe/gem').read_bytes(), (self.source / 'bin/gem').read_bytes())
        with patch.object(data.urllib.request, 'urlopen', side_effect=AssertionError('network')):
            self.assertEqual(data.prepare(self.source), info)

    def test_wrong_version_stops_before_downloading(self):
        (self.source / 'common.mk').write_text('UNICODE_VERSION = 16.0.0\n')
        with patch.object(data.urllib.request, 'urlopen', side_effect=AssertionError('network')):
            with self.assertRaises(ValueError):
                data.prepare(self.source)

    def test_corrupt_download_is_not_installed(self):
        with patch.object(data.urllib.request, 'urlopen', return_value=io.BytesIO(b'corrupt')):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        self.assertFalse((self.source / self.entries[0]['path']).exists())

    def test_corrupt_restored_artifact_is_refused(self):
        path = self.source / self.entries[0]['path']
        path.parent.mkdir(parents=True)
        path.write_bytes(b'corrupt')
        with patch.object(data.urllib.request, 'urlopen', side_effect=AssertionError('network')):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        with self.assertRaises(ValueError):
            data.verify(self.source)

    def test_oversized_download_is_bounded_and_refused(self):
        class Tracked(io.BytesIO):
            def read(self, size=-1):
                self.requested = size
                return super().read(size)
        stream = Tracked(b'x' * 1024)
        entry = dict(self.entries[0], bytes=64, sha256=hashlib.sha256(b'x' * 1024).hexdigest())
        with patch.object(data, 'FILES', [entry]), patch.object(data.urllib.request, 'urlopen', return_value=stream):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        self.assertEqual(stream.requested, 65)
        self.assertFalse((self.source / self.entries[0]['path']).exists())

    def test_network_failure_does_not_leave_a_partial_file(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                data.prepare(self.source)
        self.assertFalse((self.source / self.entries[0]['path']).exists())

    def test_changed_gem_entry_point_is_not_silently_overwritten(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=self.fetch):
            data.prepare(self.source)
        (self.source / 'exe/gem').write_text('different\n')
        with self.assertRaises(ValueError):
            data.prepare(self.source)

    def test_missing_secondary_data_is_not_verified_or_hidden_by_a_cached_first_file(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=self.fetch):
            data.prepare(self.source)
        (self.source / self.entries[1]['path']).unlink()
        with self.assertRaises(FileNotFoundError):
            data.verify(self.source)
        with patch.object(data.urllib.request, 'urlopen', side_effect=self.fetch) as request:
            data.prepare(self.source)
        request.assert_called_once_with(self.entries[1]['url'], timeout=30)

    def test_partial_download_cannot_produce_complete_provenance(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=[io.BytesIO(self.payload), io.BytesIO(b'bad')]):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        self.assertTrue((self.source / self.entries[0]['path']).exists())
        self.assertFalse((self.source / self.entries[1]['path']).exists())
        with self.assertRaises(FileNotFoundError):
            data.verify(self.source)


if __name__ == '__main__':
    unittest.main()
