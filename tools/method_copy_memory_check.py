#!/usr/bin/env python3
"""Check actual anonymous Method-copy definitions at the existing family bounds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

# The post-GC growth factor is core_assertions.rb's default leak limit.
# Keep the outer CI process-family limits, independently of that assertion.
WALL = 600
RSS_KB = 2097152
GROWTH = 2.0
PROGRAM = '''STDOUT.sync = true
module CopyMemorySource
  20.times { |index| module_eval("def method_#{index}; nil; end", "copy_memory_source.rb", 1) }
end
definitions = CopyMemorySource.instance_methods(false).map { |name| CopyMemorySource.instance_method(name) }
make_owners = lambda do
  1000.times do
    owner = Class.new
    definitions.each { |definition| owner.define_method(definition.name, definition) }
  end
end
collect = lambda { 3.times { GC.start } }
sample = lambda do |batch|
  rss = IO.popen(["/bin/ps", "-o", "rss=", "-p", Process.pid.to_s], &:read).to_i
  raise "missing real RSS observation" unless rss > 0
  puts "RSS #{batch} #{rss}"
end
make_owners.call
collect.call
sample.call(0)
20.times do |batch|
  make_owners.call
  collect.call
  sample.call(batch + 1)
end
puts "METHOD_COPY_LIFETIME_COMPLETE"
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    binary = args.binary.resolve()
    if (binary.parent / '.build_mode').read_text().strip() != 'O2':
        parser.error('an O2 build is required')
    args.output.mkdir(parents=True, exist_ok=False)
    program = args.output / 'method_copy.rb'
    program.write_text(PROGRAM)
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('RUBY', 'GEM_', 'BUNDLE_', 'MERE_'))}
    env['LANG'] = 'en_US.UTF-8'
    result = dict(bounds=dict(wall_seconds=WALL, rss_kb=RSS_KB, post_gc_growth=GROWTH),
                  check_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), sides={})
    failed = False
    for side, interpreter in [('reference', args.reference.resolve()), ('mere', binary)]:
        log = args.output / (side + '.log')
        execution = supervise([str(interpreter), '--disable-gems', str(program)], env, log, RSS_KB, WALL)
        text = log.read_text(errors='replace')
        samples = [(int(batch), int(rss)) for batch, rss in re.findall(r'^RSS (\d+) (\d+)$', text, re.M)]
        complete = [batch for batch, _ in samples] == list(range(21)) and 'METHOD_COPY_LIFETIME_COMPLETE\n' in text
        # Check every collected prefix, so a later allocator trim cannot hide
        # growth that already crossed the upstream default leak bound.
        ratio = max(rss for _, rss in samples[1:]) / samples[0][1] if complete and samples[0][1] > 0 else None
        healthy = execution['exit'] == 0 and execution['limit'] is None and complete and ratio <= GROWTH
        result['sides'][side] = dict(execution=execution, samples_kb=samples, post_gc_peak_to_initial=ratio,
                                    healthy=healthy, binary_sha256=hashlib.sha256(interpreter.read_bytes()).hexdigest())
        failed |= not healthy
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(side, json.dumps(result['sides'][side]), flush=True)
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
