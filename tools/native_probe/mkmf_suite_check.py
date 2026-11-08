#!/usr/bin/env python3
"""Measure the unchanged upstream mkmf suite in isolated build trees.

Exit zero means that measurement completed, not that all Ruby tests passed.
Setup errors, resource limits, incomplete transcripts and changed inputs fail.
"""
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
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--reference-build', type=Path,
                    help='matching CRuby build libraries; defaults to --ruby-source')
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mere', type=Path)
opts = parser.parse_args()
if sys.platform != 'darwin':
    parser.error('this prototype currently describes macOS builds')
WT = Path(__file__).resolve().parents[2]
SRC, REF, OUT = opts.ruby_source.resolve(), opts.reference.resolve(), opts.output.resolve()
REF_BUILD = opts.reference_build.resolve() if opts.reference_build else SRC
MERE = opts.mere.resolve() if opts.mere else WT/'mere-ruby'
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
sys.path.insert(0, str(WT/'unittest'))
from ci import supervise
import transcript


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(name, value):
    (OUT/name).write_text(json.dumps(value, indent=2)+'\n')


inputs = sorted(p.relative_to(SRC) for p in (SRC/'test/mkmf').rglob('*') if p.is_file())
inputs.append(Path('lib/mkmf.rb'))
files = sorted((SRC/'test/mkmf').glob('test_*.rb'))
if not files:
    parser.error('no upstream mkmf tests found')
before = {str(p): digest(SRC/p) for p in inputs}
config = json.loads(subprocess.check_output([str(REF), '-rrbconfig', '-rjson', '-e',
    'puts JSON.generate(RbConfig::CONFIG)'], text=True))
stdlib = subprocess.check_output([str(REF), '-e',
    'print(([RbConfig::CONFIG["rubylibdir"]]+Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":"))'], text=True)
manifest = dict(inputs=before, files=[p.name for p in files],
                binaries={str(p): digest(p) for p in [REF, MERE]},
                support={str(p.relative_to(WT)): digest(p) for p in [
                    Path(__file__).resolve(), WT/'tools/native_probe/mkmf_test_bootstrap.rb',
                    WT/'tools/native_probe/build_config.rb', WT/'unittest/bootstrap.rb',
                    WT/'unittest/child-bin/ruby']},
                probe_headers={str(p.relative_to(WT)): digest(p)
                    for p in (WT/'tools/native_probe/include').rglob('*') if p.is_file()},
                reference_config=config, reference_libraries={},
                limits=dict(seconds=90, process_family_rss_kib=2*1024*1024))
save('manifest.json', manifest)
results = {}


def run(key, cmd, env, cwd, *, expected=None, failure=False, test=False):
    cwd.mkdir(parents=True, exist_ok=True)
    old = Path.cwd()
    try:
        os.chdir(cwd)
        r = supervise([str(x) for x in cmd], env, OUT/(key+'.out'), 2*1024*1024, 90)
    finally:
        os.chdir(old)
    output = (OUT/(key+'.out')).read_text()
    r['command'] = [str(x) for x in cmd]
    if test:
        r['transcript'] = transcript.parse(OUT/(key+'.out'), r['exit'])
        valid = r['transcript']['state'] == 'COMPLETE'
    else:
        valid = (r['exit'] != 0 if failure else r['exit'] == 0)
    r['verified'] = r['limit'] is None and valid and (expected is None or expected in output)
    results[key] = r
    save('results.json', results)
    print(key, r.get('transcript', {}).get('summary', r['exit']), flush=True)
    if not r['verified']:
        raise RuntimeError(f'{key}: invalid measurement; see {OUT/(key+".out")}')
    return r


# Check both explicit interpreter children and PATH-based children, with the
# same -w/-I/-C switches used by upstream subprocess assertions. A raw binary
# without the preload must fail this check, so it cannot silently use the host.
inheritance = OUT/'configuration.rb'
inheritance.write_text('''require 'rbconfig'
unless RbConfig::CONFIG['topdir'] == ENV.fetch('NATIVE_MKMF_BUILD') &&
       defined?($top_srcdir) && $top_srcdir == ENV.fetch('NATIVE_MKMF_SOURCE')
  abort 'mkmf build configuration missing'
end
if ARGV == ['parent']
  [ENV.fetch('RUBY'), 'ruby'].each do |ruby|
    ok = system(ruby, '-w', '-I', File.join(ENV.fetch('NATIVE_MKMF_SOURCE'), 'lib'),
                '-C', ENV.fetch('NATIVE_MKMF_BUILD'), __FILE__, 'child')
    raise 'child configuration missing' unless ok
  end
end
puts 'mkmf configuration inherited'
''')
compiler = OUT/'compiler.rb'
compiler.write_text('''require 'mkmf/base'
extend TestMkmf::Base
setup
begin
  raise 'positive link failed' unless try_link('int main(void){return 0;}')
  raise 'missing header accepted' if have_header('mere_nonexistent_probe_header.h')
  raise 'missing symbol accepted' if have_func('mere_nonexistent_probe_symbol', 'stdlib.h')
  puts 'mkmf compiler preflight passed'
ensure
  puts File.read('mkmf.log') if File.exist?('mkmf.log')
  teardown
end
''')

