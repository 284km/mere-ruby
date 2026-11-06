#!/usr/bin/env python3
"""Check large zlib/gzip streams against an independent native decoder."""
import argparse
import gzip
from pathlib import Path
import random
import subprocess
import tempfile
import time
import zlib


PROBE = '''require "zlib"
path, mode = ARGV
data = File.binread(path)
if mode == "compress"
  File.binwrite(path + ".zlib", Zlib.deflate(data))
  File.binwrite(path + ".gzip", Zlib.gzip(data))
elsif mode == "zlib"
  File.binwrite(path + ".out", Zlib.inflate(data))
elsif mode == "gzip"
  File.binwrite(path + ".out", Zlib.gunzip(data))
else
  begin
    Zlib.gunzip(data)
  rescue Zlib::GzipFile::CRCError
    exit 0
  end
  raise "corrupted CRC was accepted"
end
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=Path(__file__).resolve().parent.parent / 'mere-ruby')
    args = parser.parse_args()
    binary = args.binary.resolve()
    rng = random.Random(731)
    cases = {
        'empty': b'',
        'binary': bytes(range(256)) * 260,
        'repeat-1m': b'x' * 1048576,
        # More than 150,000 largely literal tokens exercises multiple blocks.
        'random-200k': bytes(rng.randrange(256) for _ in range(200000)),
    }
    with tempfile.TemporaryDirectory(prefix='mr-zlib-') as directory:
        root = Path(directory)
        script = root / 'probe.rb'
        script.write_text(PROBE)

        def run(path, mode):
            # Catch the former window scan without relying on tight timings.
            subprocess.run([str(binary), str(script), str(path), mode], check=True,
                           capture_output=True, timeout=30)

        for name, data in cases.items():
            path = root / name
            path.write_bytes(data)
            start = time.monotonic()
            run(path, 'compress')
            elapsed = time.monotonic() - start
            encoded = path.with_name(name + '.zlib').read_bytes()
            assert zlib.decompress(encoded) == data, name
            assert gzip.decompress(path.with_name(name + '.gzip').read_bytes()) == data, name
            if name == 'repeat-1m':
                assert len(encoded) < len(data) // 100, 'repetition must actually compress'
            for mode, encoded in [('zlib', zlib.compress(data)), ('gzip', gzip.compress(data, mtime=0))]:
                source = root / (name + '.native-' + mode)
                source.write_bytes(encoded)
                run(source, mode)
                assert source.with_name(source.name + '.out').read_bytes() == data, (name, mode)
            print(f'{name}: both formats, both directions, compression {elapsed:.3f}s', flush=True)
        broken = bytearray(gzip.compress(b'CRC witness', mtime=0))
        broken[-8] ^= 1
        path = root / 'bad-crc.gz'
        path.write_bytes(broken)
        run(path, 'bad-crc')
        print('corrupt gzip CRC: rejected')


if __name__ == '__main__':
    main()
