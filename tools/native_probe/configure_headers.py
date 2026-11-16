#!/usr/bin/env python3
"""Generate target-specific probe headers without linking or executing target code."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile


TYPES = {'CHAR': 'char', 'SHORT': 'short', 'INT': 'int', 'LONG': 'long',
         'LONG_LONG': 'long long', 'FLOAT': 'float', 'DOUBLE': 'double',
         'VOIDP': 'void*', 'VALUE': 'VALUE'}


def configure(output, settings):
    source = Path(__file__).resolve().parent / 'include'
    output = output.resolve()
    if output.exists():
        raise ValueError('output already exists; use a fresh target directory')
    output.parent.mkdir(parents=True, exist_ok=True)
    command = shlex.split(settings['CC'])
    if not command:
        raise ValueError('CC must not be empty')
    flags = ['-DPROBE_TYPED_API'] + shlex.split(settings['CPPFLAGS']) + shlex.split(settings['CFLAGS'])
    version = subprocess.check_output(command + ['--version'], text=True, timeout=20)
    with tempfile.TemporaryDirectory(prefix='.native-config-', dir=output.parent) as tmp:
        stage = Path(tmp)
        headers = stage / 'include'
        shutil.copytree(source, headers)
        attempts = []

        def compile(body):
            cmd = command + flags + ['-I', str(headers), '-x', 'c', '-c',
                                     '-o', str(stage / 'probe.o'), '-']
            result = subprocess.run(cmd, input='#include "ruby.h"\n' + body,
                                    text=True, capture_output=True, timeout=20)
            attempts.append(dict(body=body, exit=result.returncode, stderr=result.stderr))
            return result.returncode == 0

        if not compile('int mere_config_probe;\n'):
            raise RuntimeError('compiler cannot compile the probe API headers: ' + attempts[-1]['stderr'])
        if compile('typedef char must_fail[-1];\n'):
            raise RuntimeError('compiler accepted an invalid translation unit')
        sizes = {}
        for name, type_name in TYPES.items():
            for size in range(1, 33):
                if compile(f'typedef char size_check[(sizeof({type_name}) == {size}) ? 1 : -1];\n'):
                    sizes[name] = size
                    break
            else:
                raise RuntimeError(f'cannot determine sizeof({type_name}) in range 1..32')
        size_header = headers / 'ruby/target_sizes.h'
        size_header.write_text('#ifndef MERE_PROBE_TARGET_SIZES_H\n'
                              '#define MERE_PROBE_TARGET_SIZES_H\n#include <limits.h>\n'
                              '#define LONG_LONG long long\n' +
                              ''.join(f'#define SIZEOF_{k} {v}\n' for k, v in sizes.items()) +
                              '#endif\n')
        # Every extension verifies the configured layout against its actual flags.
        ruby_h = headers / 'ruby.h'
        body, end = ruby_h.read_text().rsplit('#endif', 1)
        body += '#include "ruby/target_sizes.h"\n'
        body += ''.join(f'typedef char mere_size_{k}[(SIZEOF_{k} == sizeof({v})) ? 1 : -1];\n'
                        for k, v in TYPES.items())
        ruby_h.write_text(body + '#endif' + end)
        if not compile('typedef char char_bit_check[(CHAR_BIT > 0) ? 1 : -1];\n'):
            raise RuntimeError('generated header validation failed: ' + attempts[-1]['stderr'])
        (stage / 'probe.o').unlink()
        manifest = dict(schema=1, settings=settings, sizes=sizes, compiler_version=version,
                        source_headers={str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest()
                                        for p in sorted(source.rglob('*')) if p.is_file()},
                        generated_headers={str(p.relative_to(headers)): hashlib.sha256(p.read_bytes()).hexdigest()
                                           for p in sorted(headers.rglob('*')) if p.is_file()})
        (stage / 'config.json').write_text(json.dumps(manifest, indent=2) + '\n')
        (stage / 'probes.json').write_text(json.dumps(attempts, indent=2) + '\n')
        # Publish only a complete, verified configuration; never overwrite a target.
        stage.rename(output)
    return sizes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    for name, default in [('cc', 'cc'), ('cxx', 'c++'), ('cflags', '-O2'),
                          ('cxxflags', '-O2'), ('cppflags', ''), ('ldflags', '')]:
        parser.add_argument('--' + name, default=os.environ.get(name.upper(), default))
    opts = parser.parse_args()
    settings = {name.upper(): getattr(opts, name)
                for name in ['cc', 'cxx', 'cflags', 'cxxflags', 'cppflags', 'ldflags']}
    try:
        sizes = configure(opts.output, settings)
    except (ValueError, RuntimeError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'configuration failed: {error}\n')
    print(json.dumps(sizes, sort_keys=True))


if __name__ == '__main__':
    main()
