# Range: five separate gaps, and core/range was the worst-scoring group.
#
#   - #include? / #cover? / #=== answer FALSE when the comparison is not
#     possible. ruby asks <=> and reads nil as "not in the range"; cmp_vals
#     RAISED an ArgumentError instead, so `(1..3).include?("x")` was an error.
#   - two SINGLE-CHARACTER endpoints walk CODEPOINTS, not #succ. `'Z'.succ` is
#     "AA", which is longer than the end, so the succ walk stopped at Z and
#     `('X'..'z').to_a` had 3 elements where ruby has 35.
#   - a SYMBOL range walks like a String range; it answered [].
#   - a begin that cannot be walked is a TypeError, not an empty list:
#     `(1.0..3.0).to_a` was [] instead of "can't iterate from Float".
#   - #hash fell to 0 for every range, `(1..10) % 2` printed itself as a
#     `.step(2)`, and #overlap? did not exist.

require 'set'

def t(label)
  puts "%-34s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-34s <%s: %s>" % [label, e.class, e.message]
end

# membership never raises on an impossible comparison
t('(1..3).include?("x")')     { (1..3).include?("x") }
t('(1..3).cover?("x")')       { (1..3).cover?("x") }
t('(1..3) === "x"')           { (1..3) === "x" }
t('("a".."c").include?(1)')   { ("a".."c").include?(1) }
t('(1..3).include?(nil)')     { (1..3).include?(nil) }
t('(1..).include?("x")')      { (1..).include?("x") }
t('(1..3).include?(2)')       { (1..3).include?(2) }
t('(1..3).include?(2.5)')     { (1..3).include?(2.5) }
t('(1.0..3.0).include?(2)')   { (1.0..3.0).include?(2) }
t('("a".."e").include?("c")') { ("a".."e").include?("c") }
t('(:a..:e).include?(:c)')    { (:a..:e).include?(:c) }
t('(nil..nil).cover?(1)')     { (nil..nil).cover?(1) }
t('(1..) === 5')              { (1..) === 5 }
t('(..5) === 1')              { (..5) === 1 }

# the walk: codepoints for single characters, succ for anything longer
t("('a'..'e').to_a")          { ('a'..'e').to_a }
t("('a'...'e').to_a")         { ('a'...'e').to_a }
t("('X'..'z').to_a")          { ('X'..'z').to_a }
t("('A'..'z').to_a.size")     { ('A'..'z').to_a.size }
t("('1'..'9').to_a")          { ('1'..'9').to_a }
t("('e'..'a').to_a")          { ('e'..'a').to_a }
t("('a'..'a').to_a")          { ('a'..'a').to_a }
t("('Σ'..'Ω').to_a")          { ('Σ'..'Ω').to_a }
t("('aa'..'ad').to_a")        { ('aa'..'ad').to_a }
t("('ay'..'bb').to_a")        { ('ay'..'bb').to_a }
t("(:a..:e).to_a")            { (:a..:e).to_a }
t("(:a...:e).to_a")           { (:a...:e).to_a }
t("(:A..:z).to_a.size")       { (:A..:z).to_a.size }
t("('a'..'e').each")          { ('a'..'e').each { |x| }.class }
t("(:a..:c).each")            { (:a..:c).each { |x| }.class }
t("('a'..'e').map(&:upcase)") { ('a'..'e').map(&:upcase) }

# a begin that cannot be walked refuses
t('(1.0..3.0).to_a')          { (1.0..3.0).to_a }
t('(1.0..3.0).entries')       { (1.0..3.0).entries }
t('(1..3).to_a')              { (1..3).to_a }
t('(1..).to_a')               { (1..).to_a }
t('(..3).to_a')               { (..3).to_a }

