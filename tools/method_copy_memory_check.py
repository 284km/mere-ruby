#!/usr/bin/env python3
"""Check actual anonymous Method-copy definitions at the existing family bounds.

Each batch defines 20 Method copies on each of 1,000 new classes and lets them
go, then collects and samples RSS. A leak shows as growth from batch to batch.

What is compared is the peak of the second half against the peak of the first,
after a warm-up: max(RSS of batches 21-30) / max(RSS of batches 6-15). Without
a leak that is about 1.0 on either engine; the limit is 1.3. It is the median
of three runs.

It was max(every batch) / batch 0 against core_assertions.rb's 2.0. That
counted the climb of the first batches and where a collection happened to
fall: RSS rises for about eight batches and then saws between 120 and 175 MB
without growing, so the ratio was 1.6 to 2.1 on Linux with no leak at all, and
failed pull requests that changed nothing it measures (2.005 and 2.139).
GC_TIGHT did not steady it: it lowers the start and raised the ratio to 2.0.

    tools/method_copy_memory_check.py --reference ruby --output DIR
    tools/method_copy_memory_check.py ... --leak-every 10    a negative control

--leak-every N keeps every Nth class in a global Array, and does not run in
CI. At 5, about 5.4 MB a batch on Linux, the check must fail (a median of
1.46). At 10, about 3.3 MB a batch, it failed at 1.34, close to the limit.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import statistics
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

# Keep the outer CI process-family limits, independently of the growth bound.
WALL = 600
RSS_KB = 2097152
GROWTH = 1.3
RUNS = 3
BATCHES = 30
FIRST = range(6, 16)
SECOND = range(21, 31)
PROGRAM = '''STDOUT.sync = true
$kept = []
LEAK_EVERY = Integer(ARGV[0] || 0)
module CopyMemorySource
  20.times { |index| module_eval("def method_#{index}; nil; end", "copy_memory_source.rb", 1) }
end
definitions = CopyMemorySource.instance_methods(false).map { |name| CopyMemorySource.instance_method(name) }
made = 0
make_owners = lambda do
  1000.times do
    owner = Class.new
    definitions.each { |definition| owner.define_method(definition.name, definition) }
    made += 1
    $kept << owner if LEAK_EVERY > 0 && made % LEAK_EVERY == 0
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
BATCHES.times do |batch|
  make_owners.call
  collect.call
  sample.call(batch + 1)
end
puts "METHOD_COPY_LIFETIME_COMPLETE"
'''.replace('BATCHES.times', '%d.times' % BATCHES)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--leak-every', type=int, default=0,
                        help='keep every Nth class: a negative control, which must fail')
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
    result = dict(bounds=dict(wall_seconds=WALL, rss_kb=RSS_KB, second_half_peak_to_first=GROWTH,
                              runs=RUNS, batches=BATCHES, leak_every=args.leak_every),
                  check_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(), sides={})
    failed = False
    for side, interpreter in [('reference', args.reference.resolve()), ('mere', binary)]:
        runs = []
        for run in range(RUNS):
            log = args.output / ('%s.%d.log' % (side, run))
            execution = supervise([str(interpreter), '--disable-gems', str(program), str(args.leak_every)],
                                  env, log, RSS_KB, WALL)
            text = log.read_text(errors='replace')
            samples = [(int(batch), int(rss)) for batch, rss in re.findall(r'^RSS (\d+) (\d+)$', text, re.M)]
            complete = ([batch for batch, _ in samples] == list(range(BATCHES + 1))
                        and 'METHOD_COPY_LIFETIME_COMPLETE\n' in text)
            ratio = None
            if complete:
                rss = dict(samples)
                first = max(rss[batch] for batch in FIRST)
                ratio = max(rss[batch] for batch in SECOND) / first if first > 0 else None
            ok = execution['exit'] == 0 and execution['limit'] is None and ratio is not None
            runs.append(dict(execution=execution, samples_kb=samples, second_half_peak_to_first=ratio, ok=ok))
        ratios = [run['second_half_peak_to_first'] for run in runs if run['ok']]
        median = statistics.median(ratios) if len(ratios) == RUNS else None
        healthy = median is not None and median <= GROWTH
        result['sides'][side] = dict(runs=runs, median=median, healthy=healthy,
                                    binary_sha256=hashlib.sha256(interpreter.read_bytes()).hexdigest())
        failed |= not healthy
        (args.output / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
        print(side, json.dumps(dict(median=median, ratios=ratios, healthy=healthy)), flush=True)
    return int(failed)


if __name__ == '__main__':
    sys.exit(main())
