#!/usr/bin/env python3
"""Build unchanged Ruby TypedData inputs and compare both runtimes on macOS."""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ruby-source', type=Path, required=True)
parser.add_argument('--reference', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--mere', type=Path)
parser.add_argument('--sanitize-extension', action='store_true')
parser.add_argument('--select', action='append', default=[], help='Run names containing this text')
opts = parser.parse_args()
if sys.platform != 'darwin':
    parser.error('this investigation builds macOS bundles only')
WT = Path(__file__).resolve().parents[2]
HERE = opts.output.resolve()
HERE.mkdir(parents=True, exist_ok=True)
SRC = opts.ruby_source.resolve()
REF = opts.reference.resolve()
MERE = opts.mere.resolve() if opts.mere else WT/'mere-ruby'
inputs = [SRC/p for p in ['ext/-test-/typeddata/typeddata.c',
                         'ext/-test-/exception/dataerror.c',
                         'test/-ext-/typeddata/test_typeddata.rb',
                         'test/-ext-/exception/test_data_error.rb']]
def hashes():
    return {str(p.relative_to(SRC)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
before = hashes()
sys.path.insert(0,str(WT/'unittest'))
from ci import supervise
ref_lib=HERE/'reference-lib/-test-'
ref_lib.mkdir(parents=True,exist_ok=True)
headers=subprocess.check_output([str(REF),'-rrbconfig','-e','puts RbConfig::CONFIG.values_at("rubyhdrdir", "rubyarchhdrdir")'],text=True).splitlines()
subprocess.run(['clang','-bundle','-undefined','dynamic_lookup','-O2',*[x for h in headers for x in ['-I',h]],str(SRC/'ext/-test-/typeddata/typeddata.c'),str(SRC/'ext/-test-/exception/dataerror.c'),str(WT/'tools/native_probe/typed_fixture.c'),'-o',str(ref_lib/'typed_probe.bundle')],check=True)
(ref_lib/'typeddata.rb').write_text("require '-test-/typed_probe'\n")
(ref_lib/'exception.rb').write_text("require '-test-/typed_probe'\n")
subprocess.run(['clang','-bundle','-undefined','dynamic_lookup','-O2',*(['-fsanitize=address,undefined','-fno-sanitize-recover=all'] if opts.sanitize_extension else []),'-DPROBE_TYPED_API','-I',str(WT/'tools/native_probe/include'),str(SRC/'ext/-test-/typeddata/typeddata.c'),str(SRC/'ext/-test-/exception/dataerror.c'),str(WT/'tools/native_probe/typed_fixture.c'),'-o',str(HERE/'typed_probe.bundle')],check=True)
stdlib=subprocess.check_output([str(REF),'-e','print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir, "gems", "*", "lib")].sort).join(":"))'],text=True)
results={}
for side,binary,lib in [('reference',REF,HERE/'reference-lib'),('mere',MERE,WT/'tools/native_probe/lib')]:
    for name,file,extra,selection in [
        ('contracts',WT/'tools/native_probe/typeddata.rb',{},None),
        ('stress',WT/'tools/native_probe/typeddata.rb',{'MERE_RUBY_GC_STRESS':'1'},None),
        ('no-mark',WT/'tools/native_probe/typeddata.rb',{'MERE_TYPED_SKIP_MARK':'1'},None),
        ('no-free',WT/'tools/native_probe/typeddata.rb',{'MERE_TYPED_SKIP_FREE':'1'},None),
        ('original-full',SRC/'test/-ext-/typeddata/test_typeddata.rb',{},None),
        ('original-dataerror',SRC/'test/-ext-/exception/test_data_error.rb',{},None),
    ]:
        key=name+'.'+side
        if opts.select and not any(x in key for x in opts.select): continue
        if side=='reference' and name in ['stress','no-mark','no-free']:continue
        env=dict(os.environ)
        for knob in ['MERE_NATIVE_TYPED_MODULE', 'MERE_TYPED_SKIP_MARK', 'MERE_TYPED_SKIP_FREE',
               'MERE_RUBY_GC_STRESS', 'MERE_RUBY_GC_DBG', 'MERE_NATIVE_PROBE_NO_ROOT']:
            env.pop(knob, None)
        libs=[str(lib),str(SRC/'tool/lib'),str(SRC/'test')]
        if side=='mere':libs += [str(WT/'unittest/shim'),stdlib]
        env.update(RUBY=str(binary),UNITTEST_CHILD_RUBY=str(binary),UNITTEST_TEST_FILE=str(file.relative_to(SRC/'test')) if name.startswith('original') else '',PATH=str(WT/'unittest/child-bin')+os.pathsep+env['PATH'],RUBYLIB=os.pathsep.join(libs),MERE_NATIVE_TYPED_MODULE=str(HERE/'typed_probe.bundle'))
        env.update(extra)
        if opts.sanitize_extension:
            # Mere manages coroutine alternate stacks; ASan's own alt-stack
            # teardown conflicts with them. Heap checks stay enabled.
            env['ASAN_OPTIONS'] = 'use_sigaltstack=0'
        cmd=[str(binary)]
        if name.startswith('original'):cmd+=['-r','test/unit','-r',str(WT/'unittest/bootstrap.rb')]
        cmd+=[str(file)]
        if name.startswith('original'):cmd+=['-v','--seed=1']
        if selection:cmd+=['--name='+selection]
        log=HERE/(key+'.out')
        result=supervise(cmd,env,log,2*1024*1024,90)
        out=log.read_text()
        if name=='no-mark':ok=result['exit']!=0 and ('native-only payload survives mark' in out or 'original dmark preserves native payload' in out or 'invalid or expired typed VALUE' in out)
        elif name=='no-free':ok=result['exit']!=0 and 'unreachable C cycles are reclaimed' in out
        elif name == 'original-full':
            ok=result['exit']==0 and '3 tests, 17 assertions, 0 failures, 0 errors, 0 skips' in out
        elif name == 'original-dataerror':
            ok=result['exit']==0 and '1 tests, 3 assertions, 0 failures, 0 errors, 0 skips' in out
        else:
            count=78 if side=='reference' else 82
            ok=result['exit']==0 and f'typeddata contracts: {count} passed' in out
        ok = ok and 'ERROR: AddressSanitizer' not in out and 'runtime error:' not in out
        result['verified']=ok and result['limit'] is None
        results[key]=result
        (HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        print(key,json.dumps(result),flush=True)
        if not result['verified']:print(out[-2500:],flush=True)
assert hashes() == before, 'original Ruby inputs changed during validation'
(HERE/'input-hashes.json').write_text(json.dumps(before, indent=2)+'\n')
assert results and all(r['verified'] for r in results.values()), results
assert opts.select or len(results)==9, results
print('all TypedData outcomes verified; original inputs unchanged', flush=True)
