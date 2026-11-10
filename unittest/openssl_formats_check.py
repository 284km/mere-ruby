#!/usr/bin/env python3
"""Cross-check native cryptographic containers with an independent reference Ruby."""
import argparse
import ctypes
import base64
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time

from openssl_provider_check import pack, unpack

ROOT=Path(__file__).resolve().parent.parent
PREPARE=r'''
require 'openssl'
dir=ARGV[0]
root_key=OpenSSL::PKey::RSA.generate(2048)
key=OpenSSL::PKey::RSA.generate(2048)
def certificate(name,serial,key,issuer,issuer_key,ca: false,usage: nil)
  cert=OpenSSL::X509::Certificate.new
  cert.version=2
  cert.serial=serial
  cert.subject=OpenSSL::X509::Name.parse('/CN='+name)
  cert.issuer=issuer ? issuer.subject : cert.subject
  cert.public_key=key
  cert.not_before=Time.now-60
  cert.not_after=Time.now+3600
  factory=OpenSSL::X509::ExtensionFactory.new(cert,issuer || cert)
  cert.add_extension(factory.create_extension('basicConstraints',ca ? 'CA:TRUE' : 'CA:FALSE',true))
  key_usage=ca ? 'keyCertSign,cRLSign' : usage=='timeStamping' ? 'digitalSignature' : 'digitalSignature,keyEncipherment'
  cert.add_extension(factory.create_extension('keyUsage',key_usage,true))
  cert.add_extension(factory.create_extension('extendedKeyUsage',usage,true)) if usage
  cert.add_extension(factory.create_extension('subjectKeyIdentifier','hash'))
  cert.add_extension(factory.create_extension('authorityKeyIdentifier','keyid:always'))
  cert.sign(issuer_key || key,'SHA256')
  cert
end
root=certificate('format root',1,root_key,nil,nil,ca:true)
leaf=certificate('format leaf',2,key,root,root_key,usage:'emailProtection,clientAuth')
ocsp=certificate('format OCSP',3,key,root,root_key,usage:'OCSPSigning')
tsa=certificate('format TSA',4,key,root,root_key,usage:'timeStamping')
payload="independent binary\0payload\nsecond line\n"
files={'key.pem'=>key.private_to_pem,'wrong.pem'=>root_key.private_to_pem,
 'root.pem'=>root.to_pem,'leaf.pem'=>leaf.to_pem,'ocsp.pem'=>ocsp.to_pem,'tsa.pem'=>tsa.to_pem,'payload'=>payload}
files['pkcs12.der']=OpenSSL::PKCS12.create('password','format key',key,leaf,[root]).to_der
files['pkcs12-noca.der']=OpenSSL::PKCS12.create('password','format key',key,leaf).to_der
files['pkcs7.der']=OpenSSL::PKCS7.sign(leaf,key,payload,[root],OpenSSL::PKCS7::BINARY).to_der
files['pkcs7-detached.der']=OpenSSL::PKCS7.sign(leaf,key,payload,[root],OpenSSL::PKCS7::BINARY|OpenSSL::PKCS7::DETACHED).to_der
files['pkcs7-encrypted.der']=OpenSSL::PKCS7.encrypt([leaf],payload,'AES-128-CBC',OpenSSL::PKCS7::BINARY).to_der
request=OpenSSL::OCSP::Request.new
id=OpenSSL::OCSP::CertificateId.new(leaf,root,'SHA256')
request.add_certid(id).add_nonce('format nonce').sign(leaf,key,[root])
basic=OpenSSL::OCSP::BasicResponse.new
basic.add_status(id,OpenSSL::OCSP::V_CERTSTATUS_GOOD,nil,nil,-30,300,[])
basic.copy_nonce(request)
basic.sign(ocsp,key,[root],0,'SHA256')
files['ocsp-request.der']=request.to_der
files['ocsp-id.der']=id.to_der
files['ocsp-basic.der']=basic.to_der
files['ocsp-response.der']=OpenSSL::OCSP::Response.create(OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL,basic).to_der
request=OpenSSL::Timestamp::Request.new
request.algorithm='SHA256'
request.message_imprint=OpenSSL::Digest.digest('SHA256',payload)
request.policy_id='1.2.3.4.5'
request.nonce=(1<<140)+5
factory=OpenSSL::Timestamp::Factory.new
factory.gen_time=Time.now
factory.serial_number=(1<<100)+7
factory.allowed_digests=['SHA256']
factory.additional_certs=[root]
files['timestamp-request.der']=request.to_der
files['timestamp-response.der']=factory.create_timestamp(key,tsa,request).to_der
spki=OpenSSL::Netscape::SPKI.new
spki.public_key=key.public_key
spki.challenge='format challenge'
spki.sign(key,'SHA256')
files['spki.der']=spki.to_der
files.each { |name,value| File.binwrite(File.join(dir,name),value) }
puts 'independent format fixtures prepared'
'''
VERIFY=r'''
require 'openssl'
kind,path,dir=ARGV
bytes=File.binread(path)
payload=File.binread(File.join(dir,'payload'))
key=OpenSSL::PKey.read(File.binread(File.join(dir,'key.pem')))
leaf=OpenSSL::X509::Certificate.new(File.binread(File.join(dir,'leaf.pem')))
root=OpenSSL::X509::Certificate.new(File.binread(File.join(dir,'root.pem')))
store=OpenSSL::X509::Store.new
store.add_cert(root)
case kind
when 'pkcs12'
  value=OpenSSL::PKCS12.new(bytes,'password')
  raise 'key changed' unless value.key.public_to_der==key.public_to_der
  raise 'certificate changed' unless value.certificate.to_der==leaf.to_der
  raise 'CA changed' unless value.ca_certs.map(&:to_der)==[root.to_der]
when 'pkcs7'
  value=OpenSSL::PKCS7.new(bytes)
  raise 'signature rejected' unless value.verify([],store,nil,OpenSSL::PKCS7::BINARY)
  raise 'signed data changed' unless value.data==payload
when 'pkcs7-encrypted'
  value=OpenSSL::PKCS7.new(bytes)
  raise 'decryption changed data' unless value.decrypt(key,leaf,OpenSSL::PKCS7::BINARY)==payload
when 'ocsp-request'
  value=OpenSSL::OCSP::Request.new(bytes)
  raise 'OCSP request signature rejected' unless value.verify([leaf,root],store)
when 'ocsp-response'
  value=OpenSSL::OCSP::Response.new(bytes)
  responder=OpenSSL::X509::Certificate.new(File.binread(File.join(dir,'ocsp.pem')))
  raise 'OCSP response signature rejected' unless value.basic.verify([responder,root],store)
  raise 'OCSP nonce changed' unless OpenSSL::OCSP::Request.new(File.binread(File.join(dir,'ocsp-request.der'))).check_nonce(value.basic)==1
when 'timestamp'
  value=OpenSSL::Timestamp::Response.new(bytes)
  request=OpenSSL::Timestamp::Request.new(File.binread(File.join(dir,'timestamp-request.der')))
  raise 'timestamp rejected' unless value.verify(request,store,[root])==value
  raise 'nonce changed' unless value.token_info.nonce==(1<<140)+5
  raise 'serial changed' unless value.token_info.serial_number==(1<<100)+7
when 'spki'
  value=OpenSSL::Netscape::SPKI.new(bytes)
  raise 'SPKAC key changed' unless value.public_key.public_to_der==key.public_to_der
  raise 'SPKAC signature rejected' unless value.verify(value.public_key)
else
  raise 'unknown fixture format'
end
puts kind+' accepted by independent reference Ruby'
'''


