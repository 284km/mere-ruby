#!/usr/bin/env python3
"""Exercise the copied-byte provider ABI independently of the Ruby frontend."""
import argparse
import ctypes
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile

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
    if kind in (b's', b'i'):
        value = source[position:position+size]
        return (int(value) if kind == b'i' else value), position + size
    assert kind == b'a', kind
    values = []
    for _ in range(size):
        value, position = unpack(source, position)
        values.append(value)
    return values, position


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
                        str(ROOT/'tools/openssl_glue.c'), *flags, '-lssl', '-lcrypto', '-o', str(library)], check=True)
        lib = ctypes.CDLL(str(library))
        lib.mr_ossl_call.argtypes = [ctypes.c_char_p, ctypes.c_void_p]
        lib.mr_ossl_call.restype = ctypes.c_void_p

        def raw(op, wire, declared_size=None):
            request = ctypes.create_string_buffer(struct.pack('q', len(wire) if declared_size is None else declared_size) + wire)
            result = lib.mr_ossl_call(op.encode(), request)
            length, = struct.unpack('q', ctypes.string_at(result, 8))
            response = ctypes.string_at(result + 8, length)
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
        assert call('errors') == []
        print('OpenSSL provider ABI: bounded decoding, BN arithmetic, random and errors pass')


if __name__ == '__main__':
    main()
