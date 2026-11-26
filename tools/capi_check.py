#!/usr/bin/env python3
"""Check Ruby's C API against the reference ruby with shared C sources.

    capi_check.py --ruby-source <ruby> --reference <ruby binary> --output <dir> [--vm]

The same C -- Ruby's own ext/-test-/exception, typeddata, float and iter, and the
fixtures in capi/check -- is built twice: against the reference's headers and
against mere-ruby's (tools/capi_ext_build.py does both). The contract scripts
in capi/check then run on both sides and must print the same thing.

What each run is for:

  contracts            the six scripts on both sides, the same output
  stress               the same on mere-ruby with a collection at every
                       safepoint: what C holds must outlive each of them
  no-dmark             (negative) a data object's dmark is not called: the
                       value its C struct holds is collected, and the
                       TypedData contracts must FAIL
  no-dfree             (negative) dfree is not called: the count of freed
                       structs stays 0 and the TypedData contracts must FAIL
  no-ensure            (negative) rb_ensure skips its cleanup: the ensure
                       contracts must FAIL
  no-switch            (negative) a call into C in progress is not kept with
                       the stack it is on when fibers switch: the fiber
                       contracts must FAIL
  no-builtin           (negative) a primitive (rb_ary_push, rb_str_append,
                       rb_obj_freeze, ...) calls whatever the receiver's
                       class defines under that name: the api contracts
                       must FAIL
  no-fileprobe         (negative) a file is asked whether it is an extension
                       by loading it: its constructors run twice, and the
                       loader contracts must FAIL

--vm runs every mere-ruby side (the contracts, stress and the negative
controls) on the ISeq VM. It has to be asked for here: the runs are started
with no MERE_RUBY_* variable of the caller's, so `MERE_RUBY_VM=1 capi_check.py`
ran the evaluator and said nothing about the VM. Each run is given
MERE_RUBY_VM=report, and a contract script the VM did not take itself -- the
evaluator ran it -- fails the check, so a pass under --vm is the VM's.

A negative control that passes means the check was not looking at the thing
it names. Each run is bounded: 120 seconds, 2 GiB (its children included).
"""
from pathlib import Path
import argparse
import json
import os
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
parser.add_argument('--vm', action='store_true', help="run mere-ruby's side on the ISeq VM")
args = parser.parse_args()
SRC, REF, OUT, MERE = (p.resolve() for p in (args.ruby_source, args.reference, args.output, args.mere))
OUT.mkdir(parents=True, exist_ok=True)
if any(OUT.iterdir()):
    parser.error('--output must be empty, to exclude stale build products')
DLEXT, LINK = ('.bundle', ['-bundle', '-undefined', 'dynamic_lookup']) if sys.platform == 'darwin' else ('.so', ['-shared', '-fPIC'])
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise  # noqa: E402

reference_headers = subprocess.check_output(
    [str(REF), '-rrbconfig', '-e', 'puts RbConfig::CONFIG.values_at("rubyhdrdir", "rubyarchhdrdir")'],
    text=True).splitlines()
ext = SRC / 'ext' / '-test-'
extras = {
    'typed_probe': [ext / 'typeddata' / 'typeddata.c', ext / 'exception' / 'dataerror.c', CHECK / 'typed_fixture.c'],
    'loader_fixture': [CHECK / 'loader_fixture.c'],
    'loader_nested': [CHECK / 'loader_nested.c'],
    'loader_retry': [CHECK / 'loader_retry.c'],
    'api_fixture': [CHECK / 'api_fixture.c'],
}


def build(side):
    lib = OUT / (side + '-lib')
    command = [sys.executable, str(ROOT / 'tools' / 'capi_ext_build.py'), '--ruby-source', str(SRC),
               '--output', str(lib), '--only=-test-/exception', '--only=-test-/float', '--only=-test-/iter']
    if side == 'reference':
        for directory in reference_headers:
            command += ['--headers', directory]
    for feature, sources in extras.items():
        command += ['--extra', feature + '=' + ','.join(map(str, sources))]
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
    report = json.loads((lib / 'build.json').read_text())
    failed = [r for r in report if not r['built']]
    if failed or len(report) != 3 + len(extras):
        sys.exit(f'{side}: extensions not built: {failed or report}')
    # what the loader contracts ask for beside the extensions themselves
    (lib / 'alias').mkdir()
    (lib / 'alias' / ('loader_fixture' + DLEXT)).symlink_to(lib / ('loader_fixture' + DLEXT))
    (lib / 'loader_shadow.rb').write_text('$loader_shadow = :ruby\n')
    (lib / ('loader_shadow' + DLEXT)).symlink_to(lib / ('loader_fixture' + DLEXT))
    (lib / 'relative_driver.rb').write_text("$relative_native = require_relative 'loader_fixture'\n")
    scratch = OUT / (side + '-scratch')
    scratch.mkdir()
    includes = [x for d in (reference_headers if side == 'reference' else [ROOT / 'capi' / 'include'])
                for x in ('-I', str(d))]
    (scratch / 'missing.c').write_text('#include <ruby.h>\nvoid Init_other(void) {}\n')
    subprocess.run(['clang', *LINK, '-w', *includes, str(scratch / 'missing.c'),
                    '-o', str(lib / ('loader_missing_init' + DLEXT))], check=True)
    # (no ruby.h at all: nothing says which ruby it was built for)
    (scratch / 'foreign.c').write_text('void Init_loader_wrongabi(void) {}\n')
    subprocess.run(['clang', LINK[0], '-fPIC', str(scratch / 'foreign.c'),
                    '-o', str(lib / ('loader_wrongabi' + DLEXT))], check=True)
    return lib