class Provider:
    def __init__(self,library):
        self.library=ctypes.CDLL(str(library))
        self.library.mr_ossl_call.argtypes=[ctypes.c_char_p,ctypes.c_void_p]
        self.library.mr_ossl_call.restype=ctypes.c_void_p
        self.library.mr_ossl_clear_result.restype=ctypes.c_int
        self.handles=set()

    def raw(self,operation,*args):
        wire=pack(list(args))
        source=ctypes.create_string_buffer(struct.pack('q',len(wire))+wire)
        ptr=self.library.mr_ossl_call(operation.encode(),source)
        length,=struct.unpack('q',ctypes.string_at(ptr,8))
        response=ctypes.string_at(ptr+8,length)
        self.library.mr_ossl_clear_result()
        value,consumed=unpack(response)
        assert consumed==length,(operation,'corrupt response',consumed,length)
        self.claim(value)
        return value

    def claim(self,value):
        if isinstance(value,tuple) and value[0]=='handle':self.handles.add(value[2])
        elif isinstance(value,list):
            for item in value:self.claim(item)

    def call(self,operation,*args):
        value=self.raw(operation,*args)
        assert not (isinstance(value,tuple) and value[0]=='error'),(operation,value)
        return value

    def error(self,operation,*args):
        value=self.raw(operation,*args)
        assert isinstance(value,tuple) and value[0]=='error',(operation,value)
        return value

    def owned(self,operation,*args):
        value=self.call(operation,*args)
        assert isinstance(value,tuple) and value[0]=='handle',(operation,value)
        return value[2]

    def close(self,handle):
        assert self.call('object.release',handle) is True
        self.handles.remove(handle)

    def finish(self):
        for handle in list(self.handles):self.close(handle)
        assert self.call('object.stats')[0]==0
        assert self.call('errors')==[]


