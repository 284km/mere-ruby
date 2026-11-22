#!/usr/bin/env python3
"""Observe the original clone failure at a locked runtime, without repairing pins."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

import rss_native_probe as native

SOURCE = 'ae6bd8cc89a98fc01a1e129d3becc447b637d35f'
COMPILER = '01f5ad738748cc570cc04e3000f50b8c6965543f'


def heap_samples(raw, samples):
    result = [dict(heap=None, regions=[], stacks=[], mappings=[], active_sets=[], active=[]) for _ in samples]
    for line in raw.splitlines():
        if not line.startswith(('RSS_HEAP ', 'RSS_REGION ', 'RSS_STACK ', 'RSS_MAPPING ',
                                'RSS_ACTIVE_SET ', 'RSS_ACTIVE ')):
            continue
        kind, rest = line.split(' ', 1)
        values = {k: int(v) if re.fullmatch(r'-?\d+', v) else v
                  for k, v in re.findall(r'(\w+)=(.*?)(?= \w+=|$)', rest)}
        required = {
            'RSS_HEAP': ('sample arena mmap used free top', ''),
            'RSS_REGION': ('sample arena lo hi capacity', 'kind'),
            'RSS_STACK': ('sample handle state lo hi map bytes', ''),
            'RSS_MAPPING': ('sample lo hi rss_kb', 'kind'),
            'RSS_ACTIVE_SET': ('sample handle count', ''),
            'RSS_ACTIVE': ('sample handle index capacity allocated', 'site'),
        }[kind]
        if (any(type(values.get(k)) is not int for k in required[0].split())
                or any(not isinstance(values.get(k), str) for k in required[1].split())):
            raise ValueError('missing native heap fields')
        index = values['sample']
        if not isinstance(index, int) or not 0 <= index < len(result):
            raise ValueError('heap observation outside native samples')
        if any(isinstance(v, int) and v < 0 for v in values.values()):
            raise ValueError('negative native heap observation')
        row = result[index]
        if kind == 'RSS_HEAP':
            if row['heap'] is not None or values['used'] + values['free'] != values['arena']:
                raise ValueError('invalid allocator accounting')
            row['heap'] = values
        else:
            if kind in ('RSS_REGION', 'RSS_MAPPING'):
                if values['lo'] >= values['hi']:
                    raise ValueError('invalid native address range')
                if kind == 'RSS_REGION' and values['hi'] - values['lo'] != values['capacity']:
                    raise ValueError('invalid region capacity')
            row[{'RSS_REGION': 'regions', 'RSS_STACK': 'stacks', 'RSS_MAPPING': 'mappings',
                 'RSS_ACTIVE_SET': 'active_sets', 'RSS_ACTIVE': 'active'}[kind]].append(values)
    if not result:
        raise ValueError('missing native samples')
    for row, sample in zip(result, samples):
        if (row['heap'] is None or not row['mappings']
                or not any(s['handle'] == sample['begin']['root'] for s in row['stacks'])):
            raise ValueError('incomplete native heap observation')
        handles = [s['handle'] for s in row['active_sets']]
        if len(handles) != len(set(handles)) or set(handles) != {s['handle'] for s in row['stacks']}:
            raise ValueError('missing coroutine region inventory')
        for scope in row['active_sets']:
            indices = [s['index'] for s in row['active'] if s['handle'] == scope['handle']]
            if sorted(indices) != list(range(scope['count'])):
                raise ValueError('incomplete active region inventory')
        for kind, expected in [('default', sample['default']['capacity']),
                               ('cache', sample['end']['cache_capacity']),
                               ('retired', sample['end']['retired_capacity'])]:
            if sum(r['capacity'] for r in row['regions'] if r['kind'] == kind) != expected:
                raise ValueError('incomplete native region accounting')
    return result


def collect(args):
    subject, probe, output = args.subject.resolve(), args.diagnostic_root.resolve(), args.output.resolve()
    reference, source = args.reference.resolve(), args.ruby_src.resolve()
    compiler = args.compiler_root.resolve()
    if (native.git(subject, 'rev-parse', 'HEAD') != SOURCE
            or native.git(source, 'rev-parse', 'HEAD') != native.RUBY
            or native.git(compiler, 'rev-parse', 'HEAD') != COMPILER
            or os.environ.get('MERE_REF') != COMPILER):
        raise ValueError('the locked runtime, Ruby source and compiler are required')
    native.git(subject, 'diff', '--exit-code', 'HEAD', '--', '*.mere', '*.c', '*.h', 'tools', 'unittest', 'lib')
    receipt = json.loads((probe / 'probe-build.json').read_text())
    if (not receipt['heap_observer'] or receipt['subject_ref'] != SOURCE
            or receipt['ordinary_binary_sha256'] != native.ci.digest(subject / 'mere-ruby')
            or receipt['binary_sha256'] != native.ci.digest(probe / 'mere-ruby')
            or receipt['original_c_sha256'] != native.ci.digest(subject / 'mr.c')
            or (subject / '.build_mode').read_text().strip() != 'O2'
            or (probe / '.build_mode').read_text().strip() != native.MODE):
        raise ValueError('ordinary and separate heap build receipts must match')
    output.mkdir(parents=True, exist_ok=False)
    record = dict(subject_ref=SOURCE, compiler_ref=COMPILER, ruby_ref=native.RUBY,
                  ordinary_binary_sha256=native.ci.digest(subject / 'mere-ruby'),
                  ordinary_c_sha256=native.ci.digest(subject / 'mr.c'),
                  reference_binary_sha256=native.ci.digest(reference),
                  compiler_binary_sha256=native.ci.digest(compiler / '_build/default/bin/mere.exe'),
                  page_bytes=os.sysconf('SC_PAGE_SIZE'),
                  diagnostic_build=receipt, bounds=dict(wall_seconds=600, rss_kb=2097152, child_seconds=10),
                  order=['reference', *['ordinary-' + str(i) for i in range(4)],
                         *['heap-' + str(i) for i in range(2)]], cases={})
    native.ci.save(output / 'result.json', record)
    rejection = subprocess.run([sys.executable, str(native.ROOT / 'tools/method_copy_memory_check.py'),
        '--binary', str(probe / 'mere-ruby'), '--reference', str(reference),
        '--output', str(output / 'must-reject-probe')], capture_output=True, text=True)
    (output / 'probe-rejection.log').write_text(rejection.stdout + rejection.stderr)
    if rejection.returncode != 2 or 'an O2 build is required' not in rejection.stderr:
        raise ValueError('ordinary memory gate must reject the heap probe')
    os.environ['REF_RUBY_BIN'] = str(reference)
    with (output / 'module-driver.log').open('w') as log:
        run = subprocess.run([sys.executable, str(subject / 'tools/class_module_check.py'),
            '--binary', str(subject / 'mere-ruby'), '--reference', str(reference),
            '--ruby-src', str(source), '--output', str(output / 'module')],
            stdout=log, stderr=subprocess.STDOUT)
    record['module'] = dict(exit=run.returncode,
        result=json.loads((output / 'module/result.json').read_text()))
    native.ci.save(output / 'result.json', record)
    module = record['module']['result']
    if (module['source_ref'] != SOURCE or module['ruby_ref'] != native.RUBY
            or module['binary_sha256'] != record['ordinary_binary_sha256']
            or module['working_diff_sha256'] is not None):
        raise ValueError('Module control provenance differs from the locked source')
    for label in record['order']:
        diagnostic = label.startswith('heap-')
        binary = reference if label == 'reference' else (probe if diagnostic else subject) / 'mere-ruby'
        folder = output / label
        value = native.clone(binary, folder, reference, source, diagnostic)
        if diagnostic:
            value['heap_samples'] = heap_samples((folder / 'module.log').read_text(), value['native_samples'])
        record['cases'][label] = value
        native.ci.save(output / 'result.json', record)
        print(label, value['summary'], value['child_statuses'], flush=True)
    record['ordinary_gates_passed'] = (record['module']['exit'] == 0
        and all(v['passed'] for v in record['cases'].values() if not v['diagnostic_only']))
    record['diagnostics_complete'] = all(v['diagnostic_complete'] for v in record['cases'].values()
                                       if v['diagnostic_only'])
    native.ci.save(output / 'result.json', record)
    return int(not (record['ordinary_gates_passed'] and record['diagnostics_complete']))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('build', 'collect'))
    for name in ('subject', 'diagnostic-root'):
        parser.add_argument('--' + name, type=Path, required=True)
    for name in ('reference', 'ruby-src', 'compiler-root', 'output'):
        parser.add_argument('--' + name, type=Path)
    args = parser.parse_args()
    if args.operation == 'build':
        native.build(args.subject.resolve(), args.diagnostic_root.resolve(), SOURCE, heap=True)
        return 0
    if any(getattr(args, key) is None for key in ('reference', 'ruby_src', 'compiler_root', 'output')):
        parser.error('collect requires reference, ruby-src, compiler-root and output')
    return collect(args)


if __name__ == '__main__':
    raise SystemExit(main())
