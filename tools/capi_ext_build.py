#!/usr/bin/env python3
"""Build CRuby's test extensions (ext/-test-/*) against mere-ruby's ruby.h.

    capi_ext_build.py --ruby-source <ruby> --output <dir>

Each directory with an extconf.rb becomes one extension, named as its
extconf.rb names it (create_makefile's argument, or auto_ext's "-test-/<dir>")
and written under <dir> so that `require "-test-/float"` finds it with <dir>
on the load path. The C sources are compiled unchanged.

This reads extconf.rb instead of running it: mkmf needs an RbConfig this
interpreter does not have yet. What it takes from each file is the feature
name, auto_ext's TEST_INIT_FUNCS, and nothing else -- an extension whose
extconf.rb decides more than that (have_func, C++ probes) is built from the
same sources without those answers, and says so in the report.

An extension that does not compile is not an error of this tool: the report
(<dir>/build.json) names it and the compiler's first complaint. The exit
status is 0 unless nothing at all was built.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import argparse
import json
import os
import platform
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--cc', default=os.environ.get('CC', 'clang'))
parser.add_argument('--cxx', default=os.environ.get('CXX', 'clang++'))
parser.add_argument('--only', action='append', default=[], help='a feature name to build (repeatable)')
args = parser.parse_args()
SRC = args.ruby_source.resolve()
EXT = SRC / 'ext' / '-test-'
OUT = args.output.resolve()
darwin = platform.system() == 'Darwin'
DLEXT = '.bundle' if darwin else '.so'
LINK = ['-bundle', '-undefined', 'dynamic_lookup'] if darwin else ['-shared']
CFLAGS = ['-O2', '-fPIC', '-w', '-I', str(ROOT / 'capi' / 'include')]


def plan(extconf):
    directory = extconf.parent
    relative = directory.relative_to(EXT)
    text = extconf.read_text()
    named = re.search(r'''create_makefile\(\s*["']([^"']+)["']''', text)
    auto = 'auto_ext' in text or 'TEST_INIT_FUNCS' in text
    feature = named.group(1) if named else '-test-/' + str(relative)
    sources = sorted(p for p in directory.iterdir() if p.suffix in ('.c', '.cc', '.cpp', '.cxx'))
    notes = []
    if re.search(r'have_(func|header|type|library|macro)|try_(link|compile)|have_devel', text):
        notes.append('extconf.rb probes the platform; built without its answers')
    defines = []
    if auto:
        inits = ' '.join(f'X({p.stem})' for p in sources if p.stem != 'init')
        defines.append(f'-DTEST_INIT_FUNCS(X)={inits}')
    # (auto_ext(inc: true) and the two that spell it out add the source tree,
    #  for CRuby's internal headers; the rest see the public ones alone)
    includes = ['-I', str(directory)]
    if 'inc: true' in text or 'top_srcdir' in text:
        includes += ['-I', str(SRC)]
    return {'feature': feature, 'directory': str(relative), 'sources': sources,
            'defines': defines, 'includes': includes, 'notes': notes}


def build(item):
    target = OUT / (item['feature'] + DLEXT)
    target.parent.mkdir(parents=True, exist_ok=True)
    objects, log = [], []
    work = OUT / '.objects' / item['directory']
    work.mkdir(parents=True, exist_ok=True)
    for source in item['sources']:
        cxx = source.suffix != '.c'
        obj = work / (source.name + '.o')
        command = [args.cxx if cxx else args.cc, *CFLAGS, *item['includes'], *item['defines'],
                   '-c', str(source), '-o', str(obj)]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            first = next((l for l in result.stderr.splitlines() if 'error' in l), result.stderr[:200])
            return {'feature': item['feature'], 'built': False, 'source': source.name,
                    'error': first.replace(str(SRC) + '/', ''), 'notes': item['notes']}
        objects.append(str(obj))
    if not objects:
        return {'feature': item['feature'], 'built': False, 'error': 'no C sources', 'notes': item['notes']}
    cxx = any(s.suffix != '.c' for s in item['sources'])
    result = subprocess.run([args.cxx if cxx else args.cc, *LINK, *objects, '-o', str(target)],
                            capture_output=True, text=True)
    if result.returncode != 0:
        return {'feature': item['feature'], 'built': False, 'error': result.stderr.strip().splitlines()[-1][:300],
                'notes': item['notes']}
    return {'feature': item['feature'], 'built': True, 'notes': item['notes']}


items = [plan(p) for p in sorted(EXT.rglob('extconf.rb')) if 'win32' not in p.parts]
if args.only:
    items = [i for i in items if i['feature'] in args.only]
OUT.mkdir(parents=True, exist_ok=True)
with ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as pool:
    results = list(pool.map(build, items))
(OUT / 'build.json').write_text(json.dumps(results, indent=2) + '\n')
built = [r for r in results if r['built']]
for r in results:
    if not r['built']:
        print(f"not built  {r['feature']}: {r.get('source', '')} {r['error']}")
print(f'{len(built)} of {len(results)} extensions built into {OUT}')
sys.exit(0 if built else 1)