def check_pkcs12(api,files,verify):
    key=api.owned('pkey.read',files('key.pem'),None)
    cert=api.owned('xcert.new',files('leaf.pem'))
    root=api.owned('xcert.new',files('root.pem'))
    value=api.call('pkcs12.new',files('pkcs12.der'),'password')
    container,parsed_key,parsed_cert,chain=value
    assert api.call('pkcs12.to_der',container[2])==files('pkcs12.der')
    api.error('pkcs12.new',files('pkcs12.der'),'wrong password')
    api.close(container[2])
    assert api.call('pkey.export',parsed_key[2],'public_der',None,None)==api.call('pkey.export',key,'public_der',None,None)
    assert api.call('xcert.to_der',parsed_cert[2])==api.call('xcert.to_der',cert)
    assert [api.call('xcert.to_der',v[2]) for v in chain]==[api.call('xcert.to_der',root)]
    created=api.owned('pkcs12.create','password','format key',key,cert,[root],None,None,0,0,0)
    verify('pkcs12',api.call('pkcs12.to_der',created))
    api.call('pkcs12.set_mac',created,'password',b'mac salt',2345,'SHA384')
    verify('pkcs12',api.call('pkcs12.to_der',created))
    duplicate=api.owned('object.copy',created)
    api.close(created)
    verify('pkcs12',api.call('pkcs12.to_der',duplicate))
    # A container parse returns a container, key, certificate and CA. Leave
    # only two slots so failure occurs after partially creating its response.
    name=api.owned('xname.new',None)
    filled=[]
    while api.call('object.stats')[0]<32766:filled.append(api.owned('object.copy',name))
    before=api.call('object.stats')[0]
    for fixture in ('pkcs12.der','pkcs12-noca.der'):
        api.error('pkcs12.new',files(fixture),'password')
        after=api.call('object.stats')[0]
        assert after==before,('failed multi-handle response leaked native objects',before,after)
    for handle in filled:api.close(handle)
    api.call('pkcs12.new',files('pkcs12.der'),'password')
    print('PKCS12 cross-read, passwords, MAC, copy/child lifetime and failed-response ownership passed',flush=True)


def context(api,files):
    key=api.owned('pkey.read',files('key.pem'),None)
    leaf=api.owned('xcert.new',files('leaf.pem'))
    root=api.owned('xcert.new',files('root.pem'))
    store=api.owned('xstore.new')
    api.call('xstore.add_cert',store,root)
    return key,leaf,root,store


def check_pkcs7(api,files,verify):
    key,leaf,root,store=context(api,files)
    payload=files('payload')
    signed=api.owned('pkcs7.new',files('pkcs7.der'))
    assert api.call('pkcs7.verify',signed,[],store,None,128)==[True,payload,None]
    signer=api.call('pkcs7.signers',signed)[0][2]
    certificates=api.call('pkcs7.certificates',signed)
    api.close(signed)
    assert api.call('p7si.serial',signer)==b'2'
    assert abs(api.call('p7si.signed_time',signer)-time.time())<120
    assert api.call('xcert.to_der',certificates[0][2])==api.call('xcert.to_der',leaf)
    detached=api.owned('pkcs7.new',files('pkcs7-detached.der'))
    assert api.call('pkcs7.verify',detached,[],store,payload,128)==[True,payload,None]
    assert api.call('pkcs7.verify',detached,[],store,payload+b'changed',128)[0] is False
    assert api.call('errors')==[]
    encrypted=api.owned('pkcs7.new',files('pkcs7-encrypted.der'))
    assert api.call('pkcs7.decrypt',encrypted,key,leaf,128)==payload
    recipient=api.call('pkcs7.recipients',encrypted)[0][2]
    api.close(encrypted)
    assert api.call('p7ri.serial',recipient)==b'2'
    assert len(api.call('p7ri.enc_key',recipient))==256
    # Close the original signer and key before dataFinal needs their state.
    signer=api.owned('p7si.new',leaf,key,'SHA256')
    manual=api.owned('pkcs7.new',None)
    api.call('pkcs7.set_type',manual,'signed')
    api.call('pkcs7.add_signer',manual,signer)
    api.close(signer)
    api.close(key)
    for cert in (leaf,root):api.call('pkcs7.add_certificate',manual,cert)
    api.call('pkcs7.add_data',manual,payload)
    verify('pkcs7',api.call('pkcs7.to_der',manual))
    smime=api.call('pkcs7.write_smime',manual,None,128)
    assert smime.startswith(b'MIME-Version: 1.0\n')
    decoded,body=api.call('pkcs7.read_smime',smime)
    assert body is None
    assert api.call('pkcs7.to_der',decoded[2])==api.call('pkcs7.to_der',manual)
    key=api.owned('pkey.read',files('key.pem'),None)
    native=api.owned('pkcs7.sign',leaf,key,payload,[root],128)
    duplicate=api.owned('object.copy',native)
    api.close(native)
    verify('pkcs7',api.call('pkcs7.to_der',duplicate))
    native=api.owned('pkcs7.encrypt',[leaf],payload,'AES-128-CBC',128)
    verify('pkcs7-encrypted',api.call('pkcs7.to_der',native))
    wrong=api.owned('pkey.read',files('wrong.pem'),None)
    api.error('pkcs7.decrypt',native,wrong,leaf,128)
    print('PKCS7 signatures, encryption, S/MIME, tampering and signer/recipient/key lifetimes passed',flush=True)


