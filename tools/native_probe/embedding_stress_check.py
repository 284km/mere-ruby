#!/usr/bin/env python3
"""Check retained state and allocation growth in an existing embedding archive.

First build the archive with embedding_check.py. This checks fixed workloads;
it does not assert bounded memory for arbitrary Ruby programs. The same gate
checks both per-evaluation temporaries and historical string-page metadata.
"""
from pathlib import Path
from native_build_flags import openssl_flags
import argparse
import json
import os
import platform
import re
import sys
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--library-dir', type=Path, required=True)
parser.add_argument('--prism-lib', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
library = args.library_dir.resolve()
prism = args.prism_lib.resolve()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

results = {}
def run(name, command, seconds=90):
    log = output / (name + '.out')
    command = list(map(str, command))
    result = supervise(command, dict(os.environ, MERE_REGION_STATS='1'), log,
                       2097152, seconds)
    result['command'] = command
    results[name] = result
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert result['exit'] == 0 and result['limit'] is None, (name, result)
    print(name, 'passed', flush=True)
    return log.read_text()

openssl_cflags, openssl_ldflags = openssl_flags()
flags = ['clang', '-O2', '-w', '-I', library, '-I', FIXTURES,
         '-I', ROOT / 'vendor/prism/include'] + openssl_cflags
libs = [library / 'libmere_embedding_probe.a', ROOT / 'tools/prism_glue.c',
        ROOT / 'tools/socket_glue.c', ROOT / 'tools/math_glue.c', ROOT / 'tools/process_glue.c',
        ROOT / 'tools/openssl_glue.c', ROOT / 'tools/nkf_glue.c', prism, '-pthread', *openssl_ldflags]
if platform.system() == 'Darwin':
    libs += ['-Wl,-stack_size,0x20000000']
else:
    import resource
    _, hard = resource.getrlimit(resource.RLIMIT_STACK)
    bound = 512 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_STACK, (bound if hard < 0 else min(bound, hard), hard))
    libs += ['-lm', '-ldl']

for fixture in ['memory', 'retained']:
    run('link-' + fixture, flags + [FIXTURES / ('embedding_' + fixture + '.c'),
                                    *libs, '-o', output / fixture])
run('retained', [output / 'retained'])
totals = {}
for mode in ['scalar', 'churn']:
    totals[mode] = {}
    for count in [1000, 10000, 100000]:
        text = run(mode + '-' + str(count), [output / 'memory', mode, count], 180)
        matches = re.findall(r'^region-stats default: .*alloc_total=(\d+)$', text, re.M)
        assert len(matches) == 1, 'missing or ambiguous allocator statistics'
        totals[mode][count] = int(matches[0])
    (output / 'allocation-totals.json').write_text(json.dumps(totals, indent=2) + '\n')
# A small fixed allowance accommodates startup/sampling differences. The
# former per-evaluation retention exceeds it even at 10,000 evaluations.
violations = {mode: counts for mode, counts in totals.items()
              if max(counts.values()) - min(counts.values()) > 1024}
assert not violations, ('unresolved allocation growth', violations)
print('Retained state and fixed-workload allocation checks passed', flush=True)
