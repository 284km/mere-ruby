#!/usr/bin/env python3
"""Cross-load native and Mere YAML for scalar whitespace, styles and encodings."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
PROGRAM = r'''
require 'psych'
require 'stringio'
mode, folder = ARGV
values = ['', ' ', "\n", "\n\n", "x\n", "x\n\n", "\nx", "\n x",
          " x\ny", "  x\n  y\n", "x\n y", "x \ny", "x\n\ny", "\tindented",
          '"', "'", '#: ', ':leading', '&tag', '*alias', "a\0b", "雪☃", "雪\n ☃\n",
          "yes", "090", ":symbol", "line\n", "trailing \n", "first\n\nlast\n"]
values.each_with_index do |expected, n|
  path = folder + '/' + n.to_s + '.yaml'
  if mode == 'write'
    File.binwrite(path, Psych.dump(expected))
  else
    actual = File.open(path, 'rb') { |io| Psych.safe_load(io) }
    raise "scalar #{n}: #{expected.inspect} became #{actual.inspect}" unless actual == expected
  end
  (1..5).each do |style|
    style_path = path + style.to_s
    if mode == 'write'
      io = StringIO.new
      emitter = Psych::Emitter.new(io)
      emitter.start_stream(Psych::Parser::UTF8)
      emitter.start_document([], [], false)
      emitter.scalar(expected, nil, nil, false, true, style)
      emitter.end_document(true)
      emitter.end_stream
      File.binwrite(style_path, io.string)
    else
      begin
        actual = File.open(style_path, 'rb') { |io| Psych.safe_load(io) }
      rescue Psych::SyntaxError => error
        raise "scalar #{n}, style #{style} invalid wire: #{File.binread(style_path).inspect}: #{error.message}"
      end
      raise "scalar #{n}, style #{style}: #{expected.inspect} became #{actual.inspect}" unless actual == expected
    end
  end
end
[Psych::Parser::UTF8, Psych::Parser::UTF16LE, Psych::Parser::UTF16BE].each do |encoding|
  path = folder + '/encoding-' + encoding.to_s + '.yaml'
  if mode == 'write'
    io = StringIO.new
    emitter = Psych::Emitter.new(io)
    emitter.start_stream(encoding)
    emitter.start_document([], [], true)
    emitter.scalar('雪☃', nil, nil, false, true, 3)
    emitter.end_document(true)
    emitter.end_stream
    File.binwrite(path, io.string)
    bom = encoding == 2 ? [255, 254] : [254, 255]
    raise 'UTF-16 stream omitted BOM' if encoding != 1 && io.string.byteslice(0, 2).bytes != bom
  else
    actual = File.open(path, 'rb') { |io| Psych.safe_load(io) }
    raise 'UTF-16 wire changed data' unless actual == '雪☃'
  end
end
puts values.length
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(ROOT / 'mere-ruby')))
    args = parser.parse_args()
    reference = subprocess.check_output(['sh', '-c', '. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"', 'sh', str(ROOT)], text=True)
    with tempfile.TemporaryDirectory(prefix='psych-scalar-wire-') as tmp:
        folder = Path(tmp)
        script = folder / 'wire.rb'
        script.write_text(PROGRAM)
        for producer, consumer in [(reference, args.binary), (args.binary, reference)]:
            for mode, binary in [('write', producer), ('read', consumer)]:
                result = subprocess.run([binary, str(script), mode, str(folder)], capture_output=True, timeout=30)
                assert result.returncode == 0, result.stderr.decode(errors='replace')
    print('Psych scalar wire: 29 values, five explicit styles and UTF-8/16 streams cross-load in both directions')


if __name__ == '__main__':
    main()
