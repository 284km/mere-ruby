#!/usr/bin/env python3
"""Measure real local HTTPS with explicit trust and hostname rejection."""
import argparse
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import threading

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'unittest'))
from ci import supervise
from openssl_memory_check import PREPARE

CLIENT=r'''
begin
  require 'openssl'
  require 'socket'
  if ARGV[0]=='excon'
    $LOAD_PATH.unshift(ENV.fetch('RUBYGEMS_LIB'))
    require 'rubygems'
    require 'excon'
  elsif ARGV[0]!='direct'
    require 'net/http'
  end
rescue LoadError => error
  puts "UNAVAILABLE #{error.message}"
  exit 2
end
mode,cert_file,port,scenario=ARGV
host=scenario=='hostname' ? '127.0.0.1' : 'localhost'
store=OpenSSL::X509::Store.new
store.add_cert(OpenSSL::X509::Certificate.new(File.binread(cert_file))) unless scenario=='trust'
begin
  if mode=='direct'
    socket=TCPSocket.new(host,port.to_i)
    context=OpenSSL::SSL::SSLContext.new
    context.cert_store=store
    context.verify_mode=OpenSSL::SSL::VERIFY_PEER
    context.verify_hostname=true
    tls=OpenSSL::SSL::SSLSocket.new(socket,context)
    tls.hostname=host
    tls.connect
    tls.syswrite("GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")
    bytes=''.b
    until bytes.include?("\r\n\r\n") && bytes.split("\r\n\r\n",2)[1].bytesize>=15
      bytes << tls.sysread(4096)
    end
    raise 'HTTP body changed' unless bytes.split("\r\n\r\n",2)[1]=="https\0verified\n"
  elsif mode=='excon'
    options={ssl_verify_peer_host:host,ssl_verify_peer:true,ssl_ca_file:cert_file,connect_timeout:5,read_timeout:5,write_timeout:5}
    options[:ssl_ca_file]=cert_file+'.untrusted' if scenario=='trust'
    # The independent listener binds IPv4. Keep certificate/SNI hostname
    # verification explicit so localhost's ::1 candidate cannot select a
    # different, unlistened endpoint in Excon's nonblocking fallback.
    response=Excon.get("https://127.0.0.1:#{port}/",**options)
    raise 'HTTP status/body changed' unless response.status==200 && response.body=="https\0verified\n"
  else
    http=Net::HTTP.new(host,port.to_i,nil)
    http.use_ssl=true
    http.cert_store=store
    http.verify_mode=OpenSSL::SSL::VERIFY_PEER
    http.verify_hostname=true
    http.open_timeout=5
    http.read_timeout=5
    response=http.get('/')
    raise 'HTTP status/body changed' unless response.code=='200' && response.body=="https\0verified\n"
  end
  raise 'invalid peer was accepted' unless scenario=='success'
  puts 'PASS verified HTTPS and binary HTTP response'
rescue OpenSSL::SSL::SSLError => error
  raise if scenario=='success'
  puts "PASS rejected #{scenario}"
rescue StandardError => error
  raise unless mode=='excon' && scenario!='success' && error.is_a?(Excon::Errors::SocketError) && error.message.include?('certificate')
  puts "PASS rejected #{scenario}"
ensure
  tls.close if tls
  socket.close if socket && !socket.closed?
end
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=str(ROOT/'mere-ruby'))
    parser.add_argument('--reference',required=True)
    parser.add_argument('--output',required=True,type=Path)
    parser.add_argument('--modes',nargs='+',choices=['reference','direct','bundled','external','reference-excon','excon','external-excon'])
    parser.add_argument('--require-bundled',action='store_true',help='require all three standalone Net::HTTP outcomes')
    parser.add_argument('--gem-home',type=Path)
    parser.add_argument('--rubygems',type=Path)
    args=parser.parse_args()
    assert bool(args.gem_home)==bool(args.rubygems),'provide both --gem-home and --rubygems'
    args.output.mkdir(parents=True,exist_ok=False)
    assert subprocess.check_output([args.reference,'-e','print RUBY_VERSION'],text=True)=='4.0.9'
    fixture=args.output/'server.pem'
    subprocess.run([args.reference,'-ropenssl','-e',PREPARE,str(fixture)],check=True,capture_output=True,timeout=30)
    if args.gem_home:
        untrusted=args.output/'untrusted.pem'
        subprocess.run([args.reference,'-ropenssl','-e',PREPARE,str(untrusted)],check=True,capture_output=True,timeout=30)
        Path(str(fixture)+'.crt.untrusted').write_bytes(Path(str(untrusted)+'.crt').read_bytes())
    context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(str(fixture)+'.crt',str(fixture))
    listener=socket.socket()
    listener.bind(('127.0.0.1',0))
    listener.listen(8)
    listener.settimeout(.2)
    stop=threading.Event()
    server={'http_responses':0,'tls_rejections':0,'peer_closed_before_http':0,'tls_events':[],'errors':[]}
    workers=[]
    def handle(connection):
        try:
            connection.settimeout(5)
            with context.wrap_socket(connection,server_side=True) as secure:
                request=b''
                while b'\r\n\r\n' not in request and len(request)<8192:
                    chunk=secure.recv(4096)
                    if not chunk:break
                    request+=chunk
                if not request:
                    server['peer_closed_before_http']+=1
                    return
                if not request.startswith(b'GET / HTTP/1.1\r\n'):raise ValueError('unexpected HTTP request')
                body=b'https\0verified\n'
                secure.sendall(b'HTTP/1.1 200 OK\r\nContent-Length: '+str(len(body)).encode()+b'\r\nConnection: close\r\n\r\n'+body)
                server['http_responses']+=1
                # Send TLS close_notify. Closing the TCP socket directly
                # is a truncated TLS stream, which strict readers reject.
                try:secure.unwrap().close()
                except (ssl.SSLError,socket.timeout):pass
        except ssl.SSLError as error:
            server['tls_rejections']+=1
            server['tls_events'].append(str(error))
        except Exception as error:server['errors'].append(str(error))
        finally:connection.close()
    def serve():
        while not stop.is_set():
            try:connection,_=listener.accept()
            except socket.timeout:continue
            worker=threading.Thread(target=handle,args=(connection,),daemon=True)
            workers.append(worker)
            worker.start()
    thread=threading.Thread(target=serve,daemon=True)
    thread.start()
    stdlib=subprocess.check_output([args.reference,'-rrbconfig','-rrubygems','-e',
        'print ([RbConfig::CONFIG["rubylibdir"]]+Dir[File.join(Gem.default_dir,"gems","*","lib")].sort).join(":")'],text=True)
    script=args.output/'client.rb'
    script.write_text(CLIENT)
    rows=[]
    try:
        modes=['reference','direct','bundled','external']
        if args.gem_home:modes+=['reference-excon','excon','external-excon']
        if args.modes:modes=args.modes
        for mode in modes:
            for scenario in ('success','trust','hostname'):
                env=os.environ.copy()
                for name in ('RUBYOPT','RUBYLIB','GEM_HOME','GEM_PATH','HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy'):
                    env.pop(name,None)
                env['MERE_RUBY_NO_GEMS']='1'
                if 'excon' in mode:
                    env.update(GEM_HOME=str(args.gem_home.resolve()),GEM_PATH=str(args.gem_home.resolve()),RUBYGEMS_LIB=str((args.rubygems/'lib').resolve()))
                command=[args.reference,'--disable-gems'] if mode.startswith('reference') else [args.binary]
                if mode.startswith('external'):command+=['-I',stdlib]
                command += [str(script),'excon' if 'excon' in mode else 'direct' if mode=='direct' else 'http',str(fixture)+'.crt',str(listener.getsockname()[1]),scenario]
                log=args.output/(mode+'-'+scenario+'.log')
                result=supervise(command,env,log,1048576,30)
                result.update(mode=mode,scenario=scenario,report=log.read_text(errors='replace').strip())
                result['passed']=result['exit']==0 and result['limit'] is None and any(line.startswith('PASS ') for line in result['report'].splitlines())
                rows.append(result)
                print(mode,scenario,result['report'][-500:],flush=True)
    finally:
        stop.set()
        thread.join(6)
        listener.close()
        for worker in workers:worker.join(6)
    (args.output/'results.json').write_text(json.dumps({'rows':rows,'server':server},indent=2)+'\n')
    assert not thread.is_alive() and not any(worker.is_alive() for worker in workers) and not server['errors'],server
    assert all(row['passed'] for row in rows if row['mode'] in ('reference','direct')),rows
    if args.require_bundled:
        bundled=[row for row in rows if row['mode']=='bundled']
        assert len(bundled)==3 and all(row['passed'] for row in bundled),bundled

if __name__=='__main__':main()
