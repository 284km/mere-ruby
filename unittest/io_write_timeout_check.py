#!/usr/bin/env python3
"""Bound write deadlines against independent stalled TCP/TLS peers and inherited pipes."""
import argparse
import fcntl
import json
import os
import re
from pathlib import Path
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'gemtest'))
from https_measure import PREPARE
from ci import supervise

PROGRAM = r'''
require 'socket'
require 'openssl'
require 'net/http'
kind=ARGV.fetch(0)
port=ARGV.fetch(1).to_i
certificate=ARGV.fetch(2)
tcp=nil
ssl=nil
begin
  if kind=='http' || kind=='https'
    http=Net::HTTP.new('localhost',port,nil)
    http.ipaddr='127.0.0.1'
    http.open_timeout=1
    http.read_timeout=1
    http.write_timeout=0.02
    if kind=='https'
      http.use_ssl=true
      http.ca_file=certificate
      http.verify_mode=OpenSSL::SSL::VERIFY_PEER
    end
    request=Net::HTTP::Post.new('/')
    request.body='w'*8_000_000
    begin
      http.request(request)
      raise 'stalled HTTP upload ignored its write timeout'
    rescue Net::WriteTimeout => error
      puts [kind,error.class.name].join(':')
    end
  else
    tcp=TCPSocket.new('127.0.0.1',port)
    tcp.setsockopt(Socket::SOL_SOCKET,Socket::SO_SNDBUF,4096)
    tcp.timeout=1
    stream=tcp
    if kind.start_with?('tls')
      context=OpenSSL::SSL::SSLContext.new
      context.ca_file=certificate
      context.verify_mode=OpenSSL::SSL::VERIFY_PEER
      context.verify_hostname=true
      ssl=OpenSSL::SSL::SSLSocket.new(tcp,context)
      ssl.hostname='localhost'
      ssl.connect
      stream=ssl
    end
    if kind=='tls-false'
      tcp.timeout=false
    elsif kind=='tls-custom'
      interval=Object.new
      def interval.divmod(unit) = [0,Rational(1,50)]
      tcp.timeout=interval
    else
      tcp.timeout=0.02
    end
    write_started=Process.clock_gettime(Process::CLOCK_MONOTONIC)
    begin
      stream.write('w'*8_000_000)
      raise 'stalled transport ignored its write timeout'
    rescue IO::TimeoutError => error
      raise if kind=='tls-false'
      raise 'write deadline exceeded two seconds' if Process.clock_gettime(Process::CLOCK_MONOTONIC)-write_started>2
      puts [kind,error.class.name].join(':')
    rescue TypeError => error
      raise unless kind=='tls-false'
      puts [kind,error.class.name].join(':')
    end
  end
ensure
  begin;tcp.close if tcp && !tcp.closed?;rescue StandardError;end
  begin;ssl.close if ssl;rescue StandardError;end
end
'''
INHERITED=r'''
require 'io/nonblock'
writer=IO.new(ARGV.fetch(0).to_i,'w')
writer.sync=true
begin
  p writer.nonblock?
  writer.timeout=0.02
  begin
    writer.write('x')
    raise 'inherited full pipe ignored timeout'
  rescue IO::TimeoutError=>error
    p [error.class,error.message]
  end
  p writer.nonblock?
ensure
  writer.close
end
'''

RESOURCE=r'''
folder=File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'
GC.start
before=Dir.children(folder).size
payload='p'*1_000_000
ARGV.fetch(0).to_i.times do |index|
  reader,writer=IO.pipe
  begin
    writer.timeout=0.0001
    begin
      writer.write(payload)
      raise 'resource fixture did not stall'
    rescue IO::TimeoutError
    end
  ensure
    reader.close
    writer.close
  end
  GC.start if index%20==19
end
GC.start
after=Dir.children(folder).size
raise "timed writer descriptors leaked #{before}->#{after}" unless before==after
puts 'timed writer descriptors released and buffered suffixes discarded'
'''


def run(binary, arguments, **kwargs):
    env=os.environ.copy()
    for key in ('RUBYLIB','RUBYOPT','GEM_HOME','GEM_PATH','http_proxy','https_proxy','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY'):
        env.pop(key,None)
    env['MERE_RUBY_NO_GEMS']='1'
    result=subprocess.run([binary,*arguments],capture_output=True,text=True,timeout=20,env=env,**kwargs)
    assert result.returncode==0,(binary,arguments,result.returncode,result.stdout[-4000:],result.stderr[-4000:])
    return result


