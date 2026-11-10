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
key=OpenSSL::PKey::RSA.generate(2048)
File.binwrite(ARGV[0], key.private_to_pem)
cert=OpenSSL::X509::Certificate.new
cert.version=2
cert.serial=1
cert.subject=cert.issuer=OpenSSL::X509::Name.parse('/CN=localhost')
cert.public_key=key
cert.not_before=Time.now-60
cert.not_after=Time.now+3600
factory=OpenSSL::X509::ExtensionFactory.new(cert,cert)
cert.add_extension(factory.create_extension('basicConstraints','CA:TRUE',true))
cert.add_extension(factory.create_extension('keyUsage','keyCertSign,digitalSignature,keyEncipherment',true))
cert.add_extension(factory.create_extension('subjectAltName','DNS:localhost'))
cert.sign(key,'SHA256')
File.binwrite(ARGV[0]+'.crt',cert.to_pem)
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
    OpenSSL.__native_handle(object)
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
THREAD_LIFETIME=r'''
require 'openssl'
source=File.binread(ARGV[0])
baseline=OpenSSL::Backend.call('object.stats')[0]
def use_worker_key(source)
  key=OpenSSL::PKey.read(source)
  worker=Thread.new { key.private?; nil }
  worker.value
  nil
end
ARGV[1].to_i.times { use_worker_key(source) }
GC.start
puts "thread native live delta: #{OpenSSL::Backend.call('object.stats')[0]-baseline}"
'''
THREAD_RESULT=r'''
require 'openssl'
source=File.binread(ARGV[0])
kept=Thread.new { OpenSSL::PKey.read(source) }
kept.join
GC.start
raise 'a held Thread lost its result' unless kept.value.private?
baseline=OpenSSL::Backend.call('object.stats')[0]
def worker_result(source)
  worker=Thread.new { OpenSSL::PKey.read(source) }
  raise 'worker result changed' unless worker.value.private?
  nil
end
ARGV[1].to_i.times { worker_result(source) }
GC.start
raise 'a held Thread lost its result after other workers' unless kept.value.private?
puts "result native live delta: #{OpenSSL::Backend.call('object.stats')[0]-baseline}"
'''
TLS_LIFETIME=r'''
require 'openssl'
require 'socket'
key=OpenSSL::PKey.read(File.binread(ARGV[0]))
cert=OpenSSL::X509::Certificate.new(File.binread(ARGV[0]+'.crt'))
store=OpenSSL::X509::Store.new
store.add_cert(cert)
fd_dir=File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'
fds=Dir.children(fd_dir).size
def exchange(key,cert,store,mode)
  server_ctx=OpenSSL::SSL::SSLContext.new
  server_ctx.cert=cert
  server_ctx.key=key
  server_ctx.cert_store=store
  server_ctx.verify_mode=OpenSSL::SSL::VERIFY_PEER | OpenSSL::SSL::VERIFY_FAIL_IF_NO_PEER_CERT
  server_ctx.servername_cb=proc { raise 'SNI stopped' } if mode==:sni_error
  client_ctx=OpenSSL::SSL::SSLContext.new
  client_ctx.cert=cert
  client_ctx.key=key
  client_ctx.cert_store=store
  client_ctx.verify_mode=OpenSSL::SSL::VERIFY_PEER
  client_ctx.verify_hostname=true
  borrowed=nil
  client_ctx.verify_callback=proc do |ok,context|
    borrowed=context
    GC.start
    ok
  end
  left,right=Socket.pair(:UNIX,:STREAM,0)
  server=OpenSSL::SSL::SSLSocket.new(left,server_ctx)
  client=OpenSSL::SSL::SSLSocket.new(right,client_ctx)
  server.sync_close=client.sync_close=true
  client.hostname=mode==:wrong_host ? 'wrong.example' : 'localhost'
  worker=Thread.new do
    Thread.current.report_on_exception=false
    begin
      server.accept
      raise 'mTLS peer missing' unless server.peer_cert
      server.syswrite(server.sysread(7))
      :ok
    rescue OpenSSL::SSL::SSLError, RuntimeError => error
      raise unless mode!=:ok
      error
    ensure
      server.close
    end
  end
  begin
    client.connect
    raise 'invalid handshake accepted' unless mode==:ok
    client.syswrite("TLS\0bin")
    raise 'TLS data changed' unless client.sysread(7)=="TLS\0bin"
  rescue OpenSSL::SSL::SSLError
    raise if mode==:ok
  ensure
    client.close
    worker.value
  end
  if borrowed
    begin
      borrowed.error
      raise 'borrowed callback context escaped its lifetime'
    rescue TypeError
    end
  end
  nil
end
10.times { exchange(key,cert,store,:ok) }
exchange(key,cert,store,:wrong_host)
exchange(key,cert,store,:sni_error)
# Interrupt a client blocked waiting for a peer's handshake. Its C worker
# must be joined before the Ruby exception leaves the operation.
left,right=Socket.pair(:UNIX,:STREAM,0)
client=OpenSSL::SSL::SSLSocket.new(left)
ready=Queue.new
worker=Thread.new do
  Thread.current.report_on_exception=false
  ready << true
  begin
    client.connect
    raise 'interruption was not delivered'
  rescue RuntimeError => error
    raise unless error.message=='handshake stopped'
  end
end
ready.pop
sleep 0.02
worker.raise(RuntimeError,'handshake stopped')
worker.value
client.close
left.close
right.close
GC.start
raise 'TLS leaked transport descriptors' unless Dir.children(fd_dir).size==fds
GC.stress=false
GC.disable
live=OpenSSL::Backend.call('object.stats')[0]
owners=ObjectSpace.each_object(OpenSSL::NativeObject).count do |object|
  begin
    OpenSSL.__native_handle(object)
    true
  rescue TypeError
    false
  end
end
raise 'TLS resource escaped Ruby ownership' unless live==owners
puts 'TLS mutual authentication, negative hostname, callback GC/error, interruption and descriptor lifetimes passed'
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

    def run(name,source,binary,*argv,stats=False,stress=False):
        script=output/(name+'.rb')
        script.write_text(source)
        env=os.environ.copy()
        if stats:env['MERE_REGION_STATS']='1'
        if stress:env['MERE_RUBY_GC_STRESS']='257'
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
    run('tls_lifetimes',TLS_LIFETIME,args.binary,fixture)
    run('tls_gc_stress',TLS_LIFETIME,args.binary,fixture,stress=True)
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
    thread_retained=[]
    for n in (20,200):
        log=run('thread_lifetimes_'+str(n),THREAD_LIFETIME,args.binary,fixture,n)
        match=re.search(r'thread native live delta: (\d+)',log)
        assert match,log[-2000:]
        thread_retained.append(int(match[1]))
    # The pre-fix completed-thread registry retained all 180 additional keys.
    # Conservative stack aliases vary across clang/platforms (macOS 64 extra,
    # Linux 89); keep the bound below that known linear-registry regression.
    assert thread_retained[1]<=160 and thread_retained[1]-thread_retained[0]<=128,thread_retained
    (output/'thread_retained.json').write_text(json.dumps(thread_retained)+'\n')
    print('20/200 completed-thread conservative GC survivors:',thread_retained,flush=True)
    returned=[]
    for n in (20,200):
        log=run('thread_results_'+str(n),THREAD_RESULT,args.binary,fixture,n)
        returned.append(int(re.search(r'result native live delta: (\d+)',log)[1]))
    assert returned[1]-returned[0]<=128,returned
    (output/'thread_results.json').write_text(json.dumps(returned)+'\n')
    print('20/200 completed-thread result conservative GC survivors:',returned,flush=True)


if __name__=='__main__':
    main()
