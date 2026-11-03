#!/usr/bin/env python3
"""Prepare verified Unicode data and the RubyGems executable fixture."""
import argparse
import hashlib
import re
import urllib.request
from pathlib import Path

VERSION = '17.0.0'
RELATIVE = f'enc/unicode/data/{VERSION}/ucd/CaseFolding.txt'
URL = f'https://www.unicode.org/Public/{VERSION}/ucd/CaseFolding.txt'
SHA256 = 'ff8d8fefbf123574205085d6714c36149eb946d717a0c585c27f0f4ef58c4183'
MAX_BYTES = 1024 * 1024


def verify(source):
    source = Path(source)
    with (Path(source) / RELATIVE).open('rb') as stream:
        data = stream.read(MAX_BYTES + 1)
    if len(data) > MAX_BYTES or hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError('CaseFolding data does not match the pinned checksum')
    # Ruby's vendored Cargo tests retain RubyGems' upstream exe/gem path,
    # while the pinned Ruby tree stores that same entry point in bin/gem.
    original = (source / 'bin/gem').read_bytes()
    if (source / 'exe/gem').read_bytes() != original:
        raise ValueError('RubyGems executable fixture differs from bin/gem')
    return dict(unicode_version=VERSION, path=RELATIVE, url=URL, sha256=SHA256,
                rubygems_executable=dict(path='exe/gem', source='bin/gem',
                                         sha256=hashlib.sha256(original).hexdigest()))


def prepare(source):
    source = Path(source)
    common = (source / 'common.mk').read_text()
    version = re.search(r'^UNICODE_VERSION\s*=\s*(\S+)', common, re.MULTILINE)
    if not version or version[1] != VERSION:
        raise ValueError('Ruby source Unicode version differs from the pinned test data')
    target = source / RELATIVE
    if not target.exists():
        with urllib.request.urlopen(URL, timeout=30) as response:
            data = response.read(MAX_BYTES + 1)
        if len(data) > MAX_BYTES or hashlib.sha256(data).hexdigest() != SHA256:
            raise ValueError('Downloaded CaseFolding data does not match the pinned checksum')
        target.parent.mkdir(parents=True, exist_ok=True)
        pending = target.with_suffix('.txt.new')
        pending.write_bytes(data)
        pending.replace(target)
    executable = source / 'exe/gem'
    if not executable.exists():
        executable.parent.mkdir(parents=True, exist_ok=True)
        executable.write_bytes((source / 'bin/gem').read_bytes())
    return verify(source)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    print(prepare(args.source))
