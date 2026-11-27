#!/usr/bin/env python3
"""A StrBuf is made inside a region block, or it is the default region's.

`strbuf_new ()` takes its region from its type, and a StrBuf made outside every
`region NAME { ... }` gets the default one. Mere never gives the default region
back: a StrBuf's buffer grows to the size of what it builds, and every call left
one that size behind for the rest of the run. Array#join, Random#bytes, sub and
gsub, tr, delete, squeeze, inspect, reverse and JSON.generate each kept their
result's size, every call, after the collector had let the result go (a gsub
of 1 MB, ten times, kept 10 MB). So each one is in a region of its own, which
hands out only the text, and this finds a new one that is not:

    ./tools/strbuf_region_check.py

It reads the source, skipping comments and string literals, and keeps a stack of
the `region NAME {` blocks open at each point. A `strbuf_new` with none open is
reported, unless its function is in ALLOWED below with the reason it may stay.
A program's StrBuf made at the top level (once, for the whole run) is allowed
by the same list.

It reads the spelling, not the meaning: a function that is CALLED from inside a
region block, and makes its StrBuf there, is in that region at run time and is
still reported here. Such a function goes in ALLOWED, with the caller named.
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

# (file, enclosing top-level definition) -> why its StrBuf may be the default
# region's. Each was looked at for this check: what it builds is small and
# bounded (a name, a number's digits, a line of a message), or it runs once.
ALLOWED = {
}

DEF = re.compile(r"^(let|and)( rec)? ([a-z_][a-zA-Z0-9_']*)")
REGION = re.compile(r"region\s+[A-Z_][A-Z0-9_]*\s*\{")


def strip(line, in_str):
    """The line with comments and string contents blanked; whether a string
    is still open at its end (Mere's strings may run over lines)."""
    out = []
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if in_str:
            if c == "\\" and i + 1 < n:
                out.append("  ")
                i += 2
                continue
            if c == '"':
                in_str = False
                out.append('"')
            else:
                out.append(" ")
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append('"')
            i += 1
            continue
        if c == "/" and i + 1 < n and line[i + 1] == "/":
            break
        out.append(c)
        i += 1
    return "".join(out), in_str


def scan(path):
    rel = os.path.relpath(path, ROOT)
    bad = []
    stack = []
    func = "(top level)"
    in_str = False
    with open(path, encoding="utf-8") as fh:
        for no, raw in enumerate(fh, 1):
            m = DEF.match(raw)
            if m and not in_str:
                func = m.group(3)
            code, in_str = strip(raw.rstrip("\n"), in_str)
            # walk the line in order: region openers, other braces, closers,
            # and the StrBufs between them
            pos = 0
            while pos < len(code):
                rm = REGION.match(code, pos)
                if rm:
                    stack.append("region")
                    pos = rm.end()
                    continue
                if code.startswith("strbuf_new", pos) and (pos == 0 or not (code[pos - 1].isalnum() or code[pos - 1] == "_")):
                    if "region" not in stack and (rel, func) not in ALLOWED:
                        bad.append("%s:%d (%s)" % (rel, no, func))
                    pos += len("strbuf_new")
                    continue
                c = code[pos]
                if c == "{":
                    stack.append("other")
                elif c == "}":
                    if stack:
                        stack.pop()
                pos += 1
    return bad


def main():
    files = []
    for dirpath, dirnames, filenames in os.walk(ROOT):
        rel = os.path.relpath(dirpath, ROOT)
        if rel.startswith((".mere_modules", "vendor", ".git", ".mere-compiler", "mspec")) or "/." in "/" + rel and rel != ".":
            dirnames[:] = []
            continue
        for f in filenames:
            if f.endswith(".mere"):
                files.append(os.path.join(dirpath, f))
    bad = []
    for f in sorted(files):
        bad.extend(scan(f))
    if bad:
        print("strbuf region: a StrBuf is made outside every region block, so it is the default region's:")
        for b in bad:
            print("  " + b)
        print("Put it in a region of its own (`region NAME { let b = strbuf_new () in ...; strbuf_to_str b }`),"
              " or add its function to ALLOWED in tools/strbuf_region_check.py with the reason it may stay.")
        return 1
    print("strbuf region: every StrBuf is made inside a region block, or allowed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
