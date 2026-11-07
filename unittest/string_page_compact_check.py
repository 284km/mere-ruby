#!/usr/bin/env python3
"""Exercise the production compaction decision against the pinned Vec runtime."""
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
compiler = os.environ.get('MERE', str(ROOT / '.mere-compiler/_build/default/bin/mere.exe'))
state = (ROOT / 'm_state.mere').read_text()
# Compile the actual production helper, rather than duplicating its decision
# in a C model. The controlled pin exercises both native early-return paths.
helper = re.search(r'let str_pg_try_compact = fn pg ->.*?;', state, re.S)
assert helper, 'production compaction helper not found'
program = '''
extern fn test_set_pin: int -> int;
let pg = vec_new ();
let _ = vec_push pg "kept";
let _ = vec_compact pg;
let _ = vec_set pg 0 (str_repeat "x" 8388608);
let _ = vec_set pg 0 "kept";
let before = vec_bytes pg;
let _ = print_bool (before > 8388608);
let _ = test_set_pin 1;
// First establish the native baseline; then defer for below-threshold growth.
let _ = print_bool (not (str_pg_try_compact pg));
let _ = print_bool (not (str_pg_try_compact pg));
let _ = print_bool (vec_bytes pg == before);
let _ = print_bool (vec_get pg 0 == "kept");
let _ = test_set_pin 0;
// No intervening page mutation: the pending work must reclaim old storage.
let _ = print_bool (str_pg_try_compact pg);
let _ = print_bool (vec_bytes pg == 4096);
let _ = print_bool (vec_get pg 0 == "kept");
// Equal-capacity copies cannot be distinguished from deferrals; retry safely.
let _ = print_bool (not (str_pg_try_compact pg));
let _ = print_bool (vec_get pg 0 == "kept");
'''
native = '''
static int test_forced_pin(__lang_region *region, int growth) {
    (void)region; (void)growth;
    return 1;
}
int test_set_pin(int enabled) {
    __lang_region_pinned = enabled ? test_forced_pin : 0;
    return 0;
}
'''
with tempfile.TemporaryDirectory(prefix='mere-string-page-') as directory:
    path = Path(directory)
    source = path / 'check.mere'
    source.write_text(helper[0] + '\n' + program)
    emitted = subprocess.run([compiler, '-c', str(source)], capture_output=True,
                             check=True, timeout=60).stdout
    cfile = path / 'check.c'
    cfile.write_bytes(emitted + native.encode())
    binary = path / 'check'
    subprocess.run(['clang', '-O2', '-w', '-fbracket-depth=1024', str(cfile),
                    '-lm', '-o', str(binary)], check=True, timeout=60)
    result = subprocess.run([str(binary)], capture_output=True, check=True, timeout=20)
    assert result.stdout == b'true\n' * 10, result.stdout
print('String page compaction: deferred pins retry and reclaim without another write')
