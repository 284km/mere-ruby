#!/usr/bin/env python3
"""Exercise portable OpenSSL through the shipped playground and its real host."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
PROGRAM = r'''
require 'openssl'
asn=OpenSSL::ASN1
value=asn::Sequence.new([asn::Integer.new(123),asn::ObjectId.new('1.2.840.113549')])
raise 'DER changed' unless value.to_der.unpack1('H*')=='300b02017b06062a864886f70d'
raise 'DER round trip changed' unless asn.decode(value.to_der).to_der==value.to_der
ber=['30800201010000'].pack('H*')
raise 'BER round trip changed' unless asn.decode(ber).to_der==ber
marks=[]
asn.traverse(ber) { |mark| marks << mark }
raise 'BER traversal missing' unless marks.size==3
raise 'BN conversion changed' unless OpenSSL::BN.new('-123456789012345678901234567890').to_s=='-123456789012345678901234567890'
raise 'digest changed' unless OpenSSL::Digest::SHA256.hexdigest('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
raise 'HMAC changed' unless OpenSSL::HMAC.hexdigest('SHA256','key','abc')=='9c196e32dc0175f86f4b1cb89289d6619de6bee699e4c378e68309ed97a1a6ab'
cipher=OpenSSL::Cipher.new('AES-128-ECB')
cipher.encrypt
cipher.padding=0
cipher.key=['000102030405060708090a0b0c0d0e0f'].pack('H*')
encrypted=cipher.update(['00112233445566778899aabbccddeeff'].pack('H*'))+cipher.final
raise 'AES FIPS 197 vector changed' unless encrypted.unpack1('H*')=='69c4e0d86a7b0430d8cdb78070b4c55a'
[
  proc { OpenSSL::PKey.read('unsupported') },
  proc { OpenSSL::X509::Certificate.new },
  proc { OpenSSL::SSL::SSLContext.new }
].each do |operation|
  begin
    operation.call
    raise 'native-only operation silently succeeded'
  rescue NotImplementedError => error
    raise 'capability error lost its cause' unless error.message.include?('native OpenSSL provider')
  end
end
puts 'portable OpenSSL ASN1/BN/Digest/HMAC/AES and native capability errors passed'
'''


if __name__ == '__main__':
    result = subprocess.run(['node', '--stack-size=8000', str(ROOT/'docs/smoke.mjs'), PROGRAM],
                            capture_output=True, text=True, timeout=180)
    expected = 'portable OpenSSL ASN1/BN/Digest/HMAC/AES and native capability errors passed\n'
    assert result.returncode == 0 and result.stdout == expected and not result.stderr, (
        result.returncode, result.stdout[-2000:], result.stderr[-2000:])
    print(result.stdout, end='')