for side, binary in [('reference', REF), ('mere', MERE)]:
    base = OUT/side
    source, build = base/'source', base/'build'
    build.mkdir(parents=True)
    for p in inputs:
        dest = source/p
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SRC/p, dest)
    # Each runtime uses only its own headers and libraries. The in-tree mkmf
    # linker selects LIBRUBYARG_STATIC even for a shared installed CRuby.
    inc = WT/'tools/native_probe/include' if side == 'mere' else Path(config['rubyhdrdir'])
    (source/'include').symlink_to(inc)
    arch = build/'.ext/include'/config['arch']
    arch.parent.mkdir(parents=True)
    arch.symlink_to(inc if side == 'mere' else Path(config['rubyarchhdrdir']))
    if side == 'reference':
        for name in dict.fromkeys([config['LIBRUBY_A'], config['LIBRUBY']]):
            if not name:
                continue
            target = Path(config['libdir'])/name
            if not target.is_file():
                target = REF_BUILD/name
            if not target.is_file():
                raise FileNotFoundError(f'matching reference library required: {target}')
            (build/name).symlink_to(target)
            manifest['reference_libraries'][str(target)] = digest(target)
    launcher = base/'ruby'
    launcher.write_text('#!/bin/sh\nexec '+shlex.quote(str(binary))+' -r '+
                       shlex.quote(str(WT/'tools/native_probe/mkmf_test_bootstrap.rb'))+' "$@"\n')
    launcher.chmod(0o755)
    env = dict(os.environ)
    for key in ['RUBYOPT', 'APPVEYOR', 'MERE_LOADER_TEST', 'MERE_RUBY_GC_STRESS',
                'MERE_RUBY_GC_DBG', 'MERE_TYPED_SKIP_MARK', 'MERE_TYPED_SKIP_FREE',
                'MERE_NATIVE_SKIP_ENSURE', 'MERE_NATIVE_PROBE_NO_ROOT']:
        env.pop(key, None)
    libs = [str(source/'lib'), str(SRC/'tool/lib'), str(source/'test'), str(SRC/'test')]
    if side == 'mere':
        libs += [str(WT/'unittest/shim'), stdlib]
    env.update(RUBYLIB=os.pathsep.join(libs), RUBY=str(launcher),
               UNITTEST_CHILD_RUBY=str(launcher), NATIVE_MKMF_SIDE=side,
               NATIVE_MKMF_BUILD=str(build), NATIVE_MKMF_SOURCE=str(source),
               PATH=str(WT/'unittest/child-bin')+os.pathsep+env['PATH'])
    run('inheritance-negative.'+side, [binary, inheritance], env, base/'negative',
        expected='mkmf build configuration missing', failure=True)
    run('inheritance.'+side, [launcher, inheritance, 'parent'], env, base/'inheritance',
        expected='mkmf configuration inherited')
    run('metadata.'+side, [launcher, '-rmkmf', '-e', 'create_makefile("mkmf_environment")'],
        env, build, expected='creating Makefile')
    run('compiler.'+side, [launcher, compiler], env, base/'compiler',
        expected='mkmf compiler preflight passed')
    for file in files:
        key = file.stem+'.'+side
        run(key, [launcher, '-rtest/unit', '-r', WT/'unittest/bootstrap.rb',
                  source/'test/mkmf'/file.name, '-v', '--show-skip', '--seed=1'],
            dict(env, UNITTEST_TEST_FILE='mkmf/'+file.name), base/file.stem, test=True)

comparison = {}
for file in files:
    ref, mere = [results[file.stem+'.'+side]['transcript'] for side in ['reference', 'mere']]
    if ref['cases'].keys() != mere['cases'].keys():
        raise AssertionError(f'{file.name}: different case inventories')
    counts, _ = transcript.compare(ref, mere)
    comparison[file.name] = dict(reference=ref['summary'], mere=mere['summary'], comparison=counts)
assert before == {str(p): digest(SRC/p) for p in inputs}, 'upstream inputs changed'
for side in ['reference', 'mere']:
    assert before == {str(p): digest(OUT/side/'source'/p) for p in inputs}, 'staged inputs changed'
save('manifest.json', manifest)
save('comparison.json', comparison)
print(f'Measured {len(files)} files on both runtimes; see comparison.json for failures and skips.')
