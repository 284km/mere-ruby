#!/usr/bin/env python3
"""Diagnose method metadata retention; this does not replace the lifetime gate.

The complete case uses the unchanged 21,000-owner program. Shorter prefixes
are separate diagnostics, never alternate passing workloads or baselines.
Run method_copy_memory_check.py separately for the actual paired 2x assertion.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True
from method_copy_memory_check import PROGRAM, RSS_KB, WALL
from ci import supervise


def parse(text):
    stores = {key: int(value) for key, value in
              re.findall(r'^([\w]+)\t(\d+)$', text, re.M)}
    samples, timeline = [], []
    methods, arena = None, None
    for line in text.splitlines():
        if line.startswith('gc: class survivors '):
            found = re.search(r'methods=(\d+)', line)
            if found:
                methods = int(found[1])
        if line.startswith('gc: END '):
            found = re.search(r'meths_g=(\d+)', line)
            if found:
                arena = int(found[1])
        found = re.fullmatch(r'RSS (\d+) (\d+)', line)
        if found:
            batch, rss = int(found[1]), int(found[2])
            samples.append([batch, rss])
            timeline.append(dict(batch=batch, rss_kb=rss,
                                 last_gc_method_rows=methods,
                                 last_gc_current_method_arena_bytes=arena))
    return dict(stores=stores, samples_kb=samples, timeline=timeline,
                observed_post_gc_peak_to_initial=(
                    max(rss for _, rss in samples) / samples[0][1]
                    if samples and samples[0][1] > 0 else None),
                region_statistics=[line for line in text.splitlines()
                                   if line.startswith('region-stats ')])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path,
                        default=Path(__file__).resolve().parents[1] / 'mere-ruby')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve()
    if (binary.parent / '.build_mode').read_text().strip() != 'O2':
        parser.error('use a normal O2 build; instrumented native builds are separate diagnostics')
    args.output.mkdir(parents=True, exist_ok=False)
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('RUBY', 'GEM_', 'BUNDLE_', 'MERE_', 'MT_'))}
    env.update(LANG='en_US.UTF-8', MERE_RUBY_STORE_STATS='1',
               MERE_RUBY_GC_LOG='1', MERE_REGION_STATS='1')
    record = dict(diagnostic_only=True, replaces_lifetime_gate=False,
                  bounds=dict(wall_seconds=WALL, rss_kb=RSS_KB),
                  binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),
                  original_program_sha256=hashlib.sha256(PROGRAM.encode()).hexdigest(),
                  cases={})
    failed = False
    for batches in (0, 1, 2, 3, 6, 12, 20):
        source = PROGRAM.replace('20.times do |batch|', str(batches) + '.times do |batch|')
        program = args.output / (str(batches) + '.rb')
        program.write_text(source)
        log = args.output / (str(batches) + '.log')
        execution = supervise([str(binary), '--disable-gems', str(program)],
                              env, log, RSS_KB, WALL)
        text = log.read_text(errors='replace')
        value = parse(text)
        complete = ([batch for batch, _ in value['samples_kb']] == list(range(batches + 1))
                    and 'METHOD_COPY_LIFETIME_COMPLETE\n' in text
                    and bool(value['stores']) and 'bytes_meth_src' in value['stores'])
        value.update(execution=execution, prefix_last_batch=batches,
                     original_workload_unchanged=batches == 20,
                     program_sha256=hashlib.sha256(source.encode()).hexdigest(),
                     raw_log_sha256=hashlib.sha256(log.read_bytes()).hexdigest(),
                     diagnostic_complete=complete)
        record['cases'][str(batches)] = value
        failed |= execution['exit'] != 0 or execution['limit'] is not None or not complete
        (args.output / 'result.json').write_text(json.dumps(record, indent=2) + '\n')
        print('diagnostic prefix', batches, execution, flush=True)
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