results = {}


def run(name, side, script, lib, extra=None):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith('MERE_RUBY_') and k not in ('RUBYOPT', 'RUBYLIB', 'MERE_LOADER_TEST')}
    env.update(RUBYLIB=str(lib), LOADER_LIB=str(lib), LANG='en_US.UTF-8')
    events = OUT / f'{name}.{script}.{side}.events'
    events.unlink(missing_ok=True)
    env['LOADER_EVENTS'] = str(events)
    if side == 'mere':
        env['MERE_LOADER_TEST'] = '1'
        if args.vm:
            env['MERE_RUBY_VM'] = 'report'
    env.update(extra or {})
    log = OUT / f'{name}.{script}.{side}.out'
    result = supervise([str(REF if side == 'reference' else MERE), str(CHECK / (script + '.rb'))],
                       env, log, 2 * 1024 * 1024, 120)
    result['output'] = log.read_text(errors='replace')
    if side == 'mere' and args.vm:
        # (=report names each file the VM did not take; the script itself
        #  must not be one of them. "the native compiler declined" is not a
        #  refusal: the Ruby compiler then compiles it, for the VM.)
        refused = [l for l in result['output'].splitlines()
                   if l.startswith('mere-ruby: vm: ') and ('/' + script + '.rb: ') in l
                   and 'the native compiler declined' not in l]
        if refused:
            result['vm_refused'] = refused[0]
            print(f'  ({name}: the VM did not take {script}.rb, the evaluator ran it -- {refused[0]})', flush=True)
    results[f'{name}.{script}.{side}'] = {k: v for k, v in result.items() if k != 'output'}
    (OUT / 'results.json').write_text(json.dumps(results, indent=2) + '\n')
    return result


def passed(result):
    if 'vm_refused' in result:
        return None
    lines = [l for l in result['output'].splitlines() if l.endswith(' passed')]
    return lines[-1] if result['exit'] == 0 and result['limit'] is None and lines else None


libs = {side: build(side) for side in ('reference', 'mere')}
scripts = ['ensure', 'typeddata', 'loader', 'numeric', 'fiber', 'api']
problems = []
for script in scripts:
    answers = {side: passed(run('contracts', side, script, libs[side])) for side in ('reference', 'mere')}
    stress = passed(run('stress', 'mere', script, libs['mere'], {'MERE_RUBY_GC_STRESS': '1'}))
    print(f"{script:10s} reference: {answers['reference']} | mere-ruby{' (VM)' if args.vm else ''}: {answers['mere']} | under stress: {stress}", flush=True)
    if not answers['reference'] or not answers['mere'] or stress != answers['mere']:
        problems.append(f'{script}: a side did not finish its contracts')
        continue
    count = {side: int(answers[side].split()[-2]) for side in answers}
    # (the loader contracts have one check of mere-ruby's own: a library
    #  built for no ruby in particular is passed over)
    if count['mere'] - count['reference'] != (1 if script == 'loader' else 0):
        problems.append(f"{script}: {count['reference']} checks on the reference, {count['mere']} on mere-ruby")
for name, knob, script in [('no-dmark', 'dmark', 'typeddata'), ('no-dfree', 'dfree', 'typeddata'),
                           ('no-ensure', 'ensure', 'ensure'), ('no-switch', 'switch', 'fiber'),
                           ('no-fileprobe', 'fileprobe', 'loader'), ('no-builtin', 'builtin', 'api')]:
    result = run(name, 'mere', script, libs['mere'], {'MERE_RUBY_CAPI_WITHOUT': knob})
    failed_as_it_must = passed(result) is None and result['limit'] is None and 'vm_refused' not in result
    print(f"{name:10s} {script}: {'fails, as it must' if failed_as_it_must else 'PASSED -- the check does not see ' + knob}", flush=True)
    if not failed_as_it_must:
        problems.append(f'{name}: the {script} contracts pass without {knob}')
if problems:
    sys.exit('capi_check: ' + '; '.join(problems))
print('capi_check: the contracts agree on both sides' + (" (mere-ruby's on the ISeq VM)" if args.vm else '')
      + ', hold under collection stress, and each negative control fails')
