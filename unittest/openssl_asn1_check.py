#!/usr/bin/env python3
"""Compare DER/BER values, canonical bytes and traversal against native OpenSSL."""
import argparse
import json
import os
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PROBE = r'''
require 'openssl'
require 'json'
def description(node)
  value = node.value
  value = case value
  when Array then value.map { |v| description(v) }
  when String then ['bytes', value.unpack1('H*'), value.encoding.name]
  when OpenSSL::BN then ['bn', value.to_s]
  when Time then ['time', value.to_i]
  else value
  end
  [node.class.name, node.tag, node.tag_class, node.indefinite_length,
   node.respond_to?(:unused_bits) ? node.unused_bits : nil, value, node.to_der.unpack1('H*')]
end
result = JSON.parse(File.read(ARGV[0])).map do |hex|
  begin
    bytes = [hex].pack('H*')
    value = OpenSSL::ASN1.decode(bytes)
    locations = []
    OpenSSL::ASN1.traverse(bytes) { |mark| locations << mark }
    ['ok', description(value), locations]
  rescue StandardError => error
    ['error', error.class.name]
  end
end
puts JSON.generate(result)
'''


def tlv(tag, body):
    size = len(body)
    if size < 128:
        return bytes([tag, size]) + body
    length = size.to_bytes((size.bit_length()+7)//8, 'big')
    return bytes([tag, 128+len(length)]) + length + body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(ROOT/'mere-ruby')))
    parser.add_argument('--keep', type=Path)
    args = parser.parse_args()
    reference = subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    valid = [bytes.fromhex(x) for x in ('0000','010100','0101ff','020100','0202ff00','0500','030200ff','030204f0','060100','06032a0304','30800401610000','a0800201010000','9fc02002abcd')]
    for tag in (4,12,18,19,20,21,22,25,26,27,28,30,65,129,193):
        for body in (b'',b'abc',bytes(range(256))):
            valid.append(tlv(tag,body))
    for n in (0,127,128,255,256,2**200,-1,-128,-129,-2**200):
        size = max(1,(n.bit_length()+8)//8)
        valid.append(tlv(2,n.to_bytes(size,'big',signed=True)))
    for tag,text in ((23,b'490101000000Z'),(23,b'500101000000Z'),(24,b'99991231235959Z'),
                     (23,b'160230234339Z'),(23,b'1609082343Z'),(24,b'20161208193429.5Z'),
                     (24,b'20160230010101Z'),(24,b'20160229010101Z')):
        valid.append(tlv(tag,text))
    rng = random.Random(5517)
    base = list(valid)
    for _ in range(100):
        valid.append(tlv(rng.choice((0x30,0x31,0xa0,0x61)),b''.join(rng.sample(base,3))))
    malformed = [b'',b'\0',b'\0\x01\0',b'\x01\0',b'\x02\0',b'\x05\x01\0',b'\x03\0',b'\x03\x02\x08\xff',b'\x06\0',b'\x06\x01\x80',b'\x30\x80\x05\0',b'\x31\x06\x31\x02\x30\x02\x05\0',b'\x04\x89'+b'\xff'*9]
    for value in base:
        malformed.extend(value[:n] for n in range(min(len(value),12)))
        for _ in range(2):
            changed=bytearray(value)
            if changed:
                changed[rng.randrange(len(changed))] ^= rng.randrange(1,256)
                malformed.append(bytes(changed))
    for _ in range(200):
        malformed.append(bytes(rng.randrange(256) for _ in range(rng.randrange(1,25))))
    cases = list(dict.fromkeys(x.hex() for x in valid+malformed))
    with tempfile.TemporaryDirectory(prefix='mr-asn1-') as tmp:
        folder = Path(tmp)
        script, data = folder/'probe.rb',folder/'data.json'
        script.write_text(PROBE)
        data.write_text(json.dumps(cases))
        outputs=[]
        for binary in (reference,args.binary):
            result=subprocess.run([binary,str(script),str(data)],capture_output=True,text=True,timeout=60)
            assert result.returncode == 0, (binary, result.stderr[-4000:])
            outputs.append(json.loads(result.stdout))
        differences=[{'hex':h,'reference':a,'candidate':b} for h,a,b in zip(cases,*outputs) if a!=b]
        if args.keep:
            args.keep.write_text(json.dumps(differences,indent=2)+'\n')
        assert len(outputs[0])==len(outputs[1])==len(cases)
        assert not differences, f'{len(differences)} ASN.1 differences; first: {differences[:2]}'
        print(f'ASN.1: {len(cases)} DER/BER cases match native values, bytes, errors and traversal')


if __name__=='__main__':
    main()