def inherited(binary):
    reader,writer=os.pipe()
    try:
        os.set_blocking(writer,False)
        try:
            while True:os.write(writer,b'x'*4096)
        except BlockingIOError:pass
        os.set_blocking(writer,True)
        before=fcntl.fcntl(writer,fcntl.F_GETFL)
        result=run(binary,['-e',INHERITED,str(writer)],pass_fds=(writer,))
        assert fcntl.fcntl(writer,fcntl.F_GETFL)==before,'descriptor flags changed'
        assert result.stdout.count('false')==2 and 'IO::TimeoutError' in result.stdout,result
        return result.stdout
    finally:
        os.close(reader)
        os.close(writer)


class StalledPeer:
    def __init__(self, context=None):
        self.listener=socket.socket()
        self.listener.setsockopt(socket.SOL_SOCKET,socket.SO_RCVBUF,4096)
        self.listener.bind(('127.0.0.1',0))
        self.port=self.listener.getsockname()[1]
        self.listener.listen(1)
        self.listener.settimeout(5)
        self.context=context
        self.stop=threading.Event()
        self.accepted=False
        self.errors=[]
    def worker(self):
        connection=None
        try:
            connection,_=self.listener.accept()
            connection.settimeout(5)
            if self.context:connection=self.context.wrap_socket(connection,server_side=True)
            self.accepted=True
            self.stop.wait(20)
        except Exception as error:
            self.errors.append(str(error))
        finally:
            if connection:connection.close()
    def __enter__(self):
        self.thread=threading.Thread(target=self.worker,daemon=True)
        self.thread.start()
        return self
    def __exit__(self,*args):
        self.stop.set()
        self.thread.join(6)
        self.listener.close()
        assert not self.thread.is_alive(),'stalled peer did not stop'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',type=Path,default=ROOT/'mere-ruby')
    parser.add_argument('--reference',default=os.environ.get('REF_RUBY_BIN','ruby'))
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    reference=shutil.which(args.reference)
    assert reference,'reference Ruby unavailable'
    candidate=str(args.binary.resolve())
    args.output.mkdir(parents=True,exist_ok=False)
    records={}
    for file in ('589_io_write_deadlines.rb','590_io_write_scheduler.rb'):
        script=str(ROOT/'corpus'/file)
        expected=run(reference,[script]).stdout
        actual=run(candidate,[script]).stdout
        assert actual==expected,(file,actual,expected)
        print(file,'matches reference',flush=True)
    allocations=[]
    for count in (20,200):
        script=args.output/('resources-'+str(count)+'.rb')
        script.write_text(RESOURCE)
        env=dict(os.environ,MERE_REGION_STATS='1')
        log=args.output/('resources-'+str(count)+'.log')
        record=supervise([candidate,str(script),str(count)],env,log,2097152,60)
        text=log.read_text()
        assert record['exit']==0 and record['limit'] is None,(count,record,text[-2000:])
        assert 'timed writer descriptors released' in text,text
        match=re.search(r'region-stats default:.*alloc_total=(\d+)',text)
        assert match,'region statistics missing'
        allocations.append(int(match[1]))
        records['resources-'+str(count)]=record
    assert allocations[1]<allocations[0]+64*1024*1024,allocations
    print('timed writers20/200: descriptor cleanup, bounded memory and default arena allocations',allocations,flush=True)
    expected=inherited(reference)
    assert inherited(candidate)==expected
    print('inherited blocking write: deadline enforced, real descriptor flags preserved',flush=True)
    fixture=args.output/'server.pem'
    subprocess.run([reference,'-ropenssl','-e',PREPARE,str(fixture)],check=True,capture_output=True,timeout=30)
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(str(fixture)+'.crt',str(fixture))
    script=args.output/'client.rb'
    script.write_text(PROGRAM)
    for name,binary in (('reference',reference),('native',candidate)):
        for kind in ('tcp','tls','tls-custom','tls-false','http','https'):
            with StalledPeer(context if kind.startswith('tls') or kind=='https' else None) as peer:
                started=time.monotonic()
                result=run(binary,[str(script),kind,str(peer.port),str(fixture)+'.crt'])
                elapsed=time.monotonic()-started
                expected=kind+':'+('Net::WriteTimeout' if kind in ('http','https') else 'TypeError' if kind=='tls-false' else 'IO::TimeoutError')+'\n'
                (args.output/(name+'-'+kind+'.log')).write_text(result.stdout+result.stderr)
                assert result.stdout==expected,(name,kind,result.stdout,result.stderr)
                assert peer.accepted and not peer.errors,(name,kind,peer.errors)
                assert elapsed<20,(name,kind,elapsed)
                records[name+'-'+kind]={'passed':True,'seconds':round(elapsed,3),'report':result.stdout.strip()}
                (args.output/'results.json').write_text(json.dumps(records,indent=2)+'\n')
                print(name,kind,'stalled upload timed out',flush=True)

if __name__=='__main__':main()
