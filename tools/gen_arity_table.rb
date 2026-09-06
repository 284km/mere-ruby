# Generates the builtin ARITY table embedded in main.mere between the
# ARITY_TABLE markers.
#
#   . ./tools/ref_ruby.sh && ruby tools/gen_arity_table.rb
#
# mere-ruby's primitive layer takes `args: Val list` and mostly ignores what it
# does not read, so `[1,2].first(1,2)` and `1.gcd` answered instead of raising:
# twenty-five spec files turn on exactly that, and fourteen more on the
# opposite (a refusal ruby does not make). Both directions are one missing
# fact -- how many arguments each name takes -- and it is not ours to invent.
#
# The oracle is asked the way it answers best: CALL the method with an
# impossible number of arguments and read the range out of its own refusal,
#
#   wrong number of arguments (given 9, expected 0..1)
#
# then call it with none, which is the only way to see a MINIMUM that has no
# maximum ("expected 1+"). A method that accepts nine arguments says nothing
# and gets no row -- an absent row means "unchecked", never "takes anything",
# so a wrong guess here cannot refuse a call ruby allows.
#
# Receivers are values only: no IO, no Process, no Thread, nothing whose
# methods end the program or close a file the generator is writing to. Probing
# RUNS the method, so every receiver comes from a factory (fresh each time)
# and stdout is captured while probing.
require "stringio"

# Enumerable and Comparable are asked through a class that includes them and
# defines nothing else, so the bounds are the MODULE's own -- probing them
# through an Array would record Array's overrides under Enumerable's name.
class ArityEnumSample
  include Enumerable
  # `each` takes anything: Enumerable#to_a FORWARDS its arguments to each, so
  # an each of fixed arity makes to_a look like it refuses them -- the refusal
  # would be the inner call's, recorded under the outer name.
  def each(*args); yield 1; self; end
end
class ArityCmpSample
  include Comparable
  def <=>(other); 0; end
end

SAMPLES = {
  "Enumerable" => -> { ArityEnumSample.new }, "Comparable" => -> { ArityCmpSample.new },
  "Integer" => -> { 1 }, "Float" => -> { 1.5 }, "String" => -> { +"s" }, "Array" => -> { [1] },
  "Hash" => -> { {a: 1} }, "Range" => -> { (1..3) }, "Symbol" => -> { :s },
  "NilClass" => -> { nil }, "TrueClass" => -> { true }, "FalseClass" => -> { false },
  "Rational" => -> { Rational(1, 2) }, "Complex" => -> { Complex(1, 2) },
  "Proc" => -> { proc { |x| x } }, "Method" => -> { 1.method(:+) },
  "UnboundMethod" => -> { Integer.instance_method(:+) },
  "Regexp" => -> { Regexp.new("x") }, "MatchData" => -> { Regexp.new("x").match("x") },
  "Time" => -> { Time.at(0) }, "Exception" => -> { StandardError.new("m") },
  "Enumerator" => -> { [1].each }, "Numeric" => -> { 1 },
  "Module" => -> { Module.new }, "Class" => -> { Class.new },
  "Encoding" => -> { Encoding::UTF_8 }, "Set" => -> { Set.new([1]) },
}

# Names that would end the process, block on input, or take a lock, plus the
# iteration names whose zero-argument form runs a body.
SKIP = %w[exit exit! abort sleep gets readline readlines fork exec system spawn loop raise fail
          throw catch binding trap kill wait wait2 waitpid detach at_exit warn puts print p pp
          display putc syscall select instance_eval instance_exec class_eval module_eval eval
          freeze srand read sysread readpartial readchar readbyte getc getbyte
          each each_line each_byte each_char each_codepoint each_grapheme_cluster each_entry
          each_with_index each_with_object each_pair each_key each_value
          each_index each_child reverse_each times upto downto step cycle lazy to_enum enum_for
          pass stop join value run wakeup next peek rewind irb_binding remove_method undef_method
          define_method alias_method attr attr_accessor attr_reader attr_writer].freeze

# Names whose arity belongs to the OBJECT, not to the class: a Method wraps a
# method and answers #call with that method's arity, so a row taken from one
# sample (`1.method(:+)`, arity 1) refuses every other Method's call. A table
# keyed by class cannot hold a per-object fact.
PER_OBJECT = {
  "Proc"          => %w[call () [] === yield curry],
  "Method"        => %w[call () [] === curry],
  "UnboundMethod" => %w[bind_call curry],
}.freeze

def range_from(msg)
  # "wrong number of arguments (given 9, expected 0..1)" -> [0, 1]
  m = /wrong number of arguments \(given \d+, expected ([^)]+)\)/.match(msg)
  return nil unless m
  spec = m[1]
  case spec
  when /\A(\d+)\z/            then [$1.to_i, $1.to_i]
  when /\A(\d+)\.\.(\d+)\z/   then [$1.to_i, $2.to_i]
  when /\A(\d+)\+\z/          then [$1.to_i, -1]
  end
end

# :ok        -- ruby ran it (or refused it for a reason that is not the count)
# [lo, hi]   -- ruby refused THE COUNT, and said what it wanted
def probe(factory, name, argc, with_block = false)
  out = StringIO.new
  old = $stdout
  $stdout = out
  begin
    if with_block
      factory.call.__send__(name, *Array.new(argc) { nil }) { |*| nil }
    else
      factory.call.__send__(name, *Array.new(argc) { nil })
    end
    :ok
  rescue ArgumentError => e
    range_from(e.message) || :ok
  rescue Exception
    :ok
  ensure
    $stdout = old
  end
end

# the bounds for one name, or nil when there is nothing to check
def bounds(factory, name, with_block)
  many = probe(factory, name, 9, with_block)
  none = probe(factory, name, 0, with_block)
  lo = none == :ok ? 0 : none[0]
  hi = many == :ok ? -1 : many[1]
  return nil if lo.zero? && hi == -1
  return nil if hi >= 0 && lo > hi
  return nil unless probe(factory, name, lo, with_block) == :ok
  return nil if hi >= 0 && probe(factory, name, hi + 1, with_block) == :ok
  [lo, hi]
end

rows = []
brows = []
SAMPLES.each do |cn, factory|
  begin
    klass = Object.const_get(cn)
  rescue NameError
    next
  end
  names = (klass.is_a?(Module) ? klass.instance_methods : []).sort
  names.each do |name|
    s = name.to_s
    next if SKIP.include?(s)
    next if PER_OBJECT.fetch(cn, []).include?(s)
    # Each probe answers ONE bound, and only the probe that actually refused
    # the count may be believed for it. ruby's own message is not a bound:
    # `(1..3).min(*9)` reports "expected 1" while `(1..3).min` answers 1 --
    # the refusal comes from an inner call whose arity is not this method's.
    # So: 0 args ran => the minimum IS 0, whatever the other message claims.
    plain = bounds(factory, name, false)
    rows << "#{cn}##{s}:#{plain[0]}:#{plain[1]}" if plain
    # ...and the bounds a BLOCK changes: `"ab".sub("a") { }` takes one
    # argument where the blockless form takes two, so a table probed without
    # one refuses a call ruby runs.
    blk = bounds(factory, name, true)
    brows << "#{cn}##{s}:#{blk[0]}:#{blk[1]}" if blk
  end
end
rows.uniq!
brows.uniq!
warn "#{rows.size} plain rows, #{brows.size} block rows from #{SAMPLES.size} classes"
puts "let arity_raw = \"#{rows.join(",")}\";"
puts "let arity_blk_raw = \"#{brows.join(",")}\";"
