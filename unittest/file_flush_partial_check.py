#!/usr/bin/env python3
"""Compare a short write followed by ENOSPC and a retry with clean CRuby."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PROGRAM = r'''
path = ARGV.fetch(0)
control = ARGV.fetch(1)
File.binwrite(control, '0')
['r+', 'w+'].each do |mode|
  File.binwrite(path, 'abcdefghijkl')
  File.open(path, mode) do |file|
    File.binwrite(path, 'abcdefghijkl') if mode == 'w+'
    file.seek(2)
    file.write('123456789')
    File.binwrite(control, '1')
    begin
      file.flush
      puts :unexpected_success
    rescue Errno::ENOSPC
      puts :partial_then_full
    ensure
      File.binwrite(control, '0')
    end
    p File.binread(path)
    file.flush
    p [file.pos, File.binread(path)]
  end
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mere', default=str(ROOT / 'mere-ruby'))
    args = parser.parse_args()
    if sys.platform not in ('darwin', 'linux'):
        raise SystemExit('requires native Darwin or Linux write interposition')
    ref = subprocess.check_output(
        ['sh', '-c', '. "$1"; printf "%s" "$REF_RUBY_BIN"', 'sh',
         str(ROOT / 'tools/ref_ruby.sh')], text=True)
    with tempfile.TemporaryDirectory(prefix='mere-file-flush-partial-') as directory:
        temporary = Path(directory).resolve()
        library = temporary / ('fault.dylib' if sys.platform == 'darwin' else 'fault.so')
        command = [os.environ.get('CC', 'clang'), '-Wall', '-Wextra', '-Werror',
                   '-dynamiclib' if sys.platform == 'darwin' else '-shared', '-fPIC',
                   str(ROOT / 'unittest/repro/file_flush_partial.c'), '-o', str(library)]
        if sys.platform == 'linux':
            command.append('-ldl')
        subprocess.run(command, check=True)
        program = temporary / 'probe.rb'
        program.write_text(PROGRAM)
        observed = {}
        for side, binary in [('reference', ref), ('evaluator', args.mere), ('vm', args.mere)]:
            environment = os.environ.copy()
            environment.pop('MERE_RUBY_VM', None)
            environment['DYLD_INSERT_LIBRARIES' if sys.platform == 'darwin' else 'LD_PRELOAD'] = str(library)
            environment['MR_FLUSH_PARTIAL_TARGET'] = str(temporary / 'data')
            environment['MR_FLUSH_PARTIAL_CONTROL'] = str(temporary / 'control')
            if side == 'vm':
                environment['MERE_RUBY_VM'] = '1'
            process = subprocess.run([binary, str(program), str(temporary / 'data'), str(temporary / 'control')],
                                     env=environment, capture_output=True, timeout=60)
            if process.returncode:
                raise RuntimeError(f'{side}: exit {process.returncode}: {process.stderr.decode()}')
            observed[side] = process.stdout
        if observed['reference'].count(b'partial_then_full\n') != 2:
            raise RuntimeError(f'write fault did not reach the reference: {observed["reference"]!r}')
        for side in ('evaluator', 'vm'):
            if observed[side] != observed['reference']:
                raise AssertionError(f'{side}: {observed[side]!r}\nreference: {observed["reference"]!r}')
        print('partial write, ENOSPC, buffered retry: evaluator and VM match clean Ruby')


if __name__ == '__main__':
    main()
