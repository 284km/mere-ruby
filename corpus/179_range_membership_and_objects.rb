# `Range#include?` is a different question per endpoint kind, and a range of
# OBJECTS enumerates.
#
# The whole rule, asked of the oracle:
#
#   numeric endpoints (and Time ones)      -> COMPARE, so an endless range works
#   String / Symbol / an object with #succ -> WALK #succ, comparing with ==
#   no #succ at all                        -> TypeError, in every shape
#   a walk needs BOTH ends                 -> beginningless or endless is a TypeError
#   beginningless AND endless              -> true for anything orderable
#
# Answering the comparison for all of them made `("a".."e").include?("bc")`
# true, where ruby says false: "bc" is COVERED by the range and is not on the
# succ walk from "a" to "e". Raising for every object begin was the other half
# of the same mistake -- it took Time and #succ-bearing objects with it.

require 'time'

def t(label)
  puts "%-46s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-46s <%s: %s>" % [label, e.class, e.message]
end

class NoSucc
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(other)
    return nil unless other.is_a?(NoSucc)
    n <=> other.n
  end
  def inspect; "NoSucc(#{n})"; end
end

class WithSucc < NoSucc
  def succ; WithSucc.new(n + 1); end
  def inspect; "WithSucc(#{n})"; end
end

class Tenfold
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(other); n <=> other.n; end
  def succ; Tenfold.new(n * 10); end
  def inspect; "Tenfold(#{n})"; end
end

class NumSub < Numeric
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(o); n <=> (o.respond_to?(:n) ? o.n : o); end
  def inspect; "NumSub(#{n})"; end
end

# numeric endpoints COMPARE
t('(1..10).include?(5)')          { (1..10).include?(5) }
t('(1..).include?(5)')            { (1..).include?(5) }
t('(..10).include?(5)')           { (..10).include?(5) }
t('(1..).include?("x")')          { (1..).include?("x") }
t('(1.0..3.0).include?(2)')       { (1.0..3.0).include?(2) }
t('(NumSub..NumSub).include?(mid)') { (NumSub.new(1)..NumSub.new(9)).include?(NumSub.new(5)) }
t('(NumSub..).include?(bigger)')  { (NumSub.new(1)..).include?(NumSub.new(5)) }
t('(NumSub..NumSub).include?(Object)') { (NumSub.new(1)..NumSub.new(9)).include?(Object.new) }

# Time endpoints COMPARE too
ts = Time.at(0)
te = Time.at(100)
t('(ts..te).include?(mid)')       { (ts..te).include?(Time.at(50)) }
t('(ts..te).include?(past end)')  { (ts..te).include?(Time.at(500)) }
t('(ts..te).include?(1)')         { (ts..te).include?(1) }
t('(ts..te).include?(Object.new)'){ (ts..te).include?(Object.new) }
t('(ts..).include?(mid)')         { (ts..).include?(Time.at(50)) }
t('(ts...te).include?(te)')       { (ts...te).include?(te) }

# beginningless AND endless is true for anything orderable, and refuses the rest
t('(nil..nil).include?(1)')       { (nil..nil).include?(1) }
t('(nil..nil).include?(1.0)')     { (nil..nil).include?(1.0) }
t('(nil..nil).include?(1r)')      { (nil..nil).include?(1r) }
t('(nil..nil).include?(Complex)') { (nil..nil).include?(Complex(1)) }
t('(nil..nil).include?(NumSub)')  { (nil..nil).include?(NumSub.new(1)) }
t('(nil..nil).include?(Time)')    { (nil..nil).include?(Time.at(0)) }
t('(nil..nil).include?("x")')     { (nil..nil).include?("x") }

# a String range WALKS: covered is not the same as on the walk
t('("a".."e").include?("c")')     { ("a".."e").include?("c") }
t('("a".."e").include?("bc")')    { ("a".."e").include?("bc") }
t('("a".."e").cover?("bc")')      { ("a".."e").cover?("bc") }
t('("a".."aa").include?("b")')    { ("a".."aa").include?("b") }
t("('aa'...'aa').include?('aa')") { ('aa'...'aa').include?('aa') }
t('(..\'aa\').include?(\'a\')')   { (..'aa').include?('a') }
t("('aa'..).include?('a')")       { ('aa'..).include?('a') }
t("('a'..'aa').include?(Object)") { ('a'..'aa').include?(Object.new) }
t("('a'..'aa').include?('')")     { ('a'..'aa').include?('') }
t("('a'..'aa').include?(nil)")    { ('a'..'aa').include?(nil) }
t("('a'..'aa').include?([])")     { ('a'..'aa').include?([]) }
to_str_ok = Object.new
def to_str_ok.to_str; 'b'; end
t('to_str yielding a String')     { ('a'..'aa').include?(to_str_ok) }
to_str_bad = Object.new
def to_str_bad.to_str; 1; end
t('to_str yielding a non-String') { ('a'..'aa').include?(to_str_bad) }

# the codepoint path is for SINGLE-BYTE endpoints only -- a multi-byte
# character walks #succ, and the two disagree once a range crosses scripts
t("('X'..'z').to_a.size")         { ('X'..'z').to_a.size }
t("('a'..'e').to_a")              { ('a'..'e').to_a }
t('U+9995 in U+0999..U+9999')     { ("\u{999}".."\u{9999}").include?("\u{9995}") }
t('(:a..:e).include?(:c)')        { (:a..:e).include?(:c) }
t('(:a..:e).include?(:bc)')       { (:a..:e).include?(:bc) }

