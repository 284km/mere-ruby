# A class_eval block is still a block (its enclosing locals stay visible),
# Symbol#to_proc is a real Proc, a regex literal's escaped delimiter is not
# part of its source, and a hash value may start on the next line.

# --- class_eval keeps the block's scope ------------------------------------
class Base
  class << self
    def registry; @registry ||= {}; end
    def inherited(base)
      us = self
      base.class_eval { @registry = us.registry.dup }
      super
    end
  end
end
Base.registry[:a] = 1
class Sub < Base; end
p Sub.registry
p Base.registry
Sub.registry[:b] = 2
p Base.registry

# --- Symbol#to_proc --------------------------------------------------------
POSITIVE = :positive?.to_proc
p POSITIVE.call(3)
p POSITIVE.call(-1)
p [1, -2, 3].select(&POSITIVE)
p :upcase.to_proc.call("ab")
p :upcase.to_proc.arity
p [[1, 2], [3, 4]].map(&:first)
p %w[a b].map(&:upcase)

# --- numeric reflection ----------------------------------------------------
p 5.respond_to?(:abs)
p 5.method(:abs).call
p (-5).method(:abs).to_proc.call
p 2.5.respond_to?(:round)
p 5.respond_to?(:no_such_method)

# --- a regex literal's escaped delimiter -----------------------------------
a = /a\/b/
p a.source
p a.match?("a/b")
b = /[^\/]+/
p b.source
p b.match("x/y")[0]
inner = /(?:[^\/]|\\\/)*/
p inner.source
outer_re = /\/(#{inner})(?<!\\)\/([imxo]*)/
p outer_re.match?("/ab/i")
p outer_re.match("/a\\/b/im")[2]
c = /x\\y/
p c.source
p c.match?("x\\y")

# --- a hash value may start on the next line -------------------------------
h = {
  :location =>
    2,
  "b" =>
    [1, 2],
  c:
    3
}
p h
def kw(**o); o; end
p kw(:a =>
  1)

# --- refine ::Const do ... end ---------------------------------------------
module Shout
  refine ::String do
    def shout; upcase + "!"; end
  end
end
using Shout
p "hi".shout

# --- StringScanner captures ------------------------------------------------
require "strscan"
sc = StringScanner.new("foo=42 bar")
p sc.scan(/(\w+)=(\d+)/)
p [sc[0], sc[1], sc[2]]
p sc.captures
p sc.size
p sc.values_at(1, 2)
p sc.scan(/nope/)
p sc[1]

# --- Range#minmax and its reflection ---------------------------------------
p (1..5).minmax
p [3, 1, 2].minmax
p Range.instance_method(:minmax).owner

# --- Set without a require -------------------------------------------------
p [1, 2, 2].to_set.size
p Set.new([1, 2]).include?(2)
p({ a: 1 }.to_a.to_set.size)

# Hash[...] takes three shapes: one Hash, one array of [k, v] pairs, or a flat
# even-length list. (A 1-element pair means a nil value.)
p Hash[:a, 1, :b, 2]
p Hash[[[:a, :b], [:c, :d]]]
p Hash[[[:a]]]
p Hash[{ x: 1 }]
p Hash[]
p Hash[a: 1, b: 2]                 # labels inside an index are one Hash argument
p Hash["k" => 1, b: 2]
def herr
  yield
rescue => e
  [e.class, e.message]
end
p herr { Hash[:a] }
p herr { Hash[[[:a, :b, :c]]] }
