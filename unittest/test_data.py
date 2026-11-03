#!/usr/bin/env python3
"""Prepare verified Unicode data and the RubyGems executable fixture."""
import argparse
import hashlib
import json
import re
import urllib.request
from pathlib import Path

MANIFEST = json.loads(Path(__file__).with_suffix('.json').read_text())
VERSION = MANIFEST['unicode_version']
EMOJI_VERSION = MANIFEST['emoji_version']
FILES = MANIFEST['files']


def check_version(source):
    common = (source / 'common.mk').read_text()
    version = re.search(r'^UNICODE_VERSION\s*=\s*(\S+)', common, re.MULTILINE)
    if not version or version[1] != VERSION:
        raise ValueError('Ruby source Unicode version differs from the pinned test data')


def check_bytes(content, entry):
    if len(content) != entry['bytes'] or hashlib.sha256(content).hexdigest() != entry['sha256']:
        raise ValueError('Unicode test data differs from the pinned checksum/size: ' + entry['path'])


def verify(source):
    source = Path(source)
    check_version(source)
    for entry in FILES:
        with (source / entry['path']).open('rb') as stream:
            check_bytes(stream.read(entry['bytes'] + 1), entry)
    # Ruby's vendored Cargo tests retain RubyGems' upstream exe/gem path,
    # while the pinned Ruby tree stores that same entry point in bin/gem.
    original = (source / 'bin/gem').read_bytes()
    if (source / 'exe/gem').read_bytes() != original:
        raise ValueError('RubyGems executable fixture differs from bin/gem')
    return dict(policy=MANIFEST['policy'], unicode_version=VERSION, emoji_version=EMOJI_VERSION, files=FILES,
                rubygems_executable=dict(path='exe/gem', source='bin/gem',
                                         sha256=hashlib.sha256(original).hexdigest()))


def prepare(source):
    source = Path(source)
    check_version(source)
    for entry in FILES:
        target = source / entry['path']
        if target.exists():
            with target.open('rb') as stream:
                check_bytes(stream.read(entry['bytes'] + 1), entry)
            continue
        with urllib.request.urlopen(entry['url'], timeout=30) as response:
            data = response.read(entry['bytes'] + 1)
        check_bytes(data, entry)
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
