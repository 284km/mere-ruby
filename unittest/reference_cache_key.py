#!/usr/bin/env python3
"""Identify the exact reference build independently of CI scheduling changes."""
import hashlib
import json
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
DEFINITIONS = ('unittest/build_reference.sh', 'unittest/package_reference.sh',
               'unittest/test_data.py', 'unittest/test_data.json', 'unittest/reference_cache_key.py')


def cache_key(root, inputs, native):
    value = dict(inputs=inputs, native=native,
                 definitions={name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                              for name in DEFINITIONS})
    digest = hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
    return 'reference-ruby-v2-' + digest


def main():
    inputs = {name: os.environ[name] for name in
              ('RUBY_SOURCE_REF', 'REF_RUBY_VERSION', 'RUST_VERSION', 'RUNNER_OS', 'RUNNER_ARCH')}
    native = {name: os.environ.get(name, '') for name in
              ('ImageOS', 'ImageVersion', 'CC', 'CFLAGS', 'CPPFLAGS', 'LDFLAGS', 'RUSTFLAGS',
               'SDKROOT', 'MACOSX_DEPLOYMENT_TARGET')}
    for name, command in (
            ('clang', ['clang', '--version']),
            ('sdk', ['xcrun', '--show-sdk-version']),
            ('openssl_prefix', ['brew', '--prefix', 'openssl@3']),
            ('libyaml_prefix', ['brew', '--prefix', 'libyaml']),
            ('dependencies', ['brew', 'list', '--versions', 'autoconf', 'automake', 'libtool',
                              'pkgconf', 'openssl@3', 'libyaml'])):
        native[name] = subprocess.check_output(command, text=True).strip()
    print(cache_key(ROOT, inputs, native))


if __name__ == '__main__':
    main()