def check_ocsp(api,files,verify):
    key,leaf,root,store=context(api,files)
    responder=api.owned('xcert.new',files('ocsp.pem'))
    request=api.owned('ocsp.req.new',files('ocsp-request.der'))
    response=api.owned('ocsp.res.new',files('ocsp-response.der'))
    basic=api.owned('ocsp.res.basic',response)
    api.close(response)
    assert api.call('ocsp.req.verify',request,[],store,0) is True
    assert api.call('ocsp.bres.verify',basic,[],store,0) is True
    assert api.call('ocsp.req.check_nonce',request,basic)==1
    copy=api.owned('object.copy',request)
    api.call('ocsp.req.add_nonce',copy,b'different nonce')
    assert api.call('ocsp.req.check_nonce',copy,basic)==0
    assert api.call('ocsp.req.verify',copy,[],store,0) is False
    copy=api.owned('object.copy',basic)
    api.call('ocsp.bres.add_nonce',copy,b'different nonce')
    assert api.call('ocsp.bres.verify',copy,[],store,0) is False
    identifier=api.owned('ocsp.cid.new',None,leaf,root,'SHA256')
    assert api.call('ocsp.cid.to_der',identifier)==files('ocsp-id.der')
    assert api.call('ocsp.cid.serial',identifier)==b'2'
    native=api.owned('ocsp.req.new',None)
    api.call('ocsp.req.add_certid',native,identifier)
    api.call('ocsp.req.add_nonce',native,b'format nonce')
    api.call('ocsp.req.sign',native,leaf,key,[root],0,'SHA256')
    verify('ocsp-request',api.call('ocsp.req.to_der',native))
    native=api.owned('ocsp.bres.new',None)
    now=int(time.time())
    api.call('ocsp.bres.add_status',native,identifier,0,0,None,now-30,now+300,[])
    api.call('ocsp.bres.copy_nonce',native,request)
    api.call('ocsp.bres.sign',native,responder,key,[root],0,'SHA256')
    reply=api.owned('ocsp.res.create',0,native)
    verify('ocsp-response',api.call('ocsp.res.to_der',reply))
    single=api.call('ocsp.bres.responses',native)[0][2]
    api.close(native)
    assert api.call('ocsp.single.cert_status',single)==0
    assert api.call('ocsp.single.check_validity',single,0,-1) is True
    copied_id=api.owned('ocsp.single.certid',single)
    assert api.call('ocsp.cid.cmp',copied_id,identifier) is True
    expired=api.owned('ocsp.bres.new',None)
    api.call('ocsp.bres.add_status',expired,identifier,0,0,None,now-120,now-60,[])
    single=api.call('ocsp.bres.responses',expired)[0][2]
    assert api.call('ocsp.single.check_validity',single,0,-1) is False
    untrusted=api.owned('xstore.new')
    assert api.call('ocsp.bres.verify',basic,[],untrusted,0) is False
    print('OCSP cross-signatures, nonce/signature tampering, status/expiry and child lifetimes passed',flush=True)


