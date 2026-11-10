#!/usr/bin/env python3
"""Exercise the bundled resolver against independent UDP/TCP DNS peers."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import threading

ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,str(ROOT/'unittest'))
from ci import supervise

PROGRAM=r'''
%w[uri timeout net/protocol net/http open-uri resolv net/ftp].each { |feature| require feature }
raise 'URI parser changed' unless URI('https://example.invalid/a%20b?q=1').request_uri=='/a%20b?q=1'
raise 'Timeout result changed' unless Timeout.timeout(1) { :ready }==:ready
begin
  Timeout.timeout(0.02) { sleep 1 }
  raise 'timeout did not interrupt the block'
rescue Timeout::Error
end
port=ARGV.fetch(0).to_i
fd_dir=File.directory?('/proc/self/fd') ? '/proc/self/fd' : '/dev/fd'
def resolve_once(port)
  resolver=Resolv::DNS.new(nameserver_port:[['127.0.0.1',port]],search:[],ndots:1)
  resolver.timeouts=[0.1]
  begin
    raise 'UDP address changed' unless resolver.getaddress('udp.network.invalid').to_s=='192.0.2.42'
    raise 'TCP fallback changed' unless resolver.getaddress('tcp.network.invalid').to_s=='192.0.2.42'
    ipv6=resolver.getresource('ipv6.network.invalid',Resolv::DNS::Resource::IN::AAAA).address
    raise 'AAAA bytes changed' unless ipv6.to_s=='2001:db8::42'
    raise 'mismatched DNS transaction was accepted' unless resolver.getaddress('wrongid.network.invalid').to_s=='192.0.2.42'
    begin
      resolver.getaddress('missing.network.invalid')
      raise 'NXDOMAIN accepted'
    rescue Resolv::ResolvError
    end
  ensure
    resolver.close
  end
end
# Warm native TCP/resolver startup before measuring repeated lifetimes.
# macOS libc opens a persistent com.apple.netsrc control socket on first use.
resolve_once(port)
before=Dir.children(fd_dir).size
10.times { resolve_once(port) }
resolver=Resolv::DNS.new(nameserver_port:[['127.0.0.1',port]],search:[],ndots:1)
resolver.timeouts=[0.02]
begin
  begin
    resolver.getaddress('timeout.network.invalid')
    raise 'dropped DNS request did not time out'
  rescue Resolv::ResolvError, Resolv::ResolvTimeout
  end
ensure
  resolver.close
end
# A connected UDP socket must preserve ICMP errors. Linux answers immediately;
# platforms which suppress ICMP are still bounded by this explicit deadline.
closed=UDPSocket.new
closed.bind('127.0.0.1',0)
closed_port=closed.addr[1]
closed.close
resolver=Resolv::DNS.new(nameserver_port:[['127.0.0.1',closed_port]],search:[],ndots:1)
resolver.timeouts=[0.05]
begin
  Timeout.timeout(1) do
    raise 'closed DNS port returned records' unless resolver.getresources('closed.network.invalid',Resolv::DNS::Resource::IN::A).empty?
  end
ensure
  resolver.close
end
GC.start
after=Dir.children(fd_dir).size
raise "resolver descriptors leaked: #{before} -> #{after}" unless after==before
puts 'bundled network load, Timeout, UDP/TCP DNS, AAAA, transaction IDs, NXDOMAIN, deadline and descriptor cleanup passed'
'''

class DNSPeer:
    def __init__(self):
        self.udp=socket.socket(socket.AF_INET,socket.SOCK_DGRAM)
        self.udp.bind(('127.0.0.1',0))
        self.port=self.udp.getsockname()[1]
        self.tcp=socket.socket()
        self.tcp.bind(('127.0.0.1',self.port))
        self.tcp.listen(8)
        self.udp.settimeout(.2)
        self.tcp.settimeout(.2)
        self.stop=threading.Event()
        self.events=[]
        self.errors=[]
        self.threads=[]

    def answer(self,data,protocol):
        if len(data)<12:raise ValueError('short DNS request')
        transaction,flags,questions,_,_,_=struct.unpack('!6H',data[:12])
        if questions!=1:raise ValueError('expected one DNS question')
        labels=[]
        position=12
        while data[position]:
            length=data[position]
            labels.append(data[position+1:position+1+length].decode('ascii'))
            position+=length+1
        position+=1
        kind,klass=struct.unpack('!HH',data[position:position+4])
        if klass!=1:raise ValueError('expected IN class')
        name='.'.join(labels)
        if not name.endswith('.network.invalid'):raise ValueError('unexpected DNS name')
        self.events.append((protocol,name,kind))
        question=data[12:position+4]
        if name.startswith('timeout.'):return []
        if name.startswith('missing.'):
            return [struct.pack('!6H',transaction,0x8183,1,0,0,0)+question]
        if kind==28 and not name.startswith('ipv6.'):
            return [struct.pack('!6H',transaction,0x8180,1,0,0,0)+question]
        if name.startswith('tcp.') and protocol=='udp':
            return [struct.pack('!6H',transaction,0x8380,1,0,0,0)+question]
        address=ipaddress.ip_address('2001:db8::42' if kind==28 else '192.0.2.42').packed
        def response(identifier,value):
            answer=b'\xc0\x0c'+struct.pack('!HHIH',kind,1,60,len(value))+value
            return struct.pack('!6H',identifier,0x8180,1,1,0,0)+question+answer
        packets=[]
        if name.startswith('wrongid.'):
            packets.append(response(transaction^1,ipaddress.ip_address('198.51.100.66').packed))
        packets.append(response(transaction,address))
        return packets

    def udp_loop(self):
        while not self.stop.is_set():
            try:data,address=self.udp.recvfrom(65535)
            except socket.timeout:continue
            try:
                for packet in self.answer(data,'udp'):self.udp.sendto(packet,address)
            except Exception as error:self.errors.append(str(error))

    @staticmethod
    def exact(connection,size):
        data=b''
        while len(data)<size:
            chunk=connection.recv(size-len(data))
            if not chunk:raise EOFError('short DNS TCP stream')
            data+=chunk
        return data

    def tcp_loop(self):
        while not self.stop.is_set():
            try:connection,_=self.tcp.accept()
            except socket.timeout:continue
            try:
                connection.settimeout(2)
                length=struct.unpack('!H',self.exact(connection,2))[0]
                for packet in self.answer(self.exact(connection,length),'tcp'):
                    connection.sendall(struct.pack('!H',len(packet))+packet)
            except Exception as error:self.errors.append(str(error))
            finally:connection.close()

    def __enter__(self):
        for target in (self.udp_loop,self.tcp_loop):
            thread=threading.Thread(target=target,daemon=True)
            self.threads.append(thread)
            thread.start()
        return self

    def __exit__(self,*args):
        self.stop.set()
        for thread in self.threads:thread.join(3)
        self.udp.close()
        self.tcp.close()
        assert not any(thread.is_alive() for thread in self.threads)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=os.environ.get('MR_BIN',str(ROOT/'mere-ruby')))
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    args.output.mkdir(parents=True,exist_ok=False)
    reference=subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    script=args.output/'peer.rb'
    script.write_text(PROGRAM)
    records={}
    with DNSPeer() as peer:
        for name,binary in [('reference',reference),('native',args.binary)]:
            env=os.environ.copy()
            for key in ('RUBYLIB','RUBYOPT','GEM_HOME','GEM_PATH'):env.pop(key,None)
            env['MERE_RUBY_NO_GEMS']='1'
            log=args.output/(name+'.log')
            start=len(peer.events)
            result=supervise([binary,str(script),str(peer.port)],env,log,2097152,60)
            events=peer.events[start:]
            result['events']=events
            records[name]=result
            (args.output/'results.json').write_text(json.dumps(records,indent=2)+'\n')
            assert result['exit']==0 and result['limit'] is None,(name,{key:value for key,value in result.items() if key!='events'},log.read_text()[-3000:])
            assert not peer.errors,peer.errors
            assert sum(protocol=='tcp' for protocol,_,_ in events)==11,events
            assert any(name=='timeout.network.invalid' for _,name,_ in events),events
            print(name,log.read_text().strip(),flush=True)

if __name__=='__main__':main()
