#!/usr/bin/env python3
"""Reject incomplete page ownership and verify the reader against real mappings."""
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from rss_native_probe import native_samples
from rss_page_probe import page_samples, emit

ROOT = Path(__file__).resolve().parent


class EmissionBoundary(unittest.TestCase):
    def test_identical_unrelated_loop_is_preserved(self):
        heap = (ROOT / 'rss_heap_observer.c').read_text()
        extra = 'for (__lang_region_block *b = r ? r->blocks : NULL; b; b = b->prev) unrelated();\n'
        with patch('rss_page_probe._EMIT', return_value=extra + heap):
            output = emit('unused', heap=True)
        self.assertTrue(output.startswith(extra))
        self.assertEqual(output.count('gem_page_region(sample, kind, arena, (uintptr_t)(b + 1), b->pad);'), 1)

    def test_changed_heap_loop_is_rejected(self):
        heap = (ROOT / 'rss_heap_observer.c').read_text().replace('b = b->prev)', 'b = NULL)')
        with patch('rss_page_probe._EMIT', return_value=heap), self.assertRaises(ValueError):
            emit('unused', heap=True)


class PageEvidence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = json.loads((ROOT / 'fixtures/rss_page_sample.json').read_text())['raw']

    def parse(self, raw):
        return page_samples(raw, native_samples(raw))

    def test_captured_ranges_are_complete(self):
        rows = self.parse(self.raw)
        self.assertEqual(len(rows), 1)
        self.assertIn('cache', rows[0]['totals'])
        self.assertGreater(rows[0]['totals']['cache']['pages'], 0)

    def test_missing_range_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(re.sub(r'^RSS_PAGE [^\n]*\n', '', self.raw, count=1, flags=re.M))

    def test_duplicate_range_is_rejected(self):
        line = next(s for s in self.raw.splitlines() if s.startswith('RSS_PAGE '))
        with self.assertRaises(ValueError):
            self.parse(self.raw + line + '\n')

    def test_unavailable_observation_cannot_be_zero(self):
        with self.assertRaisesRegex(ValueError, 'unavailable'):
            self.parse(self.raw + 'RSS_PAGE_ERROR sample=0 reason=open errno=13\n')

    def test_forged_count_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(re.sub(r' present=\d+', ' present=999999999', self.raw, count=1))

    def test_missing_page_size_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(re.sub(r' page_bytes=\d+', '', self.raw, count=1))

    def test_unknown_owner_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(self.raw.replace('RSS_PAGE sample=0 kind=cache', 'RSS_PAGE sample=0 kind=unknown', 1))

    def test_wrong_extent_is_rejected(self):
        with self.assertRaises(ValueError):
            self.parse(re.sub(r' pages=\d+', ' pages=999999999', self.raw, count=1))

    def test_exclusive_count_cannot_exceed_present(self):
        with self.assertRaises(ValueError):
            self.parse(re.sub(r' exclusive=\d+', ' exclusive=999999999', self.raw, count=1))

    def test_overlapping_ranges_cannot_be_summed(self):
        caches = [r for r in self.parse(self.raw)[0]['regions'] if r['kind'] == 'cache']
        first = caches[0]
        other = next(r for r in caches[1:] if r['hi'] - r['lo'] == first['hi'] - first['lo'])
        pattern = r'^(RSS_(?:PAGE|REGION) sample=0 kind=cache arena=' + str(first['arena']) + r' lo=)\d+ hi=\d+'
        raw, count = re.subn(pattern, lambda m: m[1] + str(other['lo']) + ' hi=' + str(other['hi']), self.raw, flags=re.M)
        self.assertEqual(count, 2)
        with self.assertRaisesRegex(ValueError, 'overlapping'):
            self.parse(raw)


@unittest.skipUnless(sys.platform == 'linux', 'the native pagemap interface is Linux-specific')
class NativeReader(unittest.TestCase):
    def run_c(self, denied=False):
        headers = '''#define _GNU_SOURCE
#include <errno.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <assert.h>
'''
        override = '''static int denied_open(const char *p, int flags) {
    (void)p; (void)flags; errno = EACCES; return -1;
}
#define open denied_open
''' if denied else ''
        main = '''
int main(void) {
    long page = sysconf(_SC_PAGESIZE);
    assert(page > 0);
    volatile char *p = mmap(NULL, (size_t)page * 8, PROT_READ | PROT_WRITE,
                           MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    assert((void *)p != MAP_FAILED);
    assert(madvise((void *)p, (size_t)page * 8, MADV_NOHUGEPAGE) == 0);
    p[0] = 1; p[page * 4] = 2;
    errno = ERANGE;
    gem_page_region(0, "fixture", 0, (uintptr_t)p, (size_t)page * 8);
    assert(errno == ERANGE);
    assert(madvise((void *)p, (size_t)page, MADV_DONTNEED) == 0);
    gem_page_region(1, "fixture", 0, (uintptr_t)p, (size_t)page * 8);
    assert(munmap((void *)p, (size_t)page * 8) == 0);
    return 0;
}
'''
        with tempfile.TemporaryDirectory() as name:
            folder = Path(name)
            source = folder / 'reader.c'
            source.write_text(headers + override + (ROOT / 'rss_page_observer.c').read_text() + main)
            subprocess.run(['cc', '-std=c11', '-Wall', '-Wextra', '-Werror', '-O2', str(source), '-o', str(folder/'reader')], check=True)
            return subprocess.check_output([str(folder/'reader')], stderr=subprocess.STDOUT, text=True)

    def test_reader_does_not_fault_in_untouched_pages(self):
        output = self.run_c()
        self.assertEqual(re.findall(r'pages=(\d+) present=(\d+)', output), [('8', '2'), ('8', '1')])

    def test_denied_reader_reports_failure(self):
        output = self.run_c(denied=True)
        self.assertEqual(output.count('RSS_PAGE_ERROR'), 2)
        self.assertIn('reason=open errno=13', output)
        self.assertNotIn(' present=', output)


if __name__ == '__main__':
    unittest.main()
