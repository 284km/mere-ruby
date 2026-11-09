#!/usr/bin/env python3
"""Differential Zlib stream protocols and independent malformed/wire checks."""
import argparse
import gzip
import os
from pathlib import Path
import random
import re
import subprocess
import tempfile
import zlib

ROOT = Path(__file__).resolve().parent.parent

PROTOCOLS = r'''
require 'zlib'
require 'stringio'
# These observations include bytes available before FINISH and lifecycle errors.
[-15, 15, 31, 47].each do |window|
  next if window == 47
  [0, 1, 6, 9].each do |level|
    d = Zlib::Deflate.new(level, window)
    i = Zlib::Inflate.new(window)
    input = ["ab\0cd" * 23, 'tail' * 17, "\xff".b * 19]
    out = +''.b
    [Zlib::SYNC_FLUSH, Zlib::FULL_FLUSH, Zlib::FINISH].each_with_index do |flush, n|
      compressed = d.deflate(input[n], flush)
      compressed.each_byte { |b| out << i.inflate(b.chr.b) }
      p [window, level, n, out.bytesize, out == input[0..n].join.b]
    end
    p [d.finished?, i.finished?, d.total_in, i.total_out]
    d.close
    i.close
    [:finish, :reset, :adler, :finished?].each do |method|
      begin; d.send(method); rescue => e; p [method, e.class]; end
    end
  end
end
# The text/binary classification becomes available when a block is emitted.
['plain text', "\x00\x01".b].each do |text|
  d = Zlib::Deflate.new
  p d.data_type
  d.deflate(text, Zlib::FINISH)
  p d.data_type
  d.close
end
# One-shot APIs reject nil and discard bytes after their compressed member.
encoded = Zlib.deflate('foo')
p Zlib.inflate(encoded + 'unused')
p Zlib::Inflate.inflate(encoded + 'unused')
[nil, true, 1].each do |value|
  [:deflate, :inflate].each do |method|
    begin; Zlib.send(method, value); rescue => e; p [method, e.class]; end
  end
end
# Recovery with/without a parsed header follows inflateSync's framing rule.
[false, true].each do |header_seen|
  d = Zlib::Deflate.new
  first = d.deflate('before', Zlib::FULL_FLUSH)
  last = d.deflate('after', Zlib::FINISH)
  i = Zlib::Inflate.new
  if header_seen
    i.inflate(first.byteslice(0, 2))
    bad = "\xff".b + first.byteslice(2, first.bytesize - 2) + last
  else
    bad = 'corrupt' + first + last
  end
  begin; i.inflate(bad); rescue Zlib::DataError; end
  p i.sync('')
  p i.inflate('') + i.finish
  i.close; d.close
end
# A copy branches independently and reset starts a new stream.
d = Zlib::Deflate.new
a = d.deflate('prefix')
e = d.dup
p Zlib.inflate(a + d.deflate('left', Zlib::FINISH))
p Zlib.inflate(a + e.deflate('right', Zlib::FINISH))
d.reset
p Zlib.inflate(d.deflate('reset', Zlib::FINISH))
d.close; e.close
# Dictionaries are tried by checksum; a wrong dictionary is an error.
d = Zlib::Deflate.new
d.set_dictionary('dictionary')
s = d.deflate('dictionary' * 100, Zlib::FINISH)
i = Zlib::Inflate.new
begin; i.inflate(s); rescue Zlib::NeedDict; p :need_dictionary; end
begin; i.set_dictionary('wrong'); rescue => ex; p ex.class; end
i.set_dictionary('dictionary')
p i.inflate('') == 'dictionary' * 100
i.close
i = Zlib::Inflate.new
i.add_dictionary('wrong'); i.add_dictionary('dictionary')
p i.inflate(s) == 'dictionary' * 100
i.reset
p i.inflate(s) == 'dictionary' * 100
i.close; d.close
# A block break leaves all unreported output for finish, using the caller's buffer.
s = Zlib.deflate('0' * 100000)
i = Zlib::Inflate.new
buf = +''
parts = []
i.inflate(s, buffer: buf) { |v| parts << [v.equal?(buf), v.size]; break }
rest = i.finish
p [parts, rest.size, rest == '0' * rest.size]
i.close
# Gzip framing, concatenation, unused data, finish and rewind.
io = StringIO.new
2.times do |n|
  w = Zlib::GzipWriter.new(io)
  w.mtime = 0; w.orig_name = "file#{n}\0discard"; w.comment = 'comment'
  w.write("data#{n}")
  p w.finish.equal?(io)
end
io.rewind
r = Zlib::GzipReader.new(io)
p [r.mtime.to_i, r.orig_name, r.comment, r.read(2), r.crc]
p r.read
p r.unused.nil?
r.rewind
p [r.pos, r.lineno, r.read]
r.finish
io.rewind
p Zlib::GzipReader.zcat(io)
# A single large NO_FLUSH call must emit compressed blocks before FINISH.
# The old prefix retry stopped after one attempt and retained all the input.
large = 'x' * (16 * 1024 * 1024)
d = Zlib::Deflate.new
i = Zlib::Inflate.new
prefix = i.inflate(d.deflate(large))
p prefix.bytesize > 0
p prefix == large.byteslice(0, prefix.bytesize)
prefix << i.inflate(d.finish)
p prefix == large
d.close; i.close
# Checksum composition and IO input.
[-1, 0, 1, 0xffffffff].each do |seed|
  p [Zlib.crc32("a\0b", seed), Zlib.adler32("a\0b", seed)]
end
File.open(ARGV[0], 'rb') { |f| p Zlib.crc32(f) }
File.open(ARGV[0], 'rb') { |f| p Zlib.adler32(f) }
[0, 1, 10000].each do |n|
  a = 'left'; b = 'x' * n
  p Zlib.crc32_combine(Zlib.crc32(a), Zlib.crc32(b), n) == Zlib.crc32(a + b)
  p Zlib.adler32_combine(Zlib.adler32(a), Zlib.adler32(b), n) == Zlib.adler32(a + b)
end
'''

