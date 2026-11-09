#!/usr/bin/env python3
"""Build and check the experimental singleton embedding API, with resource bounds."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import platform
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = Path(__file__).resolve().parent

# Compiler stdout is generated code; keep its diagnostics in a separate file.
# The parent supervise() call bounds this helper and the compiler together.
if len(sys.argv) > 1 and sys.argv[1] == '--emit':
    mode, compiler, directory = sys.argv[2:]
    output = Path(directory)
    with (output / ('embedding.h' if mode == 'header' else 'embedding.c')).open('w') as out:
        with (output / ('emit-' + mode + '.stderr')).open('w') as err:
            result = subprocess.run([compiler, '--lib-instance',
                                     '--header' if mode == 'header' else '-c',
                                     str(output / 'embedding.mere')],
                                    cwd=ROOT, stdout=out, stderr=err)
    sys.exit(result.returncode)

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--compiler', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--prism-lib', type=Path, default=ROOT / 'vendor/prism/obj/libprism.a')
parser.add_argument('--reference-prefix', type=Path)
parser.add_argument('--setup-failure', action='store_true',
                    help='Inject an initialization failure into a separate test fixture')
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
compiler, prism = args.compiler.resolve(), args.prism_lib.resolve()
assert compiler.is_file() and prism.is_file()
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise
os.chdir(ROOT)
results = {}
def run(name, command, seconds=90, rss_kb=2097152):
    command = list(map(str, command))
    log = output / (name + '.out')
    result = supervise(command, dict(os.environ), log, rss_kb, seconds)
    result['rss_limit_kb'] = rss_kb
    result['command'] = command
    results[name] = result
    (output / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, result['exit'], result['limit'], flush=True)
    assert result['exit'] == 0 and result['limit'] is None, (name, result, log.read_text()[-2000:])
    return log.read_text()

source = (ROOT / 'main.mere').read_text()
assert source.endswith('exit (run_cli ())\n')
source = source[:-len('exit (run_cli ())\n')] + '()\n'
source = re.sub(r'import "(m_[^"]+\.mere)";',
                lambda m: 'import "' + str(ROOT / m[1]) + '";', source)
source = re.sub(r'import "(mgz/[^"]+\.mere)";',
                lambda m: 'import "' + str(ROOT / '.mere_modules' / m[1]) + '";', source)
(output / 'embedding_core.mere').write_text(source)
api = FIXTURES / 'embedding_api.mere'
if args.setup_failure:
    # Exercise the real protected setup/cleanup path with partial state. Keep
    # the injected fixture separate from the archive distributed to consumers.
    original = api.read_text()
    call = 'let _ = driver_setup env "" "(embedded)" in 0'
    assert original.count(call) == 1
    api = output / 'embedding_api_failure.mere'
    api.write_text(original.replace(call, 'fail "injected setup failure"'))
(output / 'embedding.mere').write_text(
    'import "embedding_core.mere";\nimport "' + str(api) + '";\n'
    'let setup = fn () -> vm_setup ();\n'
    'let eval_source = fn (source: str) -> vm_eval source;\n'
    'let cleanup = fn () -> vm_cleanup ();\n'
    'let clear_error = fn () -> vm_clear_error ();\n'
    'let error_diagnostics = fn () -> vm_error_diagnostics ();\n'
    'let error_class = fn () -> vm_error_class ();\n'
    'let exception_status = fn () -> vm_exception_status ();\n()\n')
for mode in ['header', 'c']:
    run('emit-' + mode, [sys.executable, __file__, '--emit', mode, compiler, output])
flags = ['clang', '-O2', '-w', '-fbracket-depth=1024', '-I', ROOT / 'vendor/prism/include']
link_flags = ['-Wl,-stack_size,0x20000000'] if platform.system() == 'Darwin' else ['-lm']
if platform.system() != 'Darwin':
    import resource
    soft, hard = resource.getrlimit(resource.RLIMIT_STACK)
    bound = 512 * 1024 * 1024
    resource.setrlimit(resource.RLIMIT_STACK, (bound if hard < 0 else min(bound, hard), hard))
# The generated interpreter is a large translation unit. Apple Clang's O2
# compilation can exceed 2 GiB even before lifecycle changes. Bound the build
# separately; every interpreter execution retains the 2-GiB runtime limit.
run('compile', flags + ['-c', output / 'embedding.c', '-o', output / 'embedding.o'],
    300, rss_kb=3145728)
archive = output / 'libmere_embedding_probe.a'
run('archive', ['ar', 'rcs', archive, output / 'embedding.o'])
run('link', flags + ['-I', output, FIXTURES / 'embedding_host.c', archive,
    ROOT / 'tools/prism_glue.c', ROOT / 'tools/socket_glue.c', ROOT / 'tools/process_glue.c', prism, '-pthread', *link_flags, '-o', output / 'host'])
expected = {
    'lifecycle': 'between_evals\nstate_preserved\nbefore_cleanup\nend_hook\nnested_hook\ncleanup_hook\nhost_survived\n',
    'cleanup-error': 'before_cleanup\nfirst_hook\nlast_hook\nhost_survived\n',
    'cleanup-exit': 'cleanup_hook\nhost_survived\n',
}
for mode, text in ({} if args.setup_failure else expected).items():
    assert run(mode, [output / 'host', mode]) == text
for mode in (['setup-failure'] if args.setup_failure else ['pending-runtime', 'pending-exit', 'handled-runtime',
             'pending-runtime-hook-exit', 'pending-exit-hook-error',
             'pending-exit-hook-exit', 'hooks-exit-then-error',
             'hooks-error-then-exit', 'pending-runtime-normal-hook',
             'runtime-status-ivar', 'exit-subclass', 'persistent-locals',
             'bad-inspect-pending', 'bad-inspect-clear', 'bad-inspect-hook',
             'primitive-pending', 'locals-after-error', 'local-call-before-assignment', 'method-gc']):
    text = run(mode, [output / 'host', mode])
    if mode == 'bad-inspect-hook':
        assert text == 'after_bad_inspect\nprotected_reporting_passed\n'
if args.reference_prefix and not args.setup_failure:
    ruby = args.reference_prefix.resolve() / 'bin/ruby'
    config = json.loads(subprocess.check_output([str(ruby), '-rjson', '-rrbconfig', '-e',
        'puts JSON.generate(RbConfig::CONFIG.slice("rubyhdrdir", "rubyarchhdrdir", "libdir", "LIBRUBYARG_SHARED"))'], text=True))
    import shlex
    run('reference-compile', ['clang', '-O2', '-I' + config['rubyhdrdir'], '-I' + config['rubyarchhdrdir'],
        FIXTURES / 'embedding_reference.c', '-L' + config['libdir'],
        *shlex.split(config['LIBRUBYARG_SHARED']), '-o', output / 'reference'])
    assert run('reference', [output / 'reference']) == expected['lifecycle']
paths = [compiler, prism, *ROOT.glob('*.mere'), *FIXTURES.glob('embedding*'),
         api, output / 'embedding.c', output / 'embedding.h', archive, output / 'host']
(output / 'sha256.json').write_text(json.dumps({str(p): hashlib.sha256(p.read_bytes()).hexdigest()
    for p in paths if p.is_file()}, indent=2) + '\n')
def revision(directory):
    result = subprocess.run(['git', '-C', str(directory), 'rev-parse', 'HEAD'],
                            capture_output=True, text=True)
    return result.stdout.strip() if result.returncode == 0 else None
(output / 'build-provenance.json').write_text(json.dumps({
    'schema': 1,
    'setup_failure_injected': args.setup_failure,
    'source_revision': revision(ROOT),
    'compiler_revision': revision(compiler.parent),
    'compiler_sha256': hashlib.sha256(compiler.read_bytes()).hexdigest(),
    'prism_sha256': hashlib.sha256(prism.read_bytes()).hexdigest(),
    'target': platform.platform(),
    'sources': {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in [*ROOT.glob('*.mere'), *FIXTURES.glob('embedding*')]
                if p.is_file()},
}, indent=2) + '\n')
print('Protected embedding lifecycle checks passed', flush=True)
