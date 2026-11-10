#!/usr/bin/env python3
"""Exercise the copied-byte provider ABI independently of the Ruby frontend."""
import argparse
import ctypes
import hashlib
import hmac
import math
from pathlib import Path
import random
import select
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
import time
import threading

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
    if kind in (b'e', b'E'):
        name, position = unpack(source, position)
        message, position = unpack(source, position)
        if kind == b'E':
            errors, position = unpack(source, position)
            return ('error', name, message, errors), position
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
    parser.add_argument('--source', type=Path, default=ROOT/'tools/openssl_glue.c',
                        help='adapter source, including a historical negative control')
    args = parser.parse_args()
    flags = []
    if args.prefix:
        flags = [f'-I{args.prefix}/include', f'-L{args.prefix}/lib', f'-Wl,-rpath,{args.prefix}/lib']
    elif sys.platform == 'darwin':
        prefix = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip()
        flags = [f'-I{prefix}/include', f'-L{prefix}/lib', f'-Wl,-rpath,{prefix}/lib']
    with tempfile.TemporaryDirectory(prefix='mr-ossl-provider-') as temp:
        library = Path(temp)/'provider.so'
        probe = Path(temp)/'probe.c'
        # Observe the adapter's actual calloc requests without changing the
        # production decoder or OpenSSL's allocator.
        probe.write_text('''#include <stdlib.h>
static unsigned long long requested;
static void *probe_calloc(size_t n,size_t size) {
    requested+=(unsigned long long)n*size;
    return calloc(n,size);
}
#define calloc probe_calloc
''' + '#include "' + str(args.source.resolve()) + '"\n' +
            'unsigned long long mr_test_allocated(void) { return requested; }\n')
        subprocess.run(['clang', '-shared', '-fPIC', '-Wall', '-Wextra', '-Werror',
                        str(probe), '-I'+str(ROOT/'tools'), *flags, '-pthread', '-lssl', '-lcrypto', '-o', str(library)], check=True)
        lib = ctypes.CDLL(str(library))
        lib.mr_ossl_call.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
        lib.mr_ossl_call.restype = ctypes.c_void_p
        lib.mr_ossl_clear_result.argtypes = []
        lib.mr_ossl_clear_result.restype = ctypes.c_int
        lib.mr_test_allocated.restype = ctypes.c_ulonglong

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
        payload=b'independent primitive\0binary vector'
        for algorithm in ('SHA256','SHA384','SHA512','SHA3-256'):
            digest=call('digest.new',algorithm)
            assert digest[0]=='handle',digest
            assert call('digest.update',digest[2],payload) is None
            assert call('digest.final',digest[2])==hashlib.new(algorithm.lower().replace('-','_'),payload).digest()
            assert call('object.release',digest[2]) is True
        mac=call('hmac.new',b'key\0bytes','SHA256')
        assert call('hmac.update',mac[2],payload) is None
        assert call('hmac.final',mac[2])==hmac.digest(b'key\0bytes',payload,'sha256')
        assert call('object.release',mac[2]) is True
        assert call('kdf.pbkdf2',payload,b'salt',48,1200,'SHA256')==hashlib.pbkdf2_hmac('sha256',payload,b'salt',1200,48)
        # RFC 7914's empty-password/salt vector; Python on macOS may lack scrypt.
        assert call('kdf.scrypt',b'',b'',64,16,1,1)==bytes.fromhex('77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906')
        # RFC 5869 test case 1, independent published HKDF output.
        assert call('kdf.hkdf',b'\x0b'*22,bytes(range(13)),42,bytes(range(0xf0,0xfa)),'SHA256')==bytes.fromhex('3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865')
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
        # Each header individually fits the node and remaining-byte limits,
        # but their declared children exceed the aggregate allocation budget.
        # Reject before reserving 64 large arrays for this malformed request.
        nested=b''.join(b'a'+struct.pack('!I',900000-i*5) for i in range(64))+b't'*900000
        before=lib.mr_test_allocated()
        assert raw('version',nested)[0]=='error'
        allocated=lib.mr_test_allocated()-before
        assert 0<allocated<=64*1024*1024,('nested array allocation exceeded budget',allocated)
        print('malformed nested wire calloc bytes:',allocated,flush=True)
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
        print('OpenSSL provider ABI: wire bounds, primitive vectors, BN, RSA signatures, typed ownership, EC lifetime, generation callbacks, X509 chains and independent TLS peers pass')


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
    def extension(target,issuer,oid,value):
        ext=owned('xext.create',oid,value,False,issuer,target,None,None,None)
        assert call('xcert.add_extension',target,ext) is None
    extension(root,root,'basicConstraints','critical,CA:TRUE')
    extension(root,root,'keyUsage','critical,keyCertSign,cRLSign')
    extension(root,root,'subjectKeyIdentifier','hash')
    extension(root,root,'authorityKeyIdentifier','keyid:always')
    assert call('xcert.sign',root,key,'SHA256') is None
    leaf=cert(leaf_name,2,root_name)
    extension(leaf,root,'authorityKeyIdentifier','keyid:always')
    extension(leaf,root,'subjectAltName','DNS:example.test')
    extension(leaf,root,'keyUsage','critical,digitalSignature,keyEncipherment')
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
    key_path=directory/'key.pem'
    key_path.write_bytes(call('pkey.export',key,'private_pem',None,None))
    check_tls(call,owned,store,root_path,leaf_path,key_path,leaf,key)
    expired=owned('object.copy',leaf)
    assert call('xcert.set_not_after',expired,now-1) is None
    assert call('xcert.sign',expired,key,'SHA256') is None
    assert verify(expired)==(False,constants[b'V_ERR_CERT_HAS_EXPIRED'])
    assert call('xcert.new',b'bad DER')[0]=='error'
    for handle in reversed(handles):
        assert call('object.release',handle) is True


