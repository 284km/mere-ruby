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
        self.addCleanup(patch.stopall)
        patch.object(data, 'SHA256', hashlib.sha256(self.payload).hexdigest()).start()

    def test_download_is_verified_and_cached_without_network(self):
        with patch.object(data.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            info = data.prepare(self.source)
        self.assertEqual(info['sha256'], hashlib.sha256(self.payload).hexdigest())
        request.assert_called_once_with(data.URL, timeout=30)
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
        self.assertFalse((self.source / data.RELATIVE).exists())

    def test_corrupt_restored_artifact_is_refused(self):
        path = self.source / data.RELATIVE
        path.parent.mkdir(parents=True)
        path.write_bytes(b'corrupt')
        with patch.object(data.urllib.request, 'urlopen', side_effect=AssertionError('network')):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        with self.assertRaises(ValueError):
            data.verify(self.source)

    def test_oversized_download_is_bounded_and_refused(self):
        stream = io.BytesIO(b'x' * 1024)
        with patch.object(data, 'MAX_BYTES', 64), patch.object(data.urllib.request, 'urlopen', return_value=stream):
            with self.assertRaises(ValueError):
                data.prepare(self.source)
        self.assertFalse((self.source / data.RELATIVE).exists())

    def test_network_failure_does_not_leave_a_partial_file(self):
        with patch.object(data.urllib.request, 'urlopen', side_effect=TimeoutError):
            with self.assertRaises(TimeoutError):
                data.prepare(self.source)
        self.assertFalse((self.source / data.RELATIVE).exists())

    def test_changed_gem_entry_point_is_not_silently_overwritten(self):
        with patch.object(data.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)):
            data.prepare(self.source)
        (self.source / 'exe/gem').write_text('different\n')
        with self.assertRaises(ValueError):
            data.prepare(self.source)


if __name__ == '__main__':
    unittest.main()
