#!/usr/bin/env python3
"""Reproduce the synchronous ensured.c experiment on macOS, with bounded runs."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
opts = parser.parse_args()
if sys.platform != 'darwin':
    parser.error('this investigation currently builds macOS bundles only')
WT = Path(__file__).resolve().parents[2]
SRC = opts.ruby_source.resolve()
REF = opts.reference.resolve()
HERE = opts.output.resolve()
HERE.mkdir(parents=True, exist_ok=True)
inputs = [SRC/'ext/-test-/exception/ensured.c',
          SRC/'test/-ext-/exception/test_ensured.rb',
          SRC/'test/-ext-/exception/test_exception_at_throwing.rb']
digests = {str(p.relative_to(SRC)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
headers = subprocess.check_output([str(REF), '-rrbconfig', '-e',
    'puts RbConfig::CONFIG.values_at("rubyhdrdir", "rubyarchhdrdir")'], text=True).splitlines()
ref_lib = HERE/'reference-lib/-test-'
ref_lib.mkdir(parents=True, exist_ok=True)
init = HERE/'reference-init.c'
init.write_text('#include <ruby.h>\nvoid Init_ensured(VALUE);\n'
                'void Init_exception(void) { Init_ensured(rb_define_module_under(rb_define_module("Bug"), "Exception")); }\n')
subprocess.run(['clang', '-bundle', '-undefined', 'dynamic_lookup', '-O2',
    '-I', str(WT/'tools/native_probe/include'), str(inputs[0]),
    '-o', str(HERE/'ensured.bundle')], check=True)
subprocess.run(['clang', '-bundle', '-undefined', 'dynamic_lookup', '-O2',
    *[arg for header in headers for arg in ['-I', header]], str(inputs[0]), str(init),
    '-o', str(ref_lib/'exception.bundle')], check=True)
sys.path.insert(0, str(WT / 'unittest'))
from ci import supervise
stdlib = subprocess.check_output([str(REF), '-e', 'print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))'], text=True)
results = {}
for side, binary, lib in [('reference', REF, HERE/'reference-lib'), ('mere', WT/'mere-ruby', WT/'tools/native_probe/lib')]:
    for name, filename, extra in [
        ('contracts', WT/'tools/native_probe/ensure.rb', {}),
        ('contracts-stress', WT/'tools/native_probe/ensure.rb', {'MERE_RUBY_GC_STRESS':'1'}),
        ('negative-skip-ensure', WT/'tools/native_probe/ensure.rb', {'MERE_NATIVE_SKIP_ENSURE':'1'}),
        ('original-ensured', SRC/'test/-ext-/exception/test_ensured.rb', {}),
        ('original-throwing', SRC/'test/-ext-/exception/test_exception_at_throwing.rb', {}),
        ('original-throwing-no-ensure', SRC/'test/-ext-/exception/test_exception_at_throwing.rb', {'MERE_NATIVE_SKIP_ENSURE':'1'}),
    ]:
        key = name+'.'+side
        if side=='reference' and name in ['contracts-stress','negative-skip-ensure','original-throwing-no-ensure']: continue
        env = dict(os.environ)
        for knob in ['MERE_NATIVE_SKIP_ENSURE', 'MERE_NATIVE_PROBE_NO_ROOT', 'MERE_RUBY_GC_STRESS']:
            env.pop(knob, None)
        env.update(
            RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
            UNITTEST_TEST_FILE=str(filename.relative_to(SRC/'test')) if name.startswith('original') else '',
            PATH=str(WT/'unittest/child-bin')+os.pathsep+env['PATH'],
            MERE_NATIVE_ENSURED_MODULE=str(HERE/'ensured.bundle'))
        libs = [str(lib), str(SRC/'tool/lib'), str(SRC/'test')]
        if side=='mere': libs += [str(WT/'unittest/shim'),stdlib]
        env['RUBYLIB'] = os.pathsep.join(libs)
        env.update(extra)
        cmd = [str(binary)]
        if name.startswith('original'): cmd += ['-r', 'test/unit', '-r', str(WT/'unittest/bootstrap.rb')]
        cmd += [str(filename)]
        if name.startswith('original'): cmd += ['-v','--seed=1']
        log = HERE/(key+'.out')
        result = supervise(cmd, env, log, 2*1024*1024, 90)
        output = log.read_text()
        expected = name in ['negative-skip-ensure','original-throwing-no-ensure']
        marker = 'normal cleanup once' if name=='negative-skip-ensure' else '1 failures'
        if expected:
            matched = result['exit'] != 0 and marker in output
        elif name.startswith('original'):
            count = 4 if name == 'original-ensured' else 5
            marker = f'1 tests, {count} assertions, 0 failures, 0 errors, 0 skips'
            matched = result['exit'] == 0 and marker in output
        else:
            count = 58 if side == 'reference' else 62
            matched = result['exit'] == 0 and f'native ensure contracts: {count} passed' in output
        result['verified'] = result['limit'] is None and matched
        results[key] = result
        (HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        print(key,json.dumps(result),flush=True)
        if not result['verified']: print(output[-2500:],flush=True)
after = {str(p.relative_to(SRC)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
assert digests == after, 'the original Ruby inputs changed during validation'
(HERE/'input-hashes.json').write_text(json.dumps(digests, indent=2)+'\n')
assert len(results) == 9 and all(r['verified'] for r in results.values()), results
print('all native ensure outcomes verified; original inputs unchanged', flush=True)