def check_tls(call,owned,store,root_path,leaf_path,key_path,certificate,key):
    def operation(handle,transport,kind,data=None,callbacks=None,allow_error=False):
        assert call('tls_job.start',handle,kind,data) is None
        deadline=time.monotonic()+10
        try:
            while True:
                assert time.monotonic()<deadline,'TLS operation stalled'
                step=call('tls_job.poll',handle)
                if allow_error and isinstance(step,tuple) and step[0]=='error':
                    return step
                assert not (isinstance(step,tuple) and step[0]=='error'),(step,peer_errors)
                if step[0]==b'pending':
                    time.sleep(0.001)
                elif step[0]==b'callback':
                    assert callbacks is not None,step[:2]
                    response=callbacks(step[1],step[2])
                    assert call('tls_job.respond',handle,response) is None
                else:
                    assert step[0]==b'done',step
                    status,result=step[1:]
                    if status in (b'wait_readable',b'wait_writable'):
                        assert call('tls_job.stop',handle) is None
                        ready=select.select([transport] if status==b'wait_readable' else [],[transport] if status==b'wait_writable' else [],[],max(0,deadline-time.monotonic()))
                        assert ready[0] or ready[1],'TLS transport stalled'
                        assert call('tls_job.start',handle,kind,data) is None
                    else:
                        assert status==b'ok',(status,result)
                        return result
        finally:
            assert call('tls_job.stop',handle) is None

    payload=b'independent TLS peer\0binary payload'
    observed=[]
    def native_callbacks(kind,data):
        observed.append(kind)
        if kind==1:
            ok,context=data
            assert ok is True
            cert=call('xctx.current_cert',context[2]); assert cert[0]=='handle'
            assert call('object.release',cert[2]) is True
            return True
        if kind==2:
            assert data==b'example.test'
            return None
        if kind==4:
            assert data==b'\x02h2\x08http/1.1'
            return b'h2'
        if kind==16:
            assert len(data.split())==3
            return True
        raise AssertionError(kind)

    peer_errors=[]
    def launch(function):
        def run():
            try: function()
            except BaseException as exc: peer_errors.append(exc)
        thread=threading.Thread(target=run,daemon=True)
        thread.start()
        return thread

    for native_server in (False,True):
        transport,peer=socket.socketpair()
        peer.settimeout(10)
        if native_server:
            context=owned('tls_context.new')
            for field,value in [('cert',certificate),('key',key),('verify_mode',0)]:
                assert call('tls_context.set_'+field,context,value) is None
            assert call('tls_context.callbacks',context,2|4|16) is None
            python_context=ssl.create_default_context(cafile=str(root_path))
            python_context.set_alpn_protocols(['h2','http/1.1'])
            def peer_work():
                with python_context.wrap_socket(peer,server_hostname='example.test') as secured:
                    assert secured.selected_alpn_protocol()=='h2'
                    secured.sendall(payload)
                    assert secured.recv(4096)==payload
            thread=launch(peer_work)
        else:
            context=owned('tls_context.new')
            assert call('tls_context.set_cert_store',context,store) is None
            assert call('tls_context.set_verify_mode',context,1) is None
            assert call('tls_context.callbacks',context,1|16) is None
            assert call('tls_context.set_alpn_protocols',context,b'\x02h2') is None
            python_context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            python_context.load_cert_chain(str(leaf_path),str(key_path))
            python_context.set_alpn_protocols(['h2'])
            def peer_work():
                with python_context.wrap_socket(peer,server_side=True) as secured:
                    assert secured.selected_alpn_protocol()=='h2'
                    assert secured.recv(4096)==payload
                    secured.sendall(payload)
            thread=launch(peer_work)
        handle=owned('tls_socket.new',context,transport.fileno())
        if not native_server:
            assert call('tls_socket.set_hostname',handle,'example.test',True) is None
        operation(handle,transport,2 if native_server else 1,callbacks=native_callbacks)
        assert call('tls_socket.alpn_protocol',handle)==b'h2'
        if native_server:
            assert operation(handle,transport,3,4096,native_callbacks)==payload
            assert operation(handle,transport,4,payload,native_callbacks)==len(payload)
        else:
            assert operation(handle,transport,4,payload,native_callbacks)==len(payload)
            assert operation(handle,transport,3,4096,native_callbacks)==payload
            session=owned('tls_socket.session',handle)
            copy=owned('tls_session.new',call('tls_session.to_der',session))
            assert call('tls_session.equal',session,copy) is True
            assert call('tls_socket.verify_result',handle)==0
        thread.join(10)
        assert not thread.is_alive(),'independent TLS peer stalled'
        assert not peer_errors,peer_errors
        transport.close()
    assert {1,2,4,16}.issubset(observed),observed
    # A Python peer presents a valid trusted chain for another hostname.
    transport,peer=socket.socketpair()
    peer.settimeout(10)
    python_context=ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    python_context.load_cert_chain(str(leaf_path),str(key_path))
    def rejected_peer():
        try:
            with python_context.wrap_socket(peer,server_side=True):
                raise AssertionError('wrong-hostname client completed a handshake')
        except ssl.SSLError:
            pass
    thread=launch(rejected_peer)
    context=owned('tls_context.new')
    assert call('tls_context.set_cert_store',context,store) is None
    assert call('tls_context.set_verify_mode',context,1) is None
    handle=owned('tls_socket.new',context,transport.fileno())
    assert call('tls_socket.set_hostname',handle,'wrong.example',True) is None
    error=operation(handle,transport,1,allow_error=True)
    assert error[0]=='error' and b'certificate verify failed' in error[2],error
    assert call('tls_socket.verify_result',handle)!=0
    thread.join(10)
    assert not thread.is_alive() and not peer_errors,peer_errors
    transport.close()


if __name__ == '__main__':
    main()
