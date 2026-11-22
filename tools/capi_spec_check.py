#!/usr/bin/env python3
"""ruby/spec's C API specs (optional/capi) on both rubies.

    capi_spec_check.py --ruby-source <ruby> --reference <ruby binary> --output <dir>
                       [--write] [name ...]

ruby/spec has a spec file for each part of the C API (array_spec.rb,
string_spec.rb, ...) and, beside it, the C extension that calls the functions
the examples are about (ext/array_spec.c). Each extension is built twice --
against the reference's headers and against mere-ruby's -- and each spec file
is run on both rubies with the spec shim the rest of this repository's spec
runs use (mspec/spec_helper.rb). ruby/spec's own helper for these files
builds the extensions with mkmf as it goes; here they are built beforehand,
and the helper is replaced by one that loads them.

What is compared is the count of examples that pass, file by file, with the
record in capi/check/spec_expect.tsv:

  - the reference's count must be the recorded one (the specs are part of the
    pinned ruby source: a different count is a different subject);
  - mere-ruby's count must not be LOWER than the recorded one. Higher is
    progress, and --write records it.

A file that does not reach its report (an extension that does not load, a
crash, the time bound) counts as nothing passing, and says which.

Each run is bounded: 120 seconds, 2 GiB.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import os
import re
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
EXPECT = ROOT / 'capi' / 'check' / 'spec_expect.tsv'
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mere', type=Path, default=ROOT / 'mere-ruby')
parser.add_argument('--write', action='store_true', help='record the counts instead of comparing them')
parser.add_argument('names', nargs='*', help='only the spec files whose name contains one of these')
args = parser.parse_args()
SRC, REF, OUT, MERE = (p.resolve() for p in (args.ruby_source, args.reference, args.output, args.mere))
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise  # noqa: E402

SPEC = SRC / 'spec' / 'ruby'
CAPI = SPEC / 'optional' / 'capi'
darwin = sys.platform == 'darwin'
DLEXT = '.bundle' if darwin else '.so'
LINK = ['-bundle', '-undefined', 'dynamic_lookup'] if darwin else ['-shared']
reference_headers = subprocess.check_output(
    [str(REF), '-rrbconfig', '-e', 'puts RbConfig::CONFIG.values_at("rubyhdrdir", "rubyarchhdrdir")'], text=True).split()
stdlib = subprocess.check_output([str(REF), '-rrbconfig', '-e', 'print RbConfig::CONFIG["rubylibdir"]'], text=True)

# The spec tree: the directories the capi specs and their fixtures require
# from, the shim as the root spec_helper.rb, and a helper for optional/capi
# that loads the extension built beforehand.
tree = OUT / 'tree'
for directory in ('optional', 'shared', 'fixtures', 'core', 'language'):
    shutil.copytree(SPEC / directory, tree / directory)
shutil.copy(ROOT / 'mspec' / 'spec_helper.rb', tree / 'spec_helper.rb')
(tree / 'optional' / 'capi' / 'spec_helper.rb').write_text('''require 'rbconfig'
def object_path = ENV.fetch('CAPI_SPEC_EXT')
def compile_extension(name) = File.join(object_path, "#{name}_spec.#{RbConfig::CONFIG['DLEXT']}")
def load_extension(name)
  path = compile_extension(name)
  require path
  path
end
CAPI_SIZEOF_LONG = [0].pack('l!').size
require_relative '../../spec_helper'
''')

extensions = {}
for side, includes in (('reference', reference_headers), ('mere', [str(ROOT / 'capi' / 'include')])):
    directory = OUT / (side + '-ext')
    directory.mkdir()
    extensions[side] = directory

    def build(source, directory=directory, includes=includes):
        result = subprocess.run(['clang', '-O1', '-fPIC', '-w', *LINK, *[x for i in includes for x in ('-I', i)],
                                 '-I', str(CAPI / 'ext'), str(source), '-o', str(directory / (source.stem + DLEXT))],
                                capture_output=True, text=True)
        return source.stem, result.returncode == 0, (result.stderr.splitlines() or [''])[0][:160]
    with ThreadPoolExecutor(8) as pool:
        built = list(pool.map(build, sorted((CAPI / 'ext').glob('*_spec.c'))))
    print(f"{side}: {sum(1 for b in built if b[1])} of {len(built)} extensions built", flush=True)
    for name, ok, error in built:
        if not ok:
            print(f'    not built: {name}: {error}', flush=True)

files = sorted(CAPI.glob('*_spec.rb'))
if args.names:
    files = [f for f in files if any(n in f.name for n in args.names)]


def run(file):
    row = {}
    for side, binary in (('reference', REF), ('mere', MERE)):
        driver = tree / f'driver_{file.stem}_{side}.rb'
        driver.write_text(f'require_relative "spec_helper"\nrequire_relative "optional/capi/{file.stem}"\nmspec_report\n')
        env = {k: v for k, v in os.environ.items() if not k.startswith('MERE_RUBY_') and k not in ('RUBYOPT', 'RUBYLIB')}
        env.update(CAPI_SPEC_EXT=str(extensions[side]), LANG='en_US.UTF-8')
        if side == 'mere':
            env['RUBYLIB'] = stdlib
        log = OUT / f'{file.stem}.{side}.out'
        result = supervise([str(binary), str(driver)], env, log, 2 * 1024 * 1024, 120)
        text = log.read_text(errors='replace')
        report = re.search(r'pass=(\d+) fail=(\d+) err=(\d+)', text)
        if report and result['limit'] is None:
            row[side] = (int(report.group(1)), '')
        elif result['limit']:
            row[side] = (0, result['limit'])
        else:
            last = [l for l in text.splitlines() if l.strip() and not l.lstrip().startswith('from ')][-1:] or ['']
            row[side] = (0, 'no report: ' + re.sub(r'/\S*/', '', last[0])[:70])
    return file.stem, row


# (one file at a time, from the tree: what a spec writes beside itself stays there)
os.chdir(tree)
rows = [run(f) for f in files]
recorded = {}
if EXPECT.exists():
    for line in EXPECT.read_text().splitlines():
        if line and not line.startswith('#'):
            name, reference, mere = line.split('\t')[:3]
            recorded[name] = (int(reference), int(mere))
problems = []
total = {'reference': 0, 'mere': 0}
print(f"{'file':26s} {'reference':>9s} {'mere-ruby':>9s}")
for name, row in rows:
    reference, mere = row['reference'], row['mere']
    total['reference'] += reference[0]
    total['mere'] += mere[0]
    note = '; '.join(x for x in (reference[1] and 'reference: ' + reference[1], mere[1] and 'mere-ruby: ' + mere[1]) if x)
    print(f'{name:26s} {reference[0]:9d} {mere[0]:9d}  {note}', flush=True)
    if not args.write and name in recorded:
        if reference[0] != recorded[name][0]:
            problems.append(f'{name}: the reference passes {reference[0]}, the record says {recorded[name][0]}')
        if mere[0] < recorded[name][1]:
            problems.append(f'{name}: mere-ruby passes {mere[0]}, the record says {recorded[name][1]}')
    elif not args.write and not args.names:
        problems.append(f'{name}: no record')
print(f"{'TOTAL':26s} {total['reference']:9d} {total['mere']:9d}")
if args.write:
    if args.names:
        sys.exit('capi_spec_check: --write records every file; give no names')
    EXPECT.write_text('# ruby/spec optional/capi: examples passing, per spec file (tools/capi_spec_check.py --write)\n'
                      '# file\treference\tmere-ruby\n'
                      + ''.join(f"{name}\t{row['reference'][0]}\t{row['mere'][0]}\n" for name, row in rows))
    print(f'capi_spec_check: recorded {len(rows)} files in {EXPECT.relative_to(ROOT)}')
elif problems:
    sys.exit('capi_spec_check:\n  ' + '\n  '.join(problems))
else:
    print('capi_spec_check: the reference passes what is recorded, and mere-ruby no less than is recorded')
