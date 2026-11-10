#!/usr/bin/env python3
"""Generate the portable OID name registry from an explicitly selected libcrypto."""
import argparse
import ctypes
import json

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--library', required=True)
a = p.parse_args()
lib = ctypes.CDLL(a.library)
lib.OpenSSL_version.argtypes = [ctypes.c_int]
lib.OpenSSL_version.restype = ctypes.c_char_p
for name in ('OBJ_nid2sn', 'OBJ_nid2ln'):
    f = getattr(lib, name)
    f.argtypes = [ctypes.c_int]
    f.restype = ctypes.c_char_p
lib.OBJ_nid2obj.argtypes = [ctypes.c_int]
lib.OBJ_nid2obj.restype = ctypes.c_void_p
lib.OBJ_obj2txt.argtypes = [ctypes.c_char_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_int]
lib.OBJ_obj2txt.restype = ctypes.c_int
print('# Generated OID facts by tools/gen_openssl_oids.py; ' + lib.OpenSSL_version(0).decode())
print('module OpenSSL\n  module ASN1\n    OID_NAMES = {')
seen = set()
for nid in range(1, 10000):
    sn, ln = lib.OBJ_nid2sn(nid), lib.OBJ_nid2ln(nid)
    if not sn or not ln:
        continue
    obj = lib.OBJ_nid2obj(nid)
    if not obj:
        continue
    buf = ctypes.create_string_buffer(4096)
    size = lib.OBJ_obj2txt(buf, len(buf), obj, 1)
    oid = buf.value.decode()
    if size <= 0 or not oid or not oid[0].isdigit():
        continue
    if oid in seen:
        continue
    seen.add(oid)
    values = [json.dumps(x, ensure_ascii=False) for x in (oid, sn.decode(), ln.decode())]
    print('      ' + values[0] + ' => [' + ', '.join(values[1:]) + '],')
print('    }\n  end\nend')
