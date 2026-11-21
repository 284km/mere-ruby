"""Source and header identities shared by the normal and fault-only probes."""
import hashlib
import json
from pathlib import Path
import shutil

EXPORTS = '''let setup = fn () -> vm_setup ();
let eval_source = fn (source: str) -> vm_eval source;
let cleanup = fn () -> vm_cleanup ();
let clear_error = fn () -> vm_clear_error ();
let error_diagnostics = fn () -> vm_error_diagnostics ();
let error_class = fn () -> vm_error_class ();
let exception_status = fn () -> vm_exception_status ();
()
'''
FAULT_ENV = 'MERE_EMBEDDING_PROBE_FAILURE'


def failure_api(original, setup, cleanup, selectable=False):
    setup_call = 'let _ = driver_setup env "" "(embedded)" in 0'
    cleanup_call = 'sch_terminate_all world'
    if setup:
        if original.count(setup_call) != 1:
            raise ValueError('setup injection site changed')
        replacement = 'fail "injected setup failure"'
        if selectable:
            replacement = ('(if str_eq (env_get "' + FAULT_ENV + '") "setup" then '
                           + replacement + ' else (' + setup_call + '))')
        original = original.replace(setup_call, replacement)
    if cleanup:
        if original.count(cleanup_call) != 2:
            raise ValueError('cleanup injection sites changed')
        failure = 'fail "injected cleanup failure"'
        if selectable:
            failure = '(if str_eq (env_get "' + FAULT_ENV + '") "cleanup" then ' + failure + ' else ())'
        original = original.replace(cleanup_call, '(let _ = ' + cleanup_call + ' in ' + failure + ')')
    return original


def header_recipe(root, compiler):
    fixtures = root / 'tools/native_probe'
    inputs = sorted(set([*root.glob('*.mere'), *root.glob('ic/**/*.mere'),
                         *root.glob('.mere_modules/mgz/**/*.mere'),
                         *fixtures.glob('embedding*'), fixtures / 'native_build_flags.py']))
    return dict(schema=1, compiler_sha256=hashlib.sha256(compiler.read_bytes()).hexdigest(),
                exports_sha256=hashlib.sha256(EXPORTS.encode()).hexdigest(),
                sources={str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                         for p in inputs if p.is_file()})


def reuse_header(generated, output, recipe):
    provenance = json.loads((generated / 'build-provenance.json').read_text())
    if provenance.get('setup_failure_injected') or provenance.get('cleanup_failure_injected'):
        raise ValueError('header must come from the normal embedding build')
    if provenance.get('header_recipe') != recipe:
        raise ValueError('embedding header source/compiler identity changed')
    header = generated / 'embedding.h'
    if hashlib.sha256(header.read_bytes()).hexdigest() != provenance.get('header_sha256'):
        raise ValueError('embedding header checksum changed')
    shutil.copyfile(header, output / 'embedding.h')
