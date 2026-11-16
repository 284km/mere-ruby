#!/usr/bin/env python3
"""Check target header generation and failures with a real C compiler."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--cc', default='cc')
parser.add_argument('--cflags', default='-O2')
opts = parser.parse_args()
out = opts.output.resolve()
out.mkdir(parents=True, exist_ok=False)
script = Path(__file__).with_name('configure_headers.py')
env = dict(os.environ)
for key in ['CC', 'CXX', 'CFLAGS', 'CXXFLAGS', 'CPPFLAGS', 'LDFLAGS']:
    env.pop(key, None)
results = {}


def run(name, cmd, success, source=None):
    r = subprocess.run(cmd, input=source, text=True, capture_output=True, env=env, timeout=120)
    (out/(name+'.out')).write_text(r.stdout+r.stderr)
    results[name] = {'command':cmd, 'exit':r.returncode}
    assert (r.returncode == 0) == success, (name, r.stdout, r.stderr)


target = out/'target with spaces'
base = [sys.executable, str(script), '--cflags='+opts.cflags]
run('generate', base+['--cc', opts.cc, '--output', str(target)], True)
manifest = target/'config.json'
before = hashlib.sha256(manifest.read_bytes()).hexdigest()
run('refuse-existing', base+['--cc', opts.cc, '--output', str(target)], False)
assert hashlib.sha256(manifest.read_bytes()).hexdigest() == before
for name, cc in [('compiler-failure', 'false'), ('false-positive-compiler', 'true')]:
    dest = out/name
    run(name, base+['--cc', cc, '--output', str(dest)], False)
    assert not dest.exists()
bad = out/'invalid-flags'
run('invalid-flags', base+['--cc', opts.cc, '--output', str(bad),
                          '--cppflags=-include mere_nonexistent_config_header.h'], False)
assert not bad.exists()
command = shlex.split(opts.cc)+shlex.split(opts.cflags)
source = '#include <ruby.h>\n#include <ruby/config.h>\nint probe(void) { return CHAR_BIT; }\n'
run('consumer', command+['-I',str(target/'include'),'-x','c','-c','-o',str(out/'consumer.o'),'-'], True, source)
altered = out/'wrong-layout'
shutil.copytree(target/'include', altered)
f = altered/'ruby/target_sizes.h'
f.write_text(f.read_text().replace('#define SIZEOF_VALUE 4', '#define SIZEOF_VALUE 8'))
run('reject-wrong-layout', command+['-I',str(altered),'-x','c','-c','-o',str(out/'bad.o'),'-'], False, source)
assert not list(out.glob('.native-config-*')), 'temporary generation directory leaked'
results['manifest'] = json.loads(manifest.read_text())
(out/'results.json').write_text(json.dumps(results, indent=2)+'\n')
print('7 configuration checks passed; target code was not linked or executed')
