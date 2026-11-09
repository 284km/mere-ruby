#!/usr/bin/env python3
"""Exercise the copied-byte provider ABI independently of the Ruby frontend."""
import argparse
import ctypes
import hashlib
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent


def pack(value):
    if value is None:
        return b'n'
    if isinstance(value, bool):
        return b't' if value else b'f'
    if isinstance(value, int):
        text = str(value).encode()
        return b'i' + struct.pack('!I', len(text)) + text
    if isinstance(value, str):
        value = value.encode()
    if isinstance(value, bytes):
        return b's' + struct.pack('!I', len(value)) + value
    if isinstance(value, list):
        return b'a' + struct.pack('!I', len(value)) + b''.join(map(pack, value))
    if isinstance(value, dict):
        return b'm' + struct.pack('!I', len(value)) + b''.join(pack(k)+pack(v) for k,v in value.items())
    raise TypeError(value)


def unpack(source, position=0):
    kind = source[position:position+1]
    position += 1
    if kind in (b'n', b't', b'f'):
        return {b'n': None, b't': True, b'f': False}[kind], position
    if kind == b'e':
        name, position = unpack(source, position)
        message, position = unpack(source, position)
        return ('error', name, message), position
    size, = struct.unpack_from('!I', source, position)
    position += 4
    if kind == b'h':
        name, position = unpack(source, position)
        return ('handle', name.decode(), size), position
    if kind in (b's', b'i'):
        value = source[position:position+size]
        return (int(value) if kind == b'i' else value), position + size
    assert kind in (b'a', b'm'), kind
    values = []
    for _ in range(size * (2 if kind == b'm' else 1)):
        value, position = unpack(source, position)
        values.append(value)
    return (dict(zip(values[::2], values[1::2])) if kind == b'm' else values), position


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prefix', type=Path)
    args = parser.parse_args()
    flags = []
    if args.prefix:
        flags = [f'-I{args.prefix}/include', f'-L{args.prefix}/lib', f'-Wl,-rpath,{args.prefix}/lib']
    elif sys.platform == 'darwin':
        prefix = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip()
        flags = [f'-I{prefix}/include', f'-L{prefix}/lib', f'-Wl,-rpath,{prefix}/lib']
    with tempfile.TemporaryDirectory(prefix='mr-ossl-provider-') as temp:
        library = Path(temp)/'provider.so'
        subprocess.run(['clang', '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                        str(ROOT/'tools/openssl_glue.c'), *flags, '-pthread', '-lssl', '-lcrypto', '-o', str(library)], check=True)
        lib = ctypes.CDLL(str(library))
        lib.mr_ossl_call.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
        lib.mr_ossl_call.restype = ctypes.c_void_p
        lib.mr_ossl_clear_result.argtypes = []
        lib.mr_ossl_clear_result.restype = ctypes.c_int

        def raw(op, wire, declared_size=None):
            request = ctypes.create_string_buffer(struct.pack('q', len(wire) if declared_size is None else declared_size) + wire)
            result = lib.mr_ossl_call(op.encode(), request)
            length, = struct.unpack('q', ctypes.string_at(result, 8))
            response = ctypes.string_at(result + 8, length)
            lib.mr_ossl_clear_result()
            value, consumed = unpack(response)
            assert consumed == len(response)
            return value

        def call(op, *args):
            return raw(op, pack(list(args)))

        assert call('version').startswith(b'OpenSSL 3.')
        rng = random.Random(7731)
        for _ in range(200):
            a, b = rng.randrange(-10**40, 10**40), rng.randrange(1, 10**20)
            q = (abs(a)//b) * (-1 if a < 0 else 1)
            for op, expected in [('add', a+b), ('sub', a-b), ('mul', a*b), ('mod', a-q*b), ('gcd', math.gcd(a,b))]:
                assert int(call('bn.'+op, a, b)) == expected, op
            assert list(map(int, call('bn.div', a, b))) == [q, a-q*b]
            exponent = rng.randrange(100)
            assert int(call('bn.mod_exp', a, exponent, b)) == pow(a, exponent, b)
        assert call('bn.div', 1, 0)[0] == 'error'
        assert call('bn.mod_exp', 2, 999, 98, 0, 4)[0] == 'error'
        assert call('bn.prime', 101) is True
        assert call('bn.prime', 100) is False
        assert int(call('bn.generate_prime', 32, False, 4, 3)) % 4 == 3
        for _ in range(50):
            assert 192 <= int(call('bn.rand', 8, 1, True)) <= 255
            assert int(call('bn.rand', 8, 1, True)) % 2 == 1
            assert 0 <= int(call('bn.rand_range', 256)) < 256
        for wire in (b'', b'x', b's\0\0\0\xff', b'a\0\0\0\x01', b'a\xff\xff\xff\xff', b'a\0\0\0\0x', b'a\0\0\0\x01'*70+b'n'):
            assert raw('version', wire)[0] == 'error', wire[:20]
        assert raw('version', b'', -1)[0] == 'error'
        assert raw('version', b'', 64*1024*1024+1)[0] == 'error'
        assert call('bn.add', b'12\0invalid', 3)[0] == 'error'
        key=call('pkey.generate_key','RSA',{'rsa_keygen_bits':512})
        assert key[:2] == ('handle','OpenSSL::PKey::RSA'),key
        kid=key[2]
        n,e=(int(call('pkey.get_bn',kid,p)) for p in ('n','e'))
        data=b'independent signature\0payload'
        signature=call('pkey.sign',kid,'SHA256',data,{})
        size=(n.bit_length()+7)//8
        digest_info=bytes.fromhex('3031300d060960864801650304020105000420')+hashlib.sha256(data).digest()
        assert pow(int.from_bytes(signature,'big'),e,n).to_bytes(size,'big') == b'\0\x01'+b'\xff'*(size-len(digest_info)-3)+b'\0'+digest_info
        public=call('pkey.read',call('pkey.export',kid,'public_der',None,None),None,'RSA')
        assert call('pkey.verify',public[2],'SHA256',signature,data,{}) is True
        assert call('pkey.verify',public[2],'SHA256',signature,data+b'x',{}) is False
        encrypted=call('pkey.export',kid,'private_pem','AES-128-CBC','password')
        assert call('pkey.read',encrypted,None)[1] == b'OpenSSL::PKey::PasswordRequired'
        restored=call('pkey.read',encrypted,'password')
        copied=call('object.copy',kid)
        assert call('object.release',kid) is True
        assert call('object.release',kid) is False
        assert call('pkey.private',kid)[0] == 'error'
        assert call('pkey.private',copied[2]) is True
        assert call('pkey.private',restored[2]) is True
        group=call('ec_group.new','GFp','17','2','2')
        point=call('ec_point.new',group[2],bytes.fromhex('040603'))
        assert call('object.release',group[2]) is True
        assert call('ec_point.octets',point[2],4)==bytes.fromhex('040603')
        assert call('pkey.private',point[2])[0]=='error'
        assert call('object.release',point[2]) is True
        # Real generation progress is delivered once and acknowledged before
        # the worker continues. Cancellation also wakes a pending callback.
        job=call('keygen.start','RSA',{'rsa_keygen_bits':512},False)
        deadline=time.monotonic()+10
        progress=0
        while True:
            assert time.monotonic()<deadline,'generation worker stalled'
            state=call('keygen.poll',job[2])
            if state[0]==b'progress':
                progress+=1
                assert call('keygen.respond',job[2]) is None
            elif state[0]==b'done':
                generated=state[1]
                break
            else:
                assert state==[b'pending'],state
                time.sleep(0.001)
        assert progress>0
        assert call('object.release',job[2]) is True
        cancelled=call('keygen.start','RSA',{'rsa_keygen_bits':4096},False)
        assert call('object.release',cancelled[2]) is True
        check_x509(call, Path(temp))
        for handle in (public,restored,copied,generated):
            assert call('object.release',handle[2]) is True
        assert call('object.stats')[0]==0
        assert call('errors') == []
        print('OpenSSL provider ABI: wire bounds, BN, RSA signatures, typed ownership, EC lifetime, generation callbacks and X509 chains pass')


def check_x509(call, directory):
    handles=[]
    def owned(op,*args):
        value=call(op,*args)
        assert value[0]=='handle',(op,value)
        handles.append(value[2])
        return value[2]
    constants=call('x509.constants')
    key=owned('pkey.generate_key','RSA',{'rsa_keygen_bits':2048})
    root_name=owned('xname.new',None)
    leaf_name=owned('xname.new',None)
    assert call('xname.add',root_name,'CN','independent CA',12,-1,0) is None
    assert call('xname.add',leaf_name,'CN','example.test',12,-1,0) is None
    now=int(time.time())
    def cert(name,serial,issuer):
        result=owned('xcert.new',None)
        for field,value in [('version',2),('serial',str(serial)),('subject',name),('issuer',issuer),
                            ('public_key',key),('not_before',now-60),('not_after',now+3600)]:
            assert call('xcert.set_'+field,result,value) is None,(field,value)
        return result
    root=cert(root_name,2**100,root_name)
    ext=owned('xext.create','basicConstraints','critical,CA:TRUE',False,root,root,None,None,None)
    assert call('xcert.add_extension',root,ext) is None
    assert call('xcert.sign',root,key,'SHA256') is None
    leaf=cert(leaf_name,2,root_name)
    assert call('xcert.sign',leaf,key,'SHA256') is None
    assert call('xcert.verify',leaf,key) is True
    assert call('xcert.serial',root)==str(2**100).encode()
    root_path,leaf_path=directory/'root.pem',directory/'leaf.pem'
    root_path.write_bytes(call('xcert.to_pem',root))
    leaf_path.write_bytes(call('xcert.to_pem',leaf))
    reference=subprocess.check_output(['sh','-c','. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"','sh',str(ROOT)],text=True)
    subprocess.run([reference,'-ropenssl','-e',r'''
root,leaf=ARGV.map { |path| OpenSSL::X509::Certificate.new(File.binread(path)) }
raise 'serial changed' unless root.serial==2**100
raise 'native signature rejected' unless leaf.verify(root.public_key)
store=OpenSSL::X509::Store.new
store.add_cert(root)
raise "native chain rejected: #{store.error_string}" unless store.verify(leaf)
raise 'DER round trip changed' unless OpenSSL::X509::Certificate.new(leaf.to_der).to_der==leaf.to_der
''',str(root_path),str(leaf_path)],check=True,timeout=10)
    store=owned('xstore.new')
    assert call('xstore.add_cert',store,root) is None
    def verify(certificate,reject=False):
        context=owned('xctx.new',store,certificate,[])
        assert call('xctx.start',context,True) is None
        deadline=time.monotonic()+10
        callbacks=0
        while True:
            assert time.monotonic()<deadline,'verification worker stalled'
            step=call('xctx.poll',context)
            if step[0]==b'callback':
                callbacks+=1
                current=call('xctx.current_cert',context)
                assert current[0]=='handle',current
                assert call('object.release',current[2]) is True
                if reject:
                    assert call('xctx.set_error',context,constants[b'V_ERR_APPLICATION_VERIFICATION']) is None
                assert call('xctx.respond',context,step[1] and not reject) is None
            elif step[0]==b'done':
                result=step[1]
                break
            else:
                assert step==[b'pending'],step
                time.sleep(0.001)
        assert callbacks>0
        error=call('xctx.error',context)
        assert call('xctx.stop',context) is None
        return result,error
    assert verify(leaf)==(True,constants[b'V_OK'])
    assert verify(leaf,True)==(False,constants[b'V_ERR_APPLICATION_VERIFICATION'])
    expired=owned('object.copy',leaf)
    assert call('xcert.set_not_after',expired,now-1) is None
    assert call('xcert.sign',expired,key,'SHA256') is None
    assert verify(expired)==(False,constants[b'V_ERR_CERT_HAS_EXPIRED'])
    assert call('xcert.new',b'bad DER')[0]=='error'
    for handle in reversed(handles):
        assert call('object.release',handle) is True


if __name__ == '__main__':
    main()
