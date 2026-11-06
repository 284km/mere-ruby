#!/usr/bin/env python3
"""Bound the timeout regression itself, including inherited blocking pipes."""
import argparse
import os
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parent.parent
INHERITED = '''require "io/nonblock"
r = IO.new(ARGV.fetch(0).to_i)
begin
  p r.nonblock?
  r.timeout = 0.002
  begin
    r.read(1)
    p :unexpected_success
  rescue IO::TimeoutError => error
    p [error.class, error.message]
  end
  p r.nonblock?
ensure
  r.close
end
'''


def run(binary, arguments, **options):
    return subprocess.run([binary, *arguments], check=True, capture_output=True,
                          text=True, timeout=15, **options).stdout


def inherited_pipe(binary):
    reader, writer = os.pipe()
    try:
        # Keep the peer open without sending data. The child must time out;
        # EOF would make this pass even if the deadline were ignored.
        return run(binary, ['-e', INHERITED, str(reader)], pass_fds=(reader,))
    finally:
        os.close(reader)
        os.close(writer)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
    parser.add_argument('--reference', default=os.environ.get('REF_RUBY_BIN', 'ruby'))
    args = parser.parse_args()
    reference = shutil.which(args.reference)
    if not reference:
        parser.error('reference Ruby was not found')
    candidate = str(args.binary.resolve())
    corpus = str(ROOT / 'corpus/496_io_read_timeout.rb')
    expected = run(reference, [corpus])
    for mode in ('on', 'off'):
        env = os.environ.copy()
        env.pop('MERE_RUBY_NO_HASH_INDEX', None)
        if mode == 'off':
            env['MERE_RUBY_NO_HASH_INDEX'] = '1'
        actual = run(candidate, [corpus], env=env)
        assert actual == expected, f'timeout corpus differs with hash index {mode}'
        print(f'timeout corpus: matches reference, hash index {mode}', flush=True)
    expected = inherited_pipe(reference)
    assert inherited_pipe(candidate) == expected, 'inherited blocking pipe differs'
    assert 'IO::TimeoutError' in expected and expected.count('false') == 2
    print('inherited blocking pipe: timeout raised; descriptor mode preserved')


if __name__ == '__main__':
    main()
