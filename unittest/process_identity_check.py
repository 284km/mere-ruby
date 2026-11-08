#!/usr/bin/env python3
"""Check libc identity reads and unsigned IDs without changing privileges."""
import ctypes
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent

with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)

    def load(source, name):
        library = directory / (name + '.so')
        subprocess.run([os.environ.get('CC', 'clang'), '-shared', '-fPIC',
                        '-Wall', '-Wextra', '-Werror', str(source),
                        '-o', str(library)], check=True, timeout=30)
        lib = ctypes.CDLL(str(library))
        lib.mr_process_id.argtypes = [ctypes.c_int]
        lib.mr_process_id.restype = ctypes.c_char_p
        return lib

    lib = load(ROOT / 'tools/process_glue.c', 'actual')
    for kind, getter in enumerate([os.getuid, os.getgid, os.geteuid, os.getegid]):
        assert int(lib.mr_process_id(kind)) == getter()
    assert lib.mr_process_id(-1) == b''
    assert lib.mr_process_id(4) == b''

    # Rename libc calls within this translation unit, so the large values
    # exercise the bridge without setuid/setgid or symbol interposition.
    source = directory / 'large.c'
    source.write_text('''#include <unistd.h>
static uid_t fixture_uid;
static gid_t fixture_gid;
static uid_t fixture_getuid(void) { return fixture_uid; }
static gid_t fixture_getgid(void) { return fixture_gid; }
#define getuid fixture_getuid
#define geteuid fixture_getuid
#define getgid fixture_getgid
#define getegid fixture_getgid
''' + '#include "' + str(ROOT / 'tools/process_glue.c') + '"\n' + '''
void fixture_set(unsigned int value) {
    fixture_uid = (uid_t)value;
    fixture_gid = (gid_t)value;
}
''')
    lib = load(source, 'large')
    lib.fixture_set.argtypes = [ctypes.c_uint]
    lib.fixture_set.restype = None
    for value in [0, 1, 2147483647, 2147483648, 4294967294, 4294967295, 42]:
        lib.fixture_set(value)
        for kind in range(4):
            assert lib.mr_process_id(kind) == str(value).encode(), (kind, value)

print('process identity bridge: actual, unsigned, and repeated reads passed')
