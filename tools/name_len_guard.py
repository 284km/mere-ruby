#!/usr/bin/env python3
"""Put a length test in front of every `str_eq name "..."`.

Dispatch in this interpreter is a chain of string comparisons: reaching
`Hash#[]` walks 254 of them, and a profile of a pure `h[k]` loop spends 69%
of its samples in memcmp/strcmp. `str_len` is a single load (the length lives
in a header word before the bytes), so `str_len name == N` rejects a literal
of a different length without touching memory the string occupies.

The guard is a NECESSARY condition derived from the literal itself, so it can
only skip comparisons that would have answered false. Idempotent: a site that
already carries its guard is left alone.
"""
import re, sys, pathlib

SITE = re.compile(r'str_eq name "([^"\\{}]*)"')
GUARDED = re.compile(r'\(str_len name == \d+ && str_eq name "([^"\\{}]*)"\)')

def rewrite(text):
    already = len(GUARDED.findall(text))
    n = 0
    def sub(m):
        nonlocal n
        lit = m.group(1)
        if any(ord(c) > 127 for c in lit) or lit == '':
            return m.group(0)
        n += 1
        return f'(str_len name == {len(lit)} && str_eq name "{lit}")'
    # Idempotence: park the already-guarded sites before touching anything, so
    # the plain-site pattern cannot see them and wrap a guard in a guard.
    holes = []
    def stash(m):
        holes.append(m.group(0)); return f'\x00{len(holes)-1}\x00'
    text = GUARDED.sub(stash, text)
    text = SITE.sub(sub, text)
    text = re.sub(r'\x00(\d+)\x00', lambda m: holes[int(m.group(1))], text)
    return text, n, already

if __name__ == '__main__':
    check = '--check' in sys.argv
    total = 0
    for p in sorted(pathlib.Path('.').glob('*.mere')):
        src = p.read_text(encoding='utf-8')
        out, n, already = rewrite(src)
        if n:
            print(f'{p}: {n} newly guarded, {already} already')
            total += n
            if not check:
                p.write_text(out, encoding='utf-8')
    # Every guard must agree with its own literal.
    bad = 0
    for p in sorted(pathlib.Path('.').glob('*.mere')):
        for m in re.finditer(r'str_len name == (\d+) && str_eq name "([^"]*)"',
                             p.read_text(encoding='utf-8')):
            if int(m.group(1)) != len(m.group(2).encode()):
                print(f'MISMATCH {p}: {m.group(0)}'); bad += 1
    print(f'total {total} rewritten, {bad} mismatched')
    sys.exit(1 if bad else 0)