# an object with #succ walks; one without refuses, in every shape
t('WithSucc: mid')                { (WithSucc.new(1)..WithSucc.new(4)).include?(WithSucc.new(2)) }
t('WithSucc: past the end')       { (WithSucc.new(1)..WithSucc.new(4)).include?(WithSucc.new(5)) }
t('WithSucc: excluded end')       { (WithSucc.new(1)...WithSucc.new(4)).include?(WithSucc.new(4)) }
t('WithSucc: backward range')     { (WithSucc.new(4)..WithSucc.new(1)).include?(WithSucc.new(2)) }
t('WithSucc: empty range')        { (WithSucc.new(1)...WithSucc.new(1)).include?(WithSucc.new(1)) }
t('WithSucc: uncomparable arg')   { (WithSucc.new(0)..WithSucc.new(6)).include?(Object.new) }
t('WithSucc: beginningless')      { (..WithSucc.new(10)).include?(WithSucc.new(5)) }
t('WithSucc: endless')            { (WithSucc.new(0)..).include?(WithSucc.new(5)) }
t('NoSucc: both ends')            { (NoSucc.new(0)..NoSucc.new(9)).include?(NoSucc.new(5)) }
t('NoSucc: beginningless')        { (..NoSucc.new(10)).include?(NoSucc.new(5)) }
t('NoSucc: endless')              { (NoSucc.new(0)..).include?(NoSucc.new(5)) }
t('NoSucc: cover? still answers') { (NoSucc.new(0)..NoSucc.new(9)).cover?(NoSucc.new(5)) }

# Tenfold's succ skips: membership is what the WALK produces, not the interval
tf = Tenfold.new(1)..Tenfold.new(99)
t('Tenfold: below the begin')     { tf.include?(Tenfold.new(0)) }
t('Tenfold: equal to the begin')  { tf.include?(Tenfold.new(1)) }
t('Tenfold: on the walk')         { tf.include?(Tenfold.new(10)) }
t('Tenfold: inside but not on it'){ tf.include?(Tenfold.new(2)) }

# ...and a range of objects ENUMERATES, so every Enumerable name follows
sc = WithSucc.new(1)..WithSucc.new(3)
t('object range: to_a')           { sc.to_a }
t('object range: each')           { a = []; sc.each { |x| a << x.n }; a }
t('object range: each answers')   { sc.each { |x| }.class }
t('object range: excluded each')  { a = []; (WithSucc.new(1)...WithSucc.new(3)).each { |x| a << x.n }; a }
t('object range: map')            { sc.map { |x| x.n } }
t('object range: count')          { sc.count }
t('object range: min / max')      { [sc.min, sc.max] }
t('object range: minmax')         { sc.minmax }

# a Comparable operator asked BY NAME reaches the same rule as the operator
t('send(:==) via Comparable')     { WithSucc.new(1).send(:==, WithSucc.new(1)) }
t('send(:<) via Comparable')      { WithSucc.new(1).send(:<, WithSucc.new(2)) }
t('the operator itself')          { WithSucc.new(1) == WithSucc.new(1) }
t('an object with no <=> == self') { o = Object.new; o == o }
t('an object with no <=> == other'){ Object.new == Object.new }

# an exclusive end needs an Integer at BOTH ends to name its last element
t('(1...10).max')                 { (1...10).max }
t('(1...2**64).max')              { (1...2**64).max }
t('(1..10.0).max')                { (1..10.0).max }
t('(1...10.0).max')               { (1...10.0).max }
t('(1.0...10.0).max')             { (1.0...10.0).max }
t('(1.0...10).max')               { (1.0...10).max }
t('("a"..."f").max')              { ("a"..."f").max }
t('(:a...:f).max')                { (:a...:f).max }
t('(ts...te).max')                { (ts...te).max }

# min(n) / max(n) are ARITHMETIC on integer endpoints: a bignum end answered
# [] and an endless range never returned
t('(1..10).max(2)')               { (1..10).max(2) }
t('(1...10).max(2)')              { (1...10).max(2) }
# (0...2**64).max(2) is NOT here: ruby's Range#max(n) hands off to
# Enumerable#max(n), which enumerates, so the reference never returns. mere
# answers it arithmetically -- see KNOWN_GAPS.md. A corpus program has to be
# one BOTH can answer.
t('(1..10).min(2)')               { (1..10).min(2) }
t('(1...10).min(2)')              { (1...10).min(2) }
t('(0...2**64).min(2)')           { (0...2**64).min(2) }
t('(1..).min(2)')                 { (1..).min(2) }
t('(1..).max(2)')                 { (1..).max(2) }
t('(..1).min(2)')                 { (..1).min(2) }
t('(1..3).min(9)')                { (1..3).min(9) }
t('(1..3).max(9)')                { (1..3).max(9) }
t('(3..1).min(2)')                { (3..1).min(2) }
t("('f'..'l').min(2)")            { ('f'..'l').min(2) }
t("('a'...'f').min(2)")           { ('a'...'f').min(2) }
t('(303.2..908.1).max(2)')        { (303.20..908.1111).max(2) }
