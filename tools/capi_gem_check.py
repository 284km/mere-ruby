#!/usr/bin/env python3
"""Install real gems with C extensions on both rubies, and compare their use.

    capi_gem_check.py --reference <ruby binary> --output <dir> [--gems <dir>]

Published gems with C extensions, at fixed versions: fast_blank (one
function over a String's bytes), redcarpet (a Markdown renderer whose C calls
back into Ruby renderers), msgpack (a serializer: buffers, Integers of every
size, Floats, encodings, its own exception classes), racc (the parser
runtime's C core), bcrypt (a C library wrapped in two functions), nio4r (a
selector on libev, which the gem brings: the IO struct behind RFILE, and
readiness of real descriptors), and nokogiri, built from source against the system's
libxml2 and libxslt (`--use-system-libraries`; mini_portile2, which its
extconf.rb requires, is installed with it): typed data wrapping the
library's structs, callbacks from the library into Ruby (SAX), error
objects. And what Rails 8.1's own dependencies build, at the versions
railstest/ locks: erb (its escape, which ERB::Util.html_escape is), rbs (a
parser that builds Ruby AST objects), websocket-driver (the frame mask), puma
(the HTTP request parser) and sqlite3, against the system's SQLite
(`--enable-system-libraries`; callbacks into Ruby, BLOBs, transactions). Each
of those prints whether the extension it loaded is the one in the gem home --
a library the interpreter ships under the same name would pass otherwise.
(json, date, bigdecimal, io-console and prism build as well, but mere-ruby
loads its own library before an activated gem's extension -- issue #127.)
The .gem files are fetched once by the reference
ruby (or taken from --gems), and then each ruby installs them from those
files into a gem directory of its own with RubyGems' ordinary `gem install`:
extconf.rb, make, make install, all driven by that ruby.

capi/check/gems.rb then uses the gems on both sides and must print the
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
# (name, version, what `gem fetch` is given, what `gem install` is given)
GEMS = [('fast_blank', '1.0.1', [], []), ('redcarpet', '3.6.1', [], []), ('msgpack', '1.8.7', [], []),
        ('racc', '1.8.1', [], []), ('bcrypt', '3.1.22', [], []), ('nio4r', '2.7.5', [], []),
        ('mini_portile2', '2.8.9', [], []),
        ('nokogiri', '1.19.7', ['--platform', 'ruby'], ['--', '--use-system-libraries']),
        # (what Rails 8.1's own dependencies build, at railstest/'s locked
        #  versions, and the gems they need)
        ('erb', '6.0.7', [], []), ('logger', '1.7.0', [], []), ('tsort', '0.2.0', [], []),
        ('rbs', '4.2.0', [], []), ('base64', '0.3.0', [], []), ('websocket-extensions', '0.2.0', [], []),
        ('websocket-driver', '0.9.0', [], []), ('puma', '8.1.2', [], []),
        ('sqlite3', '2.10.2', ['--platform', 'ruby'], ['--', '--enable-system-libraries'])]
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
# Prefer this runtime's libraries before using the reference Ruby as a fallback.
# In particular, the reference monitor.rb requires an incompatible monitor.so.
runtime = subprocess.check_output(["sh", str(ROOT / "tools/runtime_load_path.sh"), str(MERE)],
                                  text=True, timeout=20).split(os.pathsep)
fetched = OUT / 'fetched'
fetched.mkdir()
(OUT / 'home').mkdir()
for name, version, fetch_options, _ in GEMS:
    file = f'{name}-{version}.gem'
    if args.gems:
        shutil.copy(args.gems.resolve() / file, fetched / file)
    else:
        subprocess.run([str(REF), gem_command, 'fetch', name, '--version', version, *fetch_options], cwd=fetched,
                       check=True, stdout=subprocess.DEVNULL)
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
        env['RUBYLIB'] = os.pathsep.join([*runtime, stdlib])
        env['MERE_RUBY_STDLIB_FALLBACK'] = stdlib
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
    for name, version, _, install_options in GEMS:
        installed = run(f'install-{name}', side, [ruby, gem_command, 'install', '--local', '--no-document',
                                                   f'{name}-{version}.gem', *install_options], homes[side], 600)
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
print('capi_gem_check: twelve gems with C extensions install with `gem install` and behave the same on both sides')
