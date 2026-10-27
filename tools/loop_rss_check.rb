# The loops whose turns used to keep memory, each run the way ruby's
# assert_no_memory_leak runs it: RSS after a warm-up, the loop, GC.start, RSS
# again. ruby's limit is twice the first; this one is 1.6, so a turn that keeps
# a few hundred bytes again shows before ruby's tests do (note 441).
#
#   ./mere-ruby tools/loop_rss_check.rb N     one case, by number
#   ./tools/loop_rss_check.sh [mere-ruby]     every case, each in a process
#
# A process per case: in one process every later case would start from the
# RSS the earlier ones reached, and its ratio would say less.
LIMIT = 1.6

def rss = `ps -orss= -p #{$$}`.to_i

class LoopRssError < StandardError; end
def lrc_raise(_x) = raise(LoopRssError)

CASES = {
  # a raise out of a method kept the method's frame (6 KB a turn)
  "raise out of a method" => ->(d) { (100_000 / d).times { begin; lrc_raise(1); rescue LoopRssError; end } },
  # a Hash.new block was a GC root for good (1.4 GB at 200k)
  "Hash.new with a block" => ->(d) { (200_000 / d).times { Hash.new { |h, k| h[k] = 1 }[:a] } },
  # the eval env was a new map and a parent link per eval
  "eval" => ->(d) { (20_000 / d).times { eval("1 + 1") } },
  # ...and one that fails to parse kept its pooled env
  "eval of a syntax error" => ->(d) { (10_000 / d).times { begin; eval("/[/=~s"); rescue SyntaxError; end } },
  # a pattern that fails to compile is parsed again each time
  "Regexp.new that fails" => ->(d) { (40_000 / d).times { begin; Regexp.new("a(b"); rescue RegexpError; end } },
  # the entry threshold grew with every String ever made
  "gsub" => ->(d) { (100_000 / d).times { "aaaaaaaaaaa".gsub(/a/, "") } },
  # encode's buffers went to the default region, a fallback raised per turn
  "encode with a raising fallback" => ->(d) {
    fb = Hash.new { raise LoopRssError }
    (100_000 / d).times { begin; "\ufffd".encode(Encoding::US_ASCII, fallback: fb); rescue LoopRssError; end }
  },
}

name, body = CASES.to_a.fetch(Integer(ARGV.fetch(0)))
# (the warm-up is ruby's PREP: the first turns build what any turn reuses)
body.call(10)
GC.start
before = rss
body.call(1)
GC.start
after = rss
ratio = after.fdiv(before)
puts format("%-4s %-32s %6d KB -> %6d KB  %.2f", ratio < LIMIT ? "ok" : "FAIL", name, before, after, ratio)
exit(ratio < LIMIT ? 0 : 1)
