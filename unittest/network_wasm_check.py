#!/usr/bin/env python3
"""Check portable network values and the asynchronous deadline capability boundary."""
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parent.parent
PROGRAM=r'''
%w[uri timeout net/protocol net/http open-uri resolv net/ftp].each { |feature| require feature }
uri=URI('https://example.invalid:444/a%20b?q=1#fragment')
raise 'URI parse changed' unless uri.host=='example.invalid' && uri.port==444 && uri.request_uri=='/a%20b?q=1'
raise 'URI join changed' unless URI.join('https://example.invalid/a/','../b').to_s=='https://example.invalid/b'
raise 'URI encoding changed' unless URI.decode_www_form(URI.encode_www_form([['a b','c+d']]))==[['a b','c+d']]
raise 'zero timeout changed' unless Timeout.timeout(0) { |seconds| [seconds,:ok] }==[0,:ok]
raise 'nil timeout changed' unless Timeout.timeout(nil) { :ok }==:ok
begin
  Timeout.timeout(1) { raise 'a deadline was silently ignored' }
  raise 'asynchronous deadline silently succeeded'
rescue NotImplementedError => error
  raise 'deadline capability message changed' unless error.message.include?('asynchronous Timeout')
end
raise 'IPv4 reverse name changed' unless Resolv::IPv4.create('192.0.2.42').to_name.to_s=='42.2.0.192.in-addr.arpa'
raise 'IPv6 value changed' unless Resolv::IPv6.create('2001:db8::42').to_s=='2001:db8::42'
message=Resolv::DNS::Message.new(1234)
message.add_question('example.invalid',Resolv::DNS::Resource::IN::A)
decoded=Resolv::DNS::Message.decode(message.encode)
raise 'DNS wire round trip changed' unless decoded.id==1234 && decoded.question.first[0].to_s=='example.invalid'
raise 'HTTP response parser changed' unless Net::HTTPResponse::CODE_TO_OBJ['200']==Net::HTTPOK
# The page has no native shared-memory mappings. Import stubs must fail the
# allocation rather than pretending a private byte string is shared memory.
Warning[:experimental] = false
begin
  IO::Buffer.new(16, IO::Buffer::MAPPED | IO::Buffer::SHARED)
  raise 'native shared mapping silently succeeded'
rescue IO::Buffer::AllocationError
end
puts 'portable URI, network loading, DNS/IP codecs and explicit asynchronous Timeout capability passed'
'''

if __name__=='__main__':
    result=subprocess.run(['node','--stack-size=8000',str(ROOT/'docs/smoke.mjs'),PROGRAM],capture_output=True,text=True,timeout=240)
    expected='portable URI, network loading, DNS/IP codecs and explicit asynchronous Timeout capability passed\n'
    assert result.returncode==0 and result.stdout==expected and not result.stderr,(result.returncode,result.stdout[-3000:],result.stderr[-3000:])
    print(result.stdout,end='')