# #hash tells ranges apart
t('(1..2).hash != 0')         { (1..2).hash != 0 }
t('(1..2).hash == (1..2).hash') { (1..2).hash == (1..2).hash }
t('(1..2).hash != (1..3).hash') { (1..2).hash != (1..3).hash }
t('(1..2).hash != (1...2).hash'){ (1..2).hash != (1...2).hash }
t('{(1..2) => :a}[(1..2)]')   { ({ (1..2) => :a })[(1..2)] }

# `%` is a step that remembers how it was written
t('((1..10) % 2).inspect')    { ((1..10) % 2).inspect }
t('(1..10).step(2).inspect')  { (1..10).step(2).inspect }
t('((1..10) % 2).to_a')       { ((1..10) % 2).to_a }
t('((1..10) % 2).size')       { ((1..10) % 2).size }
t('1.step(10, 2).inspect')    { 1.step(10, 2).inspect }

# #overlap?
t('(1..3).overlap?(2..5)')    { (1..3).overlap?(2..5) }
t('(1..3).overlap?(4..5)')    { (1..3).overlap?(4..5) }
t('(1..3).overlap?(3..5)')    { (1..3).overlap?(3..5) }
t('(1...3).overlap?(3..5)')   { (1...3).overlap?(3..5) }
t('(1..).overlap?(5..9)')     { (1..).overlap?(5..9) }
t('(..3).overlap?(5..9)')     { (..3).overlap?(5..9) }
t('(1..0).overlap?(1..3)')    { (1..0).overlap?(1..3) }
t('(1..3).overlap?(1..0)')    { (1..3).overlap?(1..0) }
t('("a".."c").overlap?(1..3)'){ ("a".."c").overlap?(1..3) }
t('(1..3).overlap?(1)')       { (1..3).overlap?(1) }

# Enumerable#to_set forwards its block
t('(1..3).to_set')            { (1..3).to_set.inspect }
t('(1..3).to_set { square }') { (1..3).to_set { |x| x * x }.inspect }
t('[1, 2].to_set { square }') { [1, 2].to_set { |x| x * x }.inspect }
t('Set.new([1, 2]) { +10 }')  { Set.new([1, 2]) { |x| x + 10 }.inspect }
t('Set.new([1, 2])')          { Set.new([1, 2]).inspect }
t('Set.new')                  { Set.new.inspect }
t('Set[1, 2]')                { Set[1, 2].inspect }

# #cover? / #=== COMPARE; #include? / #member? ITERATE. ruby draws the line
# there, and an object range shows it: cover? answers, include? refuses because
# there is nothing to walk from. Both were answered by the comparison, so
# include? claimed membership in a range it cannot enumerate -- and the leaf
# dispatcher has no world to dispatch <=> through, so a Comparable object came
# back as an ArgumentError rather than false.
class Cmp
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def inspect; "Cmp(#{@n})"; end
  def <=>(other)
    return nil unless other.is_a?(Cmp)
    n <=> other.n
  end
end

objr = (Cmp.new(0)..Cmp.new(10))
t('objr === Cmp.new(2)')      { objr === Cmp.new(2) }
t('objr === Cmp.new(20)')     { objr === Cmp.new(20) }
t('objr.cover?(Cmp.new(2))')  { objr.cover?(Cmp.new(2)) }
t('objr.cover?(Cmp.new(20))') { objr.cover?(Cmp.new(20)) }
t('objr === 5')               { objr === 5 }
t('objr.cover?("x")')         { objr.cover?("x") }
t('objr.include?(Cmp.new(2))'){ objr.include?(Cmp.new(2)) }
t('objr.member?(Cmp.new(2))') { objr.member?(Cmp.new(2)) }
t('(1..3).cover?(Cmp.new(2))'){ (1..3).cover?(Cmp.new(2)) }
t('(1..3) === 2')             { (1..3) === 2 }
t('("a".."e") === "c"')       { ("a".."e") === "c" }
t('case 2 when 1..3')         { (case 2 when (1..3) then :in else :out end) }
t('case "x" when 1..3')       { (case "x" when (1..3) then :in else :out end) }
