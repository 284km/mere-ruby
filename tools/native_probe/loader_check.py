#!/usr/bin/env python3
"""Compare native registration and require with CRuby, without routing adapters."""
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
SRC = opts.ruby_source.resolve()
REF = opts.reference.resolve()
HERE = opts.output.resolve()
HERE.mkdir(parents=True, exist_ok=True)
MERE = opts.mere.resolve() if opts.mere else WT/'mere-ruby'
inputs = [SRC/p for p in [
    'ext/-test-/typeddata/typeddata.c', 'ext/-test-/exception/ensured.c',
    'ext/-test-/exception/dataerror.c', 'ext/-test-/marshal/usr/usrmarshal.c',
    'test/-ext-/typeddata/test_typeddata.rb', 'test/-ext-/exception/test_ensured.rb',
    'test/-ext-/exception/test_exception_at_throwing.rb',
    'test/-ext-/exception/test_data_error.rb', 'test/-ext-/marshal/test_usrmarshal.rb']]
def hashes():
    return {str(p.relative_to(SRC)): hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
before = hashes()
sys.path.insert(0,str(WT/'unittest'))
from ci import supervise
headers=subprocess.check_output([str(REF),'-rrbconfig','-e','puts RbConfig::CONFIG.values_at("rubyhdrdir","rubyarchhdrdir")'],text=True).splitlines()
stdlib=subprocess.check_output([str(REF),'-e','print(([RbConfig::CONFIG["rubylibdir"]] + Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":"))'],text=True)
results={}
for side,binary in [('reference',REF),('mere',MERE)]:
    lib=HERE/(side+'-lib');lib.mkdir(exist_ok=True)
    includes=[x for h in headers for x in ['-I',h]] if side=='reference' else ['-DPROBE_TYPED_API','-I',str(WT/'tools/native_probe/include')]
    source_map={
        'loader_fixture':['tools/native_probe/loader_fixture.c'],
        'loader_retry':['tools/native_probe/loader_retry.c'],
        'loader_nested':['tools/native_probe/loader_nested.c'],
        '-test-/typeddata':[SRC/'ext/-test-/typeddata/typeddata.c'],
        '-test-/exception':[SRC/'ext/-test-/exception/ensured.c',SRC/'ext/-test-/exception/dataerror.c','tools/native_probe/exception_init.c'],
        '-test-/marshal/usr':[SRC/'ext/-test-/marshal/usr/usrmarshal.c'],
        }
    sanitizer=['-fsanitize=address,undefined','-fno-sanitize-recover=all'] if side=='mere' and opts.sanitize_extension else []
    for feature,srcs in source_map.items():
        out=lib/(feature+'.bundle');out.parent.mkdir(parents=True,exist_ok=True)
        subprocess.run(['clang','-bundle','-undefined','dynamic_lookup','-O2',*sanitizer,*includes,*[str(x if isinstance(x,Path) else WT/x) for x in srcs],'-o',str(out)],check=True)
    (lib/'alias').mkdir(exist_ok=True)
    alias=lib/'alias/loader_fixture.bundle'
    if not alias.exists():alias.symlink_to(lib/'loader_fixture.bundle')
    (lib/'loader_shadow.rb').write_text('$loader_shadow = :ruby\n')
    shadow=lib/'loader_shadow.bundle'
    if not shadow.exists():shadow.symlink_to(lib/'loader_fixture.bundle')
    missing=HERE/'missing.c';missing.write_text('#include <ruby.h>\nvoid Init_other(void) {}\n')
    subprocess.run(['clang','-bundle',*includes,str(missing),'-o',str(lib/'loader_missing_init.bundle')],check=True)
    wrong=HERE/'wrongabi.c';wrong.write_text('void Init_loader_wrongabi(void) {}\n')
    subprocess.run(['clang','-bundle',str(wrong),'-o',str(lib/'loader_wrongabi.bundle')],check=True)
    (lib/'relative_driver.rb').write_text("$relative_native = require_relative 'loader_fixture'\n")
    for name,file,extra in [
        ('contracts',WT/'tools/native_probe/loader.rb',{}),
        ('stress',WT/'tools/native_probe/loader.rb',{'MERE_RUBY_GC_STRESS':'1'}),
        ('typed',SRC/'test/-ext-/typeddata/test_typeddata.rb',{}),
        ('ensured',SRC/'test/-ext-/exception/test_ensured.rb',{}),
        ('throwing',SRC/'test/-ext-/exception/test_exception_at_throwing.rb',{}),
        ('dataerror',SRC/'test/-ext-/exception/test_data_error.rb',{}),
        ('marshal',SRC/'test/-ext-/marshal/test_usrmarshal.rb',{}),
    ]:
        key=name+'.'+side
        if opts.select and not any(x in key for x in opts.select):continue
        if side=='reference' and name=='stress':continue
        env=dict(os.environ)
        for knob in ['MERE_LOADER_TEST','MERE_RUBY_GC_STRESS','MERE_RUBY_GC_DBG','MERE_TYPED_SKIP_MARK','MERE_TYPED_SKIP_FREE','MERE_NATIVE_SKIP_ENSURE','MERE_NATIVE_PROBE_NO_ROOT']:
            env.pop(knob,None)
        if opts.sanitize_extension: env['ASAN_OPTIONS']='use_sigaltstack=0'
        libs=[str(lib),str(SRC/'tool/lib'),str(SRC/'test')]
        if side=='mere':libs+=[str(WT/'unittest/shim'),stdlib]
        env.update(RUBY=str(binary),UNITTEST_CHILD_RUBY=str(binary),UNITTEST_TEST_FILE=str(file.relative_to(SRC/'test')) if name not in ['contracts','stress'] else '',PATH=str(WT/'unittest/child-bin')+os.pathsep+env['PATH'],RUBYLIB=os.pathsep.join(libs),LOADER_LIB=str(lib))
        if side=='mere':env['MERE_LOADER_TEST']='1'
        # (a collection at every safepoint: the contracts need only their own library;
        #  with the standard library on the path a refused require goes on through
        #  RubyGems' search, which is minutes under that load)
        if name=='stress':env['RUBYLIB']=str(lib)
        env.update(extra)
        cmd=[str(binary)]
        if name not in ['contracts','stress']:cmd+=['-r','test/unit','-r',str(WT/'unittest/bootstrap.rb')]
        cmd+=[str(file)]
        if name not in ['contracts','stress']:cmd+=['-v','--seed=1']
        if name=='marshal':cmd+=['--name=test_marshal']
        log=HERE/(key+'.out');r=supervise(cmd,env,log,2*1024*1024,90);output=log.read_text()
        if name in ['contracts','stress']:
            expected=f"native loader contracts: {46 if side=='reference' else 50} passed"
        else:
            tests,assertions={'typed':(3,17),'ensured':(1,4),'throwing':(1,5),'dataerror':(1,3),'marshal':(1,2)}[name]
            expected=f'{tests} tests, {assertions} assertions, 0 failures, 0 errors, 0 skips'
        r['verified']=r['exit']==0 and r['limit'] is None and expected in output and 'ERROR: AddressSanitizer' not in output and 'runtime error:' not in output
        results[key]=r;(HERE/'results.json').write_text(json.dumps(results,indent=2)+'\n');print(key,json.dumps(r),flush=True)
        if not r['verified']:print(output[-2500:],flush=True)
assert hashes() == before, 'original Ruby inputs changed during validation'
(HERE/'input-hashes.json').write_text(json.dumps(before,indent=2)+'\n')
assert results and all(r['verified'] for r in results.values()),results
assert opts.select or len(results)==13,results
print('all native loader outcomes verified; original inputs unchanged',flush=True)