DECODE = r'''
require 'zlib'
file, window, dict = ARGV
z = Zlib::Inflate.new(window.to_i)
out = +''.b
File.binread(file).each_byte do |b|
  begin
    out << z.inflate(b.chr.b)
  rescue Zlib::NeedDict
    raise unless dict
    z.set_dictionary(File.binread(dict))
    out << z.inflate('')
  end
end
out << z.finish
File.binwrite(file + '.out', out)
p [z.finished?, z.total_out, out.bytesize]
z.close
'''

MALFORMED = r'''
require 'zlib'
data = File.binread(ARGV[0])
begin
  out = Zlib.inflate(data)
  p [:ok, out.bytesize]
rescue Zlib::Error => e
  p e.class
end
'''


MEMORY = r'''
require 'zlib'
s = ('abcdefgh' * 4096).b
ARGV[0].to_i.times do
  d = Zlib::Deflate.new
  encoded = d.deflate(s, Zlib::FINISH)
  d.close
  z = Zlib::Inflate.new
  raise 'corrupted output' unless z.inflate(encoded) == s
  z.close
end
GC.start
puts 'zlib stream memory: values preserved'
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', default=os.environ.get('MR_BIN', str(ROOT / 'mere-ruby')))
    parser.add_argument('--reference', default=os.environ.get('REF_RUBY_BIN'))
    args = parser.parse_args()
    if not args.reference:
        args.reference = subprocess.check_output(
            ['sh', '-c', '. "$1/tools/ref_ruby.sh"; printf "%s" "$REF_RUBY_BIN"', 'sh', str(ROOT)], text=True)
    with tempfile.TemporaryDirectory(prefix='mr-zlib-stream-') as tmp:
        root = Path(tmp)

        def run(binary, source, *argv):
            script = root / 'probe.rb'
            script.write_text(source)
            return subprocess.run([binary, str(script), *map(str, argv)],
                                  capture_output=True, timeout=60)

        def compare(source, *argv):
            ref = run(args.reference, source, *argv)
            mr = run(args.binary, source, *argv)
            assert ref.returncode == 0, (argv, ref.stderr.decode(errors='replace'))
            assert mr.returncode == 0, mr.stderr.decode(errors='replace')
            if ref.stdout != mr.stdout:
                import difflib
                raise AssertionError(''.join(difflib.unified_diff(
                    ref.stdout.decode(errors='replace').splitlines(True),
                    mr.stdout.decode(errors='replace').splitlines(True), fromfile='ruby', tofile='mere')))

        checksummed = root / 'checksum'
        checksummed.write_bytes(b'a\0b')
        compare(PROTOCOLS, checksummed)
        print('stream and gzip protocols: identical to Ruby', flush=True)
        rng = random.Random(907)
        data = bytes(range(256)) * 5 + bytes(rng.randrange(256) for _ in range(1000)) + b'x' * 20000
        dictionary = root / 'dictionary'
        dictionary.write_bytes(data[:1000])
        # Native-produced raw, zlib, gzip, automatic headers, and a preset dictionary.
        for window, encoder_window, use_dict in [(-15, -15, False), (15, 15, False),
                                                   (31, 31, False), (47, 31, False), (15, 15, True)]:
            kwargs = {'zdict': dictionary.read_bytes()} if use_dict else {}
            enc = zlib.compressobj(wbits=encoder_window, **kwargs)
            path = root / f'input-{window}-{use_dict}'
            path.write_bytes(enc.compress(data) + enc.flush())
            compare(DECODE, path, window, *([dictionary] if use_dict else []))
            assert Path(str(path) + '.out').read_bytes() == data
        print('native streams with one-byte input: all framings and dictionary', flush=True)
        valid = zlib.compress(b'abc' * 100)
        cases = [valid[:n] for n in range(len(valid))]
        cases += [bytes([0x78, 0x9c, 7]), b'\x78\x9c\x01\x01\x00\x00\x00x',
                  valid[:-1] + bytes([valid[-1] ^ 1])]
        # Mutations of valid headers and dynamic blocks must raise or decode safely.
        for _ in range(20):
            buf = bytearray(zlib.compress(data))
            pos = rng.randrange(len(buf))
            buf[pos] ^= 1 << rng.randrange(8)
            cases.append(bytes(buf))
        for n, encoded in enumerate(cases):
            path = root / f'bad-{n}'
            path.write_bytes(encoded)
            compare(MALFORMED, path)
        print(f'malformed/truncated streams: {len(cases)} cases agree', flush=True)
        # Scratch vectors formerly escaped to the default arena on every call.
        # Measure allocation totals, independently of host RSS/allocator noise.
        totals = []
        script = root / 'memory.rb'
        script.write_text(MEMORY)
        for count in (50, 500):
            result = subprocess.run([args.binary, str(script), str(count)],
                                    env=dict(os.environ, MERE_REGION_STATS='1'),
                                    capture_output=True, text=True, timeout=60, check=True)
            assert result.stdout == 'zlib stream memory: values preserved\n', result.stdout
            match = re.search(r'region-stats default:.*alloc_total=(\d+)', result.stderr)
            assert match, result.stderr
            totals.append(int(match[1]))
        assert totals[1] - totals[0] < 2 * 1024 * 1024, totals
        print(f'50/500 stream lifecycles: default-arena allocation = {totals}', flush=True)


if __name__ == '__main__':
    main()
