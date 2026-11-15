#!/usr/bin/env python3
"""Build native probes with unchanged upstream mkmf, then load and test them."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mere', type=Path)
parser.add_argument('--side', choices=['both', 'mere', 'reference'], default='both')
parser.add_argument('--sanitize-extension', action='store_true')
opts = parser.parse_args()
if sys.platform != 'darwin':
    parser.error('this prototype currently describes macOS builds')
WT = Path(__file__).resolve().parents[2]
SRC, REF, OUT = opts.ruby_source.resolve(), opts.reference.resolve(), opts.output.resolve()
MERE = opts.mere.resolve() if opts.mere else WT/'mere-ruby'
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
sys.path.insert(0, str(WT/'unittest'))
from ci import supervise

source_files = ['ext/-test-/float/extconf.rb', 'ext/-test-/float/init.c',
                'ext/-test-/float/nextafter.c', 'ext/-test-/auto_ext.rb', 'missing/nextafter.c']
inputs = source_files + ['lib/mkmf.rb', 'test/-ext-/float/test_nextafter.rb', 'test/mkmf/test_mkmf.rb']
def hashes():
    return {p: hashlib.sha256((SRC/p).read_bytes()).hexdigest() for p in inputs}
before = hashes()
staged = OUT/'source'
# Stage only the source inputs. CRuby's generated internal-header dependency
# list is not portable to this limited header set; mkmf creates dependencies.
for p in source_files:
    dest = staged/p
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(SRC/p, dest)
fixture = staged/'fixtures'
fixture.mkdir()
for name in ['loader_fixture', 'loader_retry', 'loader_nested']:
    shutil.copy2(WT/f'tools/native_probe/{name}.c', fixture/f'{name}.c')
(fixture/'loader_missing_init.c').write_text('#include <ruby.h>\nvoid Init_other(void) {}\n')
(fixture/'loader_wrongabi.c').write_text('void Init_loader_wrongabi(void) {}\n')
(fixture/'extconf.rb').write_text('''require 'mkmf'
raise 'stdlib header unavailable' unless have_header('stdlib.h')
raise 'malloc unavailable' unless have_func('malloc', 'stdlib.h')
raise 'missing header falsely accepted' if have_header('mere_nonexistent_probe_header.h')
raise 'missing symbol falsely accepted' if have_func('mere_nonexistent_probe_symbol', 'stdlib.h')
name = ENV.fetch('NATIVE_BUILD_FEATURE')
$srcs = [name + '.c']
create_makefile(name)
''')
stdlib = subprocess.check_output([str(REF), '-e',
    'print(([RbConfig::CONFIG["rubylibdir"]]+Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":"))'], text=True)
results = {}
def run(key, cmd, env, cwd, expected='', failure=False):
    cwd.mkdir(parents=True, exist_ok=True)
    old = Path.cwd()
    try:
        os.chdir(cwd)
        r = supervise([str(x) for x in cmd], env, OUT/(key+'.out'), 2*1024*1024, 90)
    finally:
        os.chdir(old)
    output = (OUT/(key+'.out')).read_text()
    r['verified'] = r['limit'] is None and ((r['exit'] != 0) if failure else (r['exit'] == 0)) and expected in output
    r['verified'] = r['verified'] and 'ERROR: AddressSanitizer' not in output and 'runtime error:' not in output
    r['command'] = [str(x) for x in cmd]
    results[key] = r
    (OUT/'results.json').write_text(json.dumps(results, indent=2)+'\n')
    print(key, json.dumps({k:v for k,v in r.items() if k != 'command'}), flush=True)
    if not r['verified']:
        print(output[-4000:], flush=True)
        raise AssertionError(key)
    return output

for side, binary in [('reference', REF), ('mere', MERE)]:
    if opts.side != 'both' and opts.side != side: continue
    env = dict(os.environ)
    for knob in ['RUBYOPT', 'MERE_LOADER_TEST', 'MERE_RUBY_GC_STRESS', 'MERE_RUBY_GC_DBG',
                 'MERE_TYPED_SKIP_MARK', 'MERE_TYPED_SKIP_FREE', 'MERE_NATIVE_SKIP_ENSURE',
                 'MERE_NATIVE_PROBE_NO_ROOT']:
        env.pop(knob, None)
    lib = OUT/(side+'-lib')
    (lib/'-test-').mkdir(parents=True)
    libs = [str(lib), str(SRC/'lib'), str(SRC/'tool/lib'), str(SRC/'test')]
    if side == 'mere':
        libs += [str(WT/'unittest/shim'), stdlib]
        env['MERE_LOADER_TEST'] = '1'
        if opts.sanitize_extension: env['ASAN_OPTIONS'] = 'use_sigaltstack=0'
    env.update(RUBYLIB=os.pathsep.join(libs), RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
               PATH=str(WT/'unittest/child-bin')+os.pathsep+env['PATH'], LOADER_LIB=str(lib))
    config = ['-r', str(WT/'tools/native_probe/build_config.rb')] if side == 'mere' else []
    flags = ['--with-cflags=-O2 -g -fsanitize=address,undefined -fno-sanitize-recover=all',
             '--with-dldflags=-fsanitize=address,undefined'] if side == 'mere' and opts.sanitize_extension else []
    for feature in ['float', 'loader_fixture', 'loader_retry', 'loader_nested', 'loader_missing_init', 'loader_wrongabi']:
        build = OUT/side/feature
        e = dict(env, NATIVE_BUILD_FEATURE=feature)
        extconf = staged/'ext/-test-/float/extconf.rb' if feature == 'float' else fixture/'extconf.rb'
        run(f'configure-{feature}.{side}', [binary, *config, '-rmkmf', extconf, *flags], e, build, 'creating Makefile')
        makefile = (build/'Makefile').read_text()
        assert 'PROBE_TYPED_API' in makefile if side == 'mere' else 'PROBE_TYPED_API' not in makefile
        run(f'make-{feature}.{side}', ['make', 'V=1', 'top_srcdir='+str(staged)], e, build)
        bundle = build/(feature+'.bundle')
        assert bundle.is_file(), bundle
        target = lib/'-test-/float.bundle' if feature == 'float' else lib/bundle.name
        shutil.copy2(bundle, target)
        if side == 'mere':
            linked = subprocess.check_output(['otool', '-L', str(bundle)], text=True)
            assert 'libruby' not in linked.lower(), linked
    # The same loader behavior checks now consume only mkmf-produced bundles.
    (lib/'alias').mkdir()
    (lib/'alias/loader_fixture.bundle').symlink_to(lib/'loader_fixture.bundle')
    (lib/'loader_shadow.bundle').symlink_to(lib/'loader_fixture.bundle')
    (lib/'loader_shadow.rb').write_text('$loader_shadow = :ruby\n')
    (lib/'relative_driver.rb').write_text("$relative_native = require_relative 'loader_fixture'\n")
    work = OUT/side/'run'
    for name, file, extra, expected in [
        ('loader', WT/'tools/native_probe/loader.rb', {}, f"native loader contracts: {46 if side=='reference' else 50} passed"),
        ('numeric', WT/'tools/native_probe/numeric.rb', {}, 'native numeric contracts: 13 passed'),
        ('private', WT/'tools/native_probe/implicit_private_block.rb', {}, ':no_block\n:block\n:direct\nexplicit_private_refused\n:singleton\n'),
        ('nextafter', SRC/'test/-ext-/float/test_nextafter.rb', {}, '400 tests, 1225 assertions, 0 failures, 0 errors, 0 skips'),
        ('loader-stress', WT/'tools/native_probe/loader.rb', {'MERE_RUBY_GC_STRESS':'1'}, 'native loader contracts: 50 passed'),
        ('numeric-stress', WT/'tools/native_probe/numeric.rb', {'MERE_RUBY_GC_STRESS':'1'}, 'native numeric contracts: 13 passed'),
    ]:
        if side == 'reference' and name.endswith('-stress'): continue
        e = dict(env, **extra)
        # A collection at every safepoint: the contracts need only their own
        # library. With the standard library on the path, a require that is
        # refused goes on through RubyGems' search, which is minutes here.
        if name.endswith('-stress'): e['RUBYLIB'] = str(lib)
        args = ['-r', 'test/unit', '-r', str(WT/'unittest/bootstrap.rb')] if name == 'nextafter' else []
        run(name+'.'+side, [binary, *args, file, *(['-v', '--seed=1'] if name == 'nextafter' else [])], e, work, expected)
    run('mkmf-global.'+side,
        [binary, *config, '-rtest/unit', '-r', WT/'unittest/bootstrap.rb', SRC/'test/mkmf/test_mkmf.rb', '-v', '--seed=1'],
        env, work, '94 tests, 188 assertions, 0 failures, 0 errors, 0 skips')
    # A real compiler failure must stop extconf before producing a Makefile.
    if side == 'mere':
        bad = OUT/side/'compiler-failure'
        run('compiler-failure.mere', [binary, *config, '-rmkmf', fixture/'extconf.rb'],
            dict(env, CC='false', NATIVE_BUILD_FEATURE='loader_fixture'), bad,
            'The compiler failed to generate an executable file.', failure=True)
        assert not (bad/'Makefile').exists()
assert hashes() == before, 'upstream input changed'
for p in source_files:
    assert hashlib.sha256((staged/p).read_bytes()).hexdigest() == before[p], p
(OUT/'input-hashes.json').write_text(json.dumps(before, indent=2)+'\n')
assert len(results) == {'both':37, 'reference':17, 'mere':20}[opts.side] and all(r['verified'] for r in results.values())
print('all mkmf build/load outcomes verified; original inputs unchanged', flush=True)
