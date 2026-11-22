#!/usr/bin/env python3
"""Add read-only page ownership evidence without replacing ordinary RSS gates."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import sys

import rss_native_probe as native
from clone_rss_heap import heap_samples

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (native.SUBJECT, 'ae6bd8cc89a98fc01a1e129d3becc447b637d35f')
_EMIT = native.emit_probe


def emit(source, heap=False):
    if not heap:
        raise ValueError('page evidence requires the complete heap observer')
    emitted = _EMIT(source, heap=True)
    start = 'static void gem_heap_region('
    if emitted.count(start) != 1:
        raise ValueError('changed heap observation boundary')
    prefix, body = emitted.split(start, 1)
    boundary = '\n}\n\nstatic void gem_heap_snapshot('
    if body.count(boundary) != 1:
        raise ValueError('changed heap snapshot boundary')
    body, tail = body.split(boundary, 1)
    loop = 'for (__lang_region_block *b = r ? r->blocks : NULL; b; b = b->prev)'
    end = '(unsigned long)(b + 1) + b->pad, b->pad);'
    if body.count(loop) != 1 or body.count(end) != 1:
        raise ValueError('changed heap region inventory')
    body = body.replace(loop, loop + ' {\n        gem_page_region(sample, kind, arena, (uintptr_t)(b + 1), b->pad);', 1)
    body = body.replace(end, end + '\n    }', 1)
    return prefix + (ROOT / 'tools/rss_page_observer.c').read_text() + '\n' + start + body + boundary + tail


def page_samples(raw, native_rows):
    heaps = heap_samples(raw, native_rows)
    pages = [[] for _ in heaps]
    pattern = (r'RSS_PAGE sample=(\d+) kind=(\w+) arena=(\d+) lo=(\d+) hi=(\d+) '
               r'page_bytes=(\d+) pages=(\d+) present=(\d+) exclusive=(\d+) swapped=(\d+)')
    keys = ('sample', 'kind', 'arena', 'lo', 'hi', 'page_bytes', 'pages', 'present', 'exclusive', 'swapped')
    for line in raw.splitlines():
        if line.startswith('RSS_PAGE_ERROR'):
            raise ValueError('page-table observation unavailable: ' + line)
        if not line.startswith('RSS_PAGE'):
            continue
        match = re.fullmatch(pattern, line)
        if not match:
            raise ValueError('malformed page observation')
        values = {k: (v if k == 'kind' else int(v)) for k, v in zip(keys, match.groups())}
        index, size = values['sample'], values['page_bytes']
        if index >= len(pages) or size <= 0 or size & (size - 1):
            raise ValueError('invalid sample or page size')
        lo, hi = values['lo'], values['hi']
        expected = max(0, hi // size - (lo + size - 1) // size)
        if (lo >= hi or expected != values['pages'] or values['exclusive'] > values['present']
                or values['present'] + values['swapped'] > values['pages']):
            raise ValueError('invalid page accounting')
        pages[index].append(values)
    result = []
    for heap, rows in zip(heaps, pages):
        identity = lambda row: (row['kind'], row['arena'], row['lo'], row['hi'])
        actual, expected = Counter(map(identity, rows)), Counter(map(identity, heap['regions']))
        if actual != expected or any(n != 1 for n in actual.values()):
            raise ValueError('missing, duplicate or unowned page range')
        if len({r['page_bytes'] for r in rows}) != 1:
            raise ValueError('inconsistent page sizes')
        intervals = sorted(((r['lo'] + r['page_bytes'] - 1) // r['page_bytes'],
                            r['hi'] // r['page_bytes']) for r in rows if r['pages'])
        if any(a[1] > b[0] for a, b in zip(intervals, intervals[1:])):
            raise ValueError('overlapping owner ranges cannot be summed')
        totals = {}
        for row in rows:
            counts = totals.setdefault(row['kind'], Counter())
            for name in ('pages', 'present', 'exclusive', 'swapped'):
                counts[name] += row[name]
            counts['omitted_edge_bytes'] += row['hi'] - row['lo'] - row['pages'] * row['page_bytes']
        result.append(dict(page_bytes=rows[0]['page_bytes'], totals=totals, regions=rows,
                           method_compaction=native_rows[len(result)]['policy']))
    return result


def build(args):
    native.emit_probe = emit
    try:
        native.build(args.subject.resolve(), args.diagnostic_root.resolve(), args.subject_ref, heap=True)
    finally:
        native.emit_probe = _EMIT
    path = args.diagnostic_root / 'probe-build.json'
    receipt = json.loads(path.read_text())
    receipt['page_observer_sha256'] = native.ci.digest(ROOT / 'tools/rss_page_observer.c')
    native.ci.save(path, receipt)


def collect(args):
    receipt = json.loads((args.diagnostic_root / 'probe-build.json').read_text())
    if receipt.get('page_observer_sha256') != native.ci.digest(ROOT / 'tools/rss_page_observer.c'):
        raise ValueError('page observer differs from the build receipt')
    status = native.collect(args)
    path = args.output / 'result.json'
    record = json.loads(path.read_text())
    record['page_observations'] = {}
    record['page_evidence_complete'] = False
    try:
        for label, filename in [('diagnostic-clone', 'module.log'), ('diagnostic-method-copy', 'native.log')]:
            raw = (args.output / label / filename).read_text(errors='replace')
            record['page_observations'][label] = page_samples(raw, record['cases'][label]['native_samples'])
        record['page_evidence_complete'] = True
    except ValueError as exc:
        record['page_error'] = str(exc)
    native.ci.save(path, record)
    print(json.dumps({k: record[k] for k in ('ordinary_gates_passed', 'diagnostics_complete', 'page_evidence_complete')}))
    return int(bool(status) or not record['page_evidence_complete'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('build', 'collect'))
    for name in ('subject', 'diagnostic-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    parser.add_argument('--subject-ref', choices=SOURCES, default=native.SUBJECT)
    for name in ('reference', 'ruby-src', 'compiler-root', 'output'):
        parser.add_argument('--' + name, type=Path)
    args = parser.parse_args()
    if args.operation == 'build':
        build(args)
        return 0
    if any(getattr(args, k) is None for k in ('reference', 'ruby_src', 'compiler_root', 'output')):
        parser.error('collect requires reference, ruby-src, compiler-root and output')
    return collect(args)


if __name__ == '__main__':
    raise SystemExit(main())
