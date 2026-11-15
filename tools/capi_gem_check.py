#!/usr/bin/env python3
"""Install real gems with C extensions on both rubies, and compare their use.

    capi_gem_check.py --reference <ruby binary> --output <dir> [--gems <dir>]

Three published gems, at fixed versions, each with a C extension and no
library of its own to find: fast_blank (one function over a String's bytes),
redcarpet (a Markdown renderer whose C calls back into Ruby renderers), and
msgpack (a serializer: buffers, Integers of every size, Floats, encodings,
its own exception classes). The .gem files are fetched once by the reference
ruby (or taken from --gems), and then each ruby installs them from those
files into a gem directory of its own with RubyGems' ordinary `gem install`:
extconf.rb, make, make install, all driven by that ruby.

capi/check/gems.rb then uses the three gems on both sides and must print the
same. As the control, mere-ruby is pointed at the gem directory the REFERENCE
installed into: it must fail there (those extensions were built for another
ruby), so what passed was mere-ruby's own build.

Each step is bounded: 600 seconds for an install, 120 for a run; 2 GiB.
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
GEMS = [('fast_blank', '1.0.1'), ('redcarpet', '3.6.1'), ('msgpack', '1.8.7')]
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--gems', type=Path, help='a directory that already holds the .gem files')
parser.add_argument('--mere', type=Path, default=ROOT / 'mere-ruby')
args = parser.parse_args()
REF, OUT, MERE = (p.resolve() for p in (args.reference, args.output, args.mere))
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise  # noqa: E402

# (RubyGems' own command, the reference installation's script: each ruby runs it)
gem_command = subprocess.check_output([str(REF), '-rrbconfig', '-e', 'print File.join(RbConfig::CONFIG["bindir"], "gem")'], text=True)
stdlib = subprocess.check_output([str(REF), '-rrbconfig', '-e', 'print RbConfig::CONFIG["rubylibdir"]'], text=True)
fetched = OUT / 'fetched'
fetched.mkdir()
(OUT / 'home').mkdir()
for name, version in GEMS:
    file = f'{name}-{version}.gem'
    if args.gems:
        shutil.copy(args.gems.resolve() / file, fetched / file)
    else:
        subprocess.run([str(REF), gem_command, 'fetch', name, '--version', version], cwd=fetched, check=True,
                       stdout=subprocess.DEVNULL)
    if not (fetched / file).is_file():
        sys.exit(f'capi_gem_check: {file} was not fetched')
results = {}


def run(key, side, command, home, seconds):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith('MERE_RUBY_') and k not in ('RUBYOPT', 'RUBYLIB', 'MAKEFLAGS', 'GEM_HOME', 'GEM_PATH')}
    # (a home of its own: no ~/.gemrc of the machine's decides how a gem is
    #  installed here)
    env.update(GEM_HOME=str(home), GEM_PATH=str(home), LANG='en_US.UTF-8', HOME=str(OUT / 'home'))
    if side == 'mere':
        env['RUBYLIB'] = stdlib
    log = OUT / f'{key}.{side}.out'
    old = Path.cwd()
    try:
        os.chdir(fetched)
        result = supervise([str(x) for x in command], env, log, 2 * 1024 * 1024, seconds)
    finally:
        os.chdir(old)
    result['output'] = log.read_text(errors='replace')
    results[f'{key}.{side}'] = {k: v for k, v in result.items() if k != 'output'}
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    result['ok'] = result['exit'] == 0 and result['limit'] is None
    return result


problems = []
homes = {}
for side, ruby in (('reference', REF), ('mere', MERE)):
    homes[side] = OUT / side / 'installed'
    homes[side].mkdir(parents=True)
    for name, version in GEMS:
        installed = run(f'install-{name}', side, [ruby, gem_command, 'install', '--local', '--no-document',
                                                   f'{name}-{version}.gem'], homes[side], 600)
        print(f"{side:10s} gem install {name} {version}: {'installed' if installed['ok'] else 'FAILED'}", flush=True)
        if not installed['ok']:
            problems.append(f'{side}: gem install {name} failed')
script = ROOT / 'capi' / 'check' / 'gems.rb'
outputs = {}
for side, ruby in (('reference', REF), ('mere', MERE)):
    used = run('use', side, [ruby, script], homes[side], 120)
    outputs[side] = used['output'] if used['ok'] else None
    if not used['ok']:
        problems.append(f'{side}: the gems could not be used')
same = outputs['reference'] is not None and outputs['reference'] == outputs['mere']
print(f"use        {'the same output on both sides' if same else 'DIFFERENT'} ({len((outputs['reference'] or '').splitlines())} lines)", flush=True)
if not same:
    problems.append('the gems behave differently on the two rubies')
other = run('other-ruby', 'mere', [MERE, script], homes['reference'], 120)
refused = not other['ok'] and other['limit'] is None
print(f"other-ruby {'fails, as it must' if refused else 'PASSED -- mere-ruby used extensions built for the reference'}", flush=True)
if not refused:
    problems.append('mere-ruby used the gems the reference built')
if problems:
    sys.exit('capi_gem_check: ' + '; '.join(problems))
print('capi_gem_check: three gems with C extensions install with `gem install` and behave the same on both sides')
