#!/usr/bin/env python3
"""Bound provider lifetimes and interrupted allocation/generation in the real VM."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'unittest'))
from ci import supervise

PREPARE=r'''
require 'openssl'
File.binwrite(ARGV[0], OpenSSL::PKey::RSA.generate(2048).private_to_pem)
puts 'ephemeral test key prepared'
'''
LIFETIME=r'''
require 'openssl'
source=File.binread(ARGV[0])
baseline=OpenSSL::Backend.call('object.stats')[0]
def use_native_key(source)
  key=OpenSSL::PKey.read(source)
  copy=key.dup
  public_key=key.public_key
  sig=copy.sign('SHA256','binary' + "\0payload")
  raise 'signature changed' unless public_key.verify('SHA256',sig,'binary' + "\0payload")
  group=OpenSSL::PKey::EC::Group.new('prime256v1')
  point=group.generator.mul(7)
  raise 'point changed' unless point.on_curve?
  nil
end
ARGV[1].to_i.times { use_native_key(source) }
GC.start
live=OpenSSL::Backend.call('object.stats')[0]
owners=ObjectSpace.each_object(OpenSSL::NativeObject).count do |object|
  begin
    object.__native_id
    true
  rescue TypeError
    false
  end
end
raise 'native objects escaped their Ruby owners' unless live==owners
# The VM conservatively scans untyped integers on the C stack. A live String
# handle can retain an unrelated object with the same numeric ID. Compare the
# retained set at 20 and 200 iterations below, without disabling that GC scan.
puts "native live delta: #{live-baseline}"
puts 'native key and EC lifetimes preserved'
'''
INTERRUPT=r'''
require 'openssl'
source=File.binread(ARGV[0])
baseline=OpenSSL::Backend.call('object.stats')[0]
10.times do
  begin
    OpenSSL::PKey::RSA.new(1024) { raise 'callback stopped' }
    raise 'callback was not called'
  rescue RuntimeError => e
    raise unless e.message=='callback stopped'
  end
  value=OpenSSL::PKey::RSA.new(1024) { break :stopped }
  raise 'callback break value changed' unless value==:stopped
end
GC.start
raise 'cancelled generation retained resources' unless OpenSSL::Backend.call('object.stats')[0]==baseline

class << OpenSSL::Backend
  alias __memory_original_wrap wrap
  attr_accessor :pause_wrap, :gate_thread, :ready, :proceed
  def wrap(name,handle)
    if @pause_wrap && Thread.current==@gate_thread && name.start_with?('OpenSSL::PKey::')
      @ready << true
      @proceed.pop
    end
    __memory_original_wrap(name,handle)
  end
end
OpenSSL::Backend.ready=Queue.new
OpenSSL::Backend.proceed=Queue.new
OpenSSL::Backend.pause_wrap=true
thread=Thread.new do
  Thread.current.report_on_exception=false
  OpenSSL::Backend.gate_thread=Thread.current
  begin
    OpenSSL::PKey.read(source)
    raise 'asynchronous exception was not delivered'
  rescue RuntimeError => e
    raise unless e.message=='allocation stopped'
  end
end
OpenSSL::Backend.ready.pop
thread.raise(RuntimeError,'allocation stopped')
OpenSSL::Backend.proceed << true
thread.value
thread=nil
OpenSSL::Backend.pause_wrap=false
OpenSSL::Backend.gate_thread=nil
OpenSSL::Backend.ready=nil
OpenSSL::Backend.proceed=nil
GC.start
raise 'interrupted allocation retained an unowned resource' unless OpenSSL::Backend.call('object.stats')[0]==baseline
puts 'native allocation and generation interruption preserved ownership'
'''
WIRE=r'''
require 'openssl'
key=OpenSSL::PKey.read(File.binread(ARGV[0]))
payload=("a\0b" * (1024*1024))
signature=key.sign('SHA256',payload)
raise 'large signature did not verify' unless key.public_key.verify('SHA256',signature,payload)
puts 'large binary signature preserved'
'''


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=os.environ.get('MR_BIN',str(ROOT/'mere-ruby')))
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    output=args.output.resolve()
    output.mkdir(parents=True,exist_ok=False)
    reference=subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    results={}

    def run(name,source,binary,*argv,stats=False):
        script=output/(name+'.rb')
        script.write_text(source)
        env=os.environ.copy()
        if stats:env['MERE_REGION_STATS']='1'
        log=output/(name+'.log')
        result=supervise([str(Path(binary).resolve()),str(script),*map(str,argv)],env,log,2097152,120)
        results[name]=result
        (output/'results.json').write_text(json.dumps(results,indent=2)+'\n')
        assert result['exit']==0 and result['limit'] is None,(name,result,log.read_text()[-3000:])
        print(name,'passed',flush=True)
        return log.read_text()

    fixture=output/'ephemeral-key.pem'
    run('reference_prepare',PREPARE,reference,fixture)
    run('interruption',INTERRUPT,args.binary,fixture)
    run('large_wire',WIRE,args.binary,fixture)
    allocated=[]
    retained=[]
    for n in (20,200):
        log=run('lifetimes_'+str(n),LIFETIME,args.binary,fixture,n,stats=True)
        match=re.search(r'region-stats default:.*alloc_total=(\d+)',log)
        assert match,log[-2000:]
        allocated.append(int(match[1]))
        match=re.search(r'native live delta: (\d+)',log)
        assert match,log[-2000:]
        retained.append(int(match[1]))
    (output/'allocation.json').write_text(json.dumps(allocated)+'\n')
    assert allocated[1]-allocated[0]<8*1024*1024,allocated
    assert retained[1]<=200 and retained[1]-retained[0]<=128,retained
    (output/'retained.json').write_text(json.dumps(retained)+'\n')
    print('20/200 conservative GC survivors:',retained,flush=True)
    print('20/200 native lifetimes default arena allocations:',allocated,flush=True)


if __name__=='__main__':
    main()