def check_timestamp(api,files,verify):
    key,leaf,root,store=context(api,files)
    tsa=api.owned('xcert.new',files('tsa.pem'))
    request=api.owned('ts.req.new',files('timestamp-request.der'))
    response=api.owned('ts.res.new',files('timestamp-response.der'))
    assert api.call('ts.res.status',response)==0
    api.call('ts.res.verify',response,request,store,[root])
    info=api.owned('ts.res.token_info',response)
    token=api.owned('ts.res.token',response)
    api.close(response)
    assert int(api.call('ts.info.nonce',info))==(1<<140)+5
    assert int(api.call('ts.info.serial_number',info))==(1<<100)+7
    assert api.call('ts.info.message_imprint',info)==hashlib.sha256(files('payload')).digest()
    signature=api.call('pkcs7.verify',token,[],store,None,128|32)
    assert signature==[True,api.call('ts.info.to_der',info),None]
    serial=str((1<<100)+7)
    native=api.owned('ts.create',key,tsa,request,serial,int(time.time()),None,['SHA256'],[root])
    verify('timestamp',api.call('ts.res.to_der',native))
    wrong=api.owned('object.copy',request)
    api.call('ts.req.set_nonce',wrong,'1')
    api.error('ts.res.verify',native,wrong,store,[root])
    wrong=api.owned('object.copy',request)
    api.call('ts.req.set_message_imprint',wrong,b'\0'*32)
    api.error('ts.res.verify',native,wrong,store,[root])
    wrong=api.owned('object.copy',request)
    api.call('ts.req.set_policy_id',wrong,'1.2.3.4.999')
    api.error('ts.res.verify',native,wrong,store,[root])
    api.error('ts.create',key,leaf,request,serial,int(time.time()),None,['SHA256'],[root])
    untrusted=api.owned('xstore.new')
    api.error('ts.res.verify',native,request,untrusted,[])
    rejected=api.owned('ts.create',key,tsa,request,serial,int(time.time()),None,[],[root])
    assert api.call('ts.res.status',rejected)==2
    assert api.call('ts.res.failure_info',rejected)==b'BAD_ALG'
    print('Timestamp cross-verify, large nonce/serial, PKCS7 signature, purpose/policy/digest/trust rejection and child lifetimes passed',flush=True)


def check_spki(api,files,verify):
    key=api.owned('pkey.read',files('key.pem'),None)
    value=api.owned('spki.new',files('spki.der'))
    assert api.call('spki.verify',value,key) is True
    assert api.call('spki.challenge',value)==b'format challenge'
    native=api.owned('spki.new',None)
    api.call('spki.set_public_key',native,key)
    api.call('spki.set_challenge',native,b'format challenge')
    api.call('spki.sign',native,key,'SHA256')
    der=api.call('spki.to_der',native)
    verify('spki',der)
    assert api.call('spki.to_pem',native)==base64.b64encode(der)
    public=api.owned('spki.public_key',native)
    copy=api.owned('object.copy',native)
    api.close(native)
    assert api.call('spki.verify',copy,public) is True
    api.call('spki.set_challenge',copy,b'changed challenge')
    assert api.call('spki.verify',copy,public) is False
    api.error('spki.new',b'not a SPKAC')
    print('SPKAC cross-signatures, base64/DER, tampering and public-key lifetime passed',flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,default=ROOT/'tools/openssl_glue.c')
    parser.add_argument('--keep',type=Path)
    args=parser.parse_args()
    reference=subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    with tempfile.TemporaryDirectory(prefix='mr-openssl-formats-') as temp:
        directory=args.keep.resolve() if args.keep else Path(temp)
        directory.mkdir(parents=True,exist_ok=True)
        script=directory/'prepare.rb';script.write_text(PREPARE)
        subprocess.run([reference,str(script),str(directory)],check=True,timeout=60)
        flags=[]
        if sys.platform=='darwin':
            prefix=subprocess.check_output(['brew','--prefix','openssl@3'],text=True).strip()
            flags=[f'-I{prefix}/include',f'-L{prefix}/lib',f'-Wl,-rpath,{prefix}/lib']
        library=Path(temp)/'provider.so'
        subprocess.run(['clang','-shared','-fPIC','-Wall','-Wextra','-Werror','-I'+str(ROOT/'tools'),str(args.source.resolve()),*flags,'-pthread','-lssl','-lcrypto','-o',str(library)],check=True,timeout=60)
        api=Provider(library)
        def files(name):return (directory/name).read_bytes()
        def verify(kind,content):
            target=directory/('native-'+kind+'.der');target.write_bytes(content)
            script=directory/'verify.rb';script.write_text(VERIFY)
            subprocess.run([reference,str(script),kind,str(target),str(directory)],check=True,timeout=20)
        check_pkcs12(api,files,verify)
        check_pkcs7(api,files,verify)
        check_ocsp(api,files,verify)
        check_timestamp(api,files,verify)
        check_spki(api,files,verify)
        api.finish()
        print('all native format resources released',flush=True)


if __name__=='__main__':main()
