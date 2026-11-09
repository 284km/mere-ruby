#!/usr/bin/env python3
"""Compare parser events with the pinned native parser, independently of loaders."""
import argparse
import difflib
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
VALID = [
    '', '# comment\n', '---', '---\n...\n', 'null', '--- foo\n',
    'a: b\nc: d\n', '- one\n- two\n',
    'a:\n  b: [one, two]\n  c: {x: y}\n',
    '- a: b\n  c: d\n- e\n', 'a:\n- one\n- two\nb: end\n',
    '[one, {two: [three, four]}, five,]\n',
    "['one''two', \"a\\n\\u3042\\U0001F600\", plain]\n",
    '--- &root\n- &child [one]\n- *child\n- *root\n',
    '--- !!map\na: !!str 1\nb: !custom value\n',
    '%YAML 1.1\n%TAG !e! tag:example.com,2026:\n--- !e!thing [a, b]\n...\n',
    '%TAG ! tag:example.com,2026:\n--- !thing value\n',
    'a: |\n  first\n  second\nb: >-\n  first\n  second\n',
    '--- one\n--- two\n...\n---\n- three\n',
    'a: # empty\nb:\nc: []\nd: {}\n',
    '日本語: "値"\n',
    'a: &empty\nb: *empty\n', '- &empty\n- *empty\n',
    '&name key: value\n*name : other\n',
    '? [one, two]\n: three\n',
    '[one, two: three, four]\n',
    '---\na:\n  b: c\n---\none\ntwo\n',
    'one\ntwo\n\nthree\n',
]
INVALID = ['[', '{a: b', '--- `', '"unterminated', '"\\q"',
           '---\n"a"\n"b"\n', '%YAML 9.9\n--- a\n', '!missing!tag value', ': empty key\n',
           '\0', '\tbad', 'a:\n \tbad']
PROBE = r'''
require 'psych'
require 'stringio'
class Capture < Psych::Handler
  attr_reader :events
  def initialize; @events = []; end
  def event_location(*args); @location = args; end
  Psych::Handler::EVENTS.each do |name|
    define_method(name) { |*args| @events << [name, args, @location] }
  end
end
handler = Capture.new
parser = Psych::Parser.new(handler)
ARGV.each do |path|
  handler.events.clear
  begin
    parser.parse(File.read(path), path)
    p [:ok, handler.events]
  rescue Psych::SyntaxError
    p [:syntax_error]
  end
end
['UTF-8', 'UTF-16LE', 'UTF-16BE', 'Shift_JIS'].each do |encoding|
  handler.events.clear
  parser.parse('--- 雪'.encode(encoding))
  p [encoding, handler.events]
end
['UTF-8', 'UTF-16LE', 'UTF-16BE'].each do |encoding|
  [false, true].each do |io|
    handler.events.clear
    source = "\uFEFF--- 雪".encode(encoding)
    parser.parse(io ? StringIO.new(source) : source)
    p [:bom, encoding, io, handler.events]
  end
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(ROOT / 'mere-ruby')))
    parser.add_argument('--preload', help='optional parser source override')
    parser.add_argument('--reference', default=os.environ.get('REF_RUBY_BIN'))
    args = parser.parse_args()
    if not args.reference:
        args.reference = subprocess.check_output(
            ['sh', '-c', '. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"', 'sh', str(ROOT)], text=True)
    with tempfile.TemporaryDirectory(prefix='psych-events-') as folder:
        folder = Path(folder)
        probe = folder / 'probe.rb'
        probe.write_text(PROBE)
        paths = []
        for i, source in enumerate(VALID + INVALID):
            path = folder / f'{i}.yaml'
            path.write_text(source)
            paths.append(str(path))
        reference = subprocess.run([args.reference, str(probe), *paths], capture_output=True, timeout=30, check=True)
        command = [args.binary]
        if args.preload:
            command += ['-r', args.preload]
        actual = subprocess.run(command + [str(probe), *paths], capture_output=True, timeout=30)
        assert actual.returncode == 0, actual.stderr.decode(errors='replace')
        if reference.stdout != actual.stdout:
            diff = ''.join(difflib.unified_diff(reference.stdout.decode().splitlines(True), actual.stdout.decode().splitlines(True), fromfile='Ruby', tofile='Mere'))
            raise AssertionError(diff)
    print(f'Psych parser: {len(VALID)} valid, {len(INVALID)} malformed plus encoding/BOM cases match native events/locations')


if __name__ == '__main__':
    main()
