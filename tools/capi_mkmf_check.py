#!/usr/bin/env python3
"""Build extensions with ruby's own mkmf on both rubies, and compare.

    capi_mkmf_check.py --ruby-source <ruby> --reference <ruby binary> --output <dir>

An extension is built the way a gem's is: `ruby extconf.rb`, `make`,
`make install`. mkmf.rb is the reference ruby's file on both sides; what
differs is the RbConfig it reads -- the reference's, and the one mere-ruby
says of its own build (the compiler, the flags, where ruby.h is).

What each run is for:

  probe                capi/check/mkmf/probe: extconf.rb asks the compiler
                       about headers, functions (the C library's and
                       ruby's own), a macro, a size and a library; the
                       built library says what was answered
  float                ruby's ext/-test-/float through its own extconf.rb
  contracts            capi/check/mkmf.rb loads both libraries, on both
                       sides, and must print the same; on mere-ruby again
                       with a collection at every safepoint
  broken               a source that does not compile: extconf.rb succeeds
                       and `make` must FAIL, on both sides
  other-ruby           (negative) mere-ruby is given the libraries the
                       REFERENCE's mkmf built: the contracts must FAIL --
                       what passed above was built for mere-ruby

mere-ruby's Makefile must name capi/include as the directory of ruby.h, and
the reference's must not. Each run is bounded: 120 seconds, 2 GiB.
"""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
CHECK = ROOT / 'capi' / 'check'
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mere', type=Path, default=ROOT / 'mere-ruby')
args = parser.parse_args()
SRC, REF, OUT, MERE = (p.resolve() for p in (args.ruby_source, args.reference, args.output, args.mere))
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise  # noqa: E402

# (mere-ruby reads the standard library -- mkmf.rb among it -- from the
#  reference's directory, as everywhere else in the checks)
stdlib = subprocess.check_output([str(REF), '-rrbconfig', '-e', 'print RbConfig::CONFIG["rubylibdir"]'], text=True)
# Prefer this runtime's libraries before using the reference Ruby as a fallback.
# In particular, the reference monitor.rb requires an incompatible monitor.so.
runtime = subprocess.check_output(["sh", str(ROOT / "tools/runtime_load_path.sh"), str(MERE)],
                                  text=True, timeout=20).split(os.pathsep)
results = {}
problems = []


def run(key, side, command, cwd, extra=None, lib=None):
    env = {k: v for k, v in os.environ.items() if not k.startswith('MERE_RUBY_') and k not in ('RUBYOPT', 'RUBYLIB', 'MAKEFLAGS')}
    path = ([str(lib)] if lib else []) + ([*runtime, stdlib] if side == 'mere' else [])
    if path:
        env['RUBYLIB'] = os.pathsep.join(path)
    env['LANG'] = 'en_US.UTF-8'
    env['CAPI_CHECK_SIDE'] = side
    env.update(extra or {})
    log = OUT / f'{key}.{side}.out'
    old = Path.cwd()
    try:
        os.chdir(cwd)
        result = supervise([str(x) for x in command], env, log, 2 * 1024 * 1024, 120)
    finally:
        os.chdir(old)
    result['output'] = log.read_text(errors='replace')
    results[f'{key}.{side}'] = {k: v for k, v in result.items() if k != 'output'}
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    result['ok'] = result['exit'] == 0 and result['limit'] is None
    return result


def build(side, name, directory, extconf, make_args=()):
    """extconf.rb, make, make install; False at the first step that fails."""
    ruby = REF if side == 'reference' else MERE
    lib = OUT / side / 'lib'
    lib.mkdir(parents=True, exist_ok=True)
    for step, command in [
            ('extconf', [ruby, *extconf]),
            ('make', ['make', *make_args]),
            ('install', ['make', *make_args, 'install', f'sitearchdir={lib}', f'sitelibdir={lib}'])]:
        if not run(f'{name}-{step}', side, command, directory)['ok']:
            return step
    return None


libs = {}
for side in ('reference', 'mere'):
    work = OUT / side
    libs[side] = work / 'lib'
    # the probe
    probe = work / 'probe'
    shutil.copytree(CHECK / 'mkmf' / 'probe', probe)
    failed = build(side, 'probe', probe, ['extconf.rb'])
    if failed:
        problems.append(f'{side}: the probe extension stopped at {failed}')
    makefile = (probe / 'Makefile').read_text() if (probe / 'Makefile').exists() else ''
    ours = str(ROOT / 'capi' / 'include') in makefile
    if ours != (side == 'mere'):
        problems.append(f"{side}: the Makefile {'names' if ours else 'does not name'} mere-ruby's capi/include")
    # ruby's own ext/-test-/float, by its own extconf.rb (which ruby's build
    # runs with mkmf already loaded, and with the source tree as top_srcdir)
    tree = work / 'tree'
    (tree / 'ext' / '-test-').mkdir(parents=True)
    shutil.copy(SRC / 'ext' / '-test-' / 'auto_ext.rb', tree / 'ext' / '-test-')
    shutil.copytree(SRC / 'ext' / '-test-' / 'float', tree / 'ext' / '-test-' / 'float')
    (tree / 'missing').mkdir()
    shutil.copy(SRC / 'missing' / 'nextafter.c', tree / 'missing')
    floatdir = tree / 'ext' / '-test-' / 'float'
    failed = build(side, 'float', floatdir, ['-r', 'mkmf', floatdir / 'extconf.rb'], [f'top_srcdir={tree}'])
    if failed:
        problems.append(f'{side}: ext/-test-/float stopped at {failed}')
    # a source that does not compile
    broken = work / 'broken'
    shutil.copytree(CHECK / 'mkmf' / 'broken', broken)
    failed = build(side, 'broken', broken, ['extconf.rb'])
    print(f"{side:10s} broken: {'make fails, as it must' if failed == 'make' else 'stopped at ' + str(failed)}", flush=True)
    if failed != 'make':
        problems.append(f'{side}: the source that does not compile stopped at {failed}, not at make')


def passed(result):
    lines = [l for l in result['output'].splitlines() if l.endswith(' passed')]
    return lines[-1] if result['ok'] and lines else None


script = CHECK / 'mkmf.rb'
answers = {side: passed(run('contracts', side, [REF if side == 'reference' else MERE, script], OUT, lib=libs[side]))
           for side in ('reference', 'mere')}
stress = passed(run('stress', 'mere', [MERE, script], OUT, {'MERE_RUBY_GC_STRESS': '1'}, lib=libs['mere']))
print(f"contracts  reference: {answers['reference']} | mere-ruby: {answers['mere']} | under stress: {stress}", flush=True)
if not answers['reference'] or answers['mere'] != answers['reference'] or stress != answers['mere']:
    problems.append('the mkmf contracts do not agree on both sides')
other = run('other-ruby', 'mere', [MERE, script], OUT, lib=libs['reference'])
refused = passed(other) is None and other['limit'] is None
print(f"other-ruby {'fails, as it must' if refused else 'PASSED -- the contracts do not see whose library they load'}", flush=True)
if not refused:
    problems.append('mere-ruby passed the contracts with the libraries built for the reference')
if problems:
    sys.exit('capi_mkmf_check: ' + '; '.join(problems))
print("capi_mkmf_check: ruby's mkmf builds the same extensions on both sides, and each control fails")
