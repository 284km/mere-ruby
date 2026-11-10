#!/usr/bin/env python3
"""Package and check an experimental embedding archive containing all native glue.

Run embedding_check.py first. This consumes its generated object and header,
plus a Prism archive built for the same target. Consumers link the resulting
archive and system libraries; no product C source is needed on their link line.
The exported API is mere_embedding_*, not the Ruby C API.
"""
from pathlib import Path
from native_build_flags import openssl_flags
import argparse
import hashlib
import json
import os
import platform
import shutil
import sys

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--library-dir', type=Path, required=True)
parser.add_argument('--prism-lib', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
generated, prism, output = args.library_dir.resolve(), args.prism_lib.resolve(), args.output.resolve()
provenance_path = generated / 'build-provenance.json'
provenance = json.loads(provenance_path.read_text()) if provenance_path.is_file() else None
if provenance and provenance.get('setup_failure_injected'):
    parser.error('the setup-failure fixture cannot be packaged as an embedding library')
if provenance and provenance.get('cleanup_failure_injected'):
    parser.error('the cleanup-failure fixture cannot be packaged as an embedding library')
for path in [generated / 'embedding.o', generated / 'embedding.h', prism]:
    if not path.is_file():
        parser.error(f'missing input: {path}')
output.mkdir(parents=True, exist_ok=False)
objects, includes, libraries = [output / name for name in ['objects', 'include', 'lib']]
for path in [objects, includes, libraries]:
    path.mkdir()
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

results = {}
def run(name, command, env=None):
    command = list(map(str, command))
    log = output / (name + '.out')
    result = supervise(command, dict(os.environ) if env is None else env, log, 2097152, 90)
    result['command'] = command
    results[name] = result
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    assert result['exit'] == 0 and result['limit'] is None, (name, result, log.read_text()[-2000:])
    print(name, 'passed', flush=True)

# Resolve a relative OPENSSL_PREFIX before archive extraction changes cwd.
openssl_cflags, openssl_ldflags = openssl_flags()
os.chdir(objects)
run('extract-prism', ['ar', 'x', prism])
prism_objects = sorted(objects.glob('*.o'))
assert prism_objects, 'Prism archive contained no object files'
glue = [ROOT / 'tools' / (name + '.c') for name in ['prism_glue', 'socket_glue', 'process_glue', 'openssl_glue']]
for source in glue:
    target = objects / (source.stem + '.o')
    assert not target.exists(), f'archive member collision: {target.name}'
    run('compile-' + source.stem, ['clang', '-O2', '-w', '-I', ROOT / 'vendor/prism/include', *openssl_cflags,
                                  '-c', source, '-o', target])
assert not (objects / 'embedding.o').exists(), 'archive member collision: embedding.o'
shutil.copyfile(generated / 'embedding.o', objects / 'embedding.o')
shutil.copyfile(generated / 'embedding.h', includes / 'embedding.h')
archive = libraries / 'libmere-ruby-embedding.a'
run('archive', ['ar', 'rcs', archive, *sorted(objects.glob('*.o'))])
link = ['-pthread', '-lm'] + openssl_ldflags
if platform.system() == 'Darwin':
    link += ['-Wl,-stack_size,0x20000000']
else:
    import resource
    _, hard = resource.getrlimit(resource.RLIMIT_STACK)
    bound = 512 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_STACK, (bound if hard < 0 else min(bound, hard), hard))
    link += ['-ldl']
run('consumer-link', ['clang', '-O2', '-w', '-I', includes, '-I', FIXTURES,
                      FIXTURES / 'embedding_integration.c', archive, *link, '-o', output / 'consumer'])
for mode in ['normal', 'cleanup-error']:
    run('consumer-' + mode, [output / 'consumer', mode],
        dict(os.environ, EMBED_PATH=str(output / (mode + '.txt'))))
inputs = [generated / 'embedding.o', generated / 'embedding.h', prism, *glue,
          FIXTURES / 'embedding_integration.c', FIXTURES / 'embedding_host.c',
          Path(__file__).with_name('native_build_flags.py')]
(output / 'manifest.json').write_text(json.dumps({
    'schema': 1,
    'build_provenance': provenance,
    'archive': str(archive),
    'platform': platform.platform(),
    'system_link_flags': link,
    'members': [p.name for p in sorted(objects.glob('*.o'))],
    'sha256': {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in [*inputs, archive]},
    'api': 'generated mere_embedding_* API; no ruby_init/ruby_cleanup facade',
}, indent=2) + '\n')
# Preserve templates separately from expanded consumer paths. Build tools may
# substitute exec_prefix; an absolute MAKEFILE_CONFIG libdir breaks that use.
(output / 'build-config.json').write_text(json.dumps({
    'schema': 1,
    'templates': {'prefix': str(output), 'exec_prefix': '$(prefix)',
                  'libdir': '$(exec_prefix)/lib', 'includedir': '$(prefix)/include',
                  'RUBY_SO_NAME': 'mere-ruby',
                  'LIBRUBY_A': 'lib$(RUBY_SO_NAME)-embedding.a',
                  'LIBRUBYARG_STATIC': '$(libdir)/$(LIBRUBY_A)'},
    'expanded': {'prefix': str(output), 'exec_prefix': str(output),
                 'libdir': str(libraries), 'includedir': str(includes),
                 'LIBRUBY_A': archive.name, 'LIBRUBYARG_STATIC': str(archive)},
    'system_link_flags': link,
    'api': 'mere_embedding_*; not the CRuby VALUE ABI',
}, indent=2) + '\n')
print('Self-contained embedding archive and consumer checks passed', flush=True)
