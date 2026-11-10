#!/usr/bin/env python3
"""Compare repeated native container initialization and preserved state."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

from openssl_formats_check import PREPARE

ROOT=Path(__file__).resolve().parent.parent
PROGRAM=r'''
require 'openssl'
dir=ARGV.fetch(0)
read=proc { |name| File.binread(File.join(dir,name)) }
key=OpenSSL::PKey.read(read.call('key.pem'))
leaf=OpenSSL::X509::Certificate.new(read.call('leaf.pem'))
basic=OpenSSL::OCSP::BasicResponse.new(read.call('ocsp-basic.der'))
single_bytes=basic.responses.first.to_der
response=OpenSSL::Timestamp::Response.new(read.call('timestamp-response.der'))
info_bytes=response.token_info.to_der
cases=[
 [OpenSSL::PKCS12,[read.call('pkcs12.der'),'password'],true,false],
 [OpenSSL::PKCS7,[read.call('pkcs7.der')],true,false],
 [OpenSSL::OCSP::Request,[read.call('ocsp-request.der')],true,true],
 [OpenSSL::OCSP::Response,[read.call('ocsp-response.der')],true,true],
 [OpenSSL::OCSP::BasicResponse,[read.call('ocsp-basic.der')],true,true],
 [OpenSSL::OCSP::CertificateId,[read.call('ocsp-id.der')],false,false],
 [OpenSSL::OCSP::SingleResponse,[single_bytes],false,false],
 [OpenSSL::Timestamp::Request,[read.call('timestamp-request.der')],true,false],
 [OpenSSL::Timestamp::Response,[read.call('timestamp-response.der')],false,false],
 [OpenSSL::Timestamp::TokenInfo,[info_bytes],false,false],
 [OpenSSL::Netscape::SPKI,[read.call('spki.der')],true,false]
]
cases.each do |klass,args,optional,nil_noop|
  value=klass.new(*args)
  before=value.to_der
  if optional
    raise 'no-argument initialize identity changed' unless value.send(:initialize).equal?(value)
    raise 'no-argument initialize lost state' unless value.to_der==before
  end
  if nil_noop
    raise 'nil initialize identity changed' unless value.send(:initialize,nil).equal?(value)
    raise 'nil initialize lost state' unless value.to_der==before
  end
  10.times do
    raise 'replacement initialize identity changed' unless value.send(:initialize,*args).equal?(value)
    GC.start
    raise 'replacement state changed' unless value.to_der==before
  end
  puts klass.name+' reinitialization preserves identity and data'
end
signer=OpenSSL::PKCS7::SignerInfo.new(leaf,key,'SHA256')
recipient=OpenSSL::PKCS7::RecipientInfo.new(leaf)
10.times do
  signer.send(:initialize,leaf,key,'SHA256')
  recipient.send(:initialize,leaf)
  GC.start
  raise 'signer changed' unless signer.serial==leaf.serial && signer.issuer.to_der==leaf.issuer.to_der
  raise 'recipient changed' unless recipient.serial==leaf.serial && recipient.issuer.to_der==leaf.issuer.to_der
end
puts 'PKCS7 signer and recipient reinitialization preserves native children'
request=OpenSSL::Timestamp::Request.new(read.call('timestamp-request.der'))
info=response.token_info
id=OpenSSL::OCSP::CertificateId.new(read.call('ocsp-id.der'))
values=[request.nonce,info.nonce,info.serial_number,id.serial,signer.serial,recipient.serial]
expected=[(1<<140)+5,(1<<140)+5,(1<<100)+7,2,2,2]
values.zip(expected).each_with_index do |(value,number),index|
  raise 'native integer getter lost BN type' unless value.instance_of?(OpenSSL::BN)
  raise 'native integer magnitude changed' unless value.to_i==number
  raise 'BN method changed' unless value.num_bits==number.bit_length
  hex=number.to_s(16)
  hex='0'+hex if hex.length.odd?
  raise 'BN binary conversion changed' unless value.to_s(2)==[hex].pack('H*')
  puts "BN getter #{index}: #{value.class} #{value.num_bits} #{value.to_s(2).unpack1('H*')}"
end
raise 'optional nonce changed' unless OpenSSL::Timestamp::Request.new.nonce.nil?
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary',default=os.environ.get('MR_BIN',str(ROOT/'mere-ruby')))
    args=parser.parse_args()
    reference=subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    with tempfile.TemporaryDirectory(prefix='mr-openssl-reinitialize-') as temp:
        directory=Path(temp)
        script=directory/'prepare.rb';script.write_text(PREPARE)
        subprocess.run([reference,str(script),temp],check=True,timeout=30,capture_output=True)
        script=directory/'check.rb';script.write_text(PROGRAM)
        outputs=[]
        for binary in (reference,args.binary):
            result=subprocess.run([binary,str(script),temp],capture_output=True,text=True,timeout=45)
            assert result.returncode==0,(binary,result.returncode,result.stdout,result.stderr)
            outputs.append(result.stdout)
        assert outputs[0]==outputs[1],outputs
        print(outputs[1],end='')

if __name__=='__main__':main()
