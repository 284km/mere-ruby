# What a Range can BE, and what it can WALK -- two questions, and ruby answers
# both by asking the endpoints rather than by knowing their classes.
#
#   Range.new(a, b) is valid    <=>  (a <=> b) is not nil
#   the range can be WALKED     <=>  its BEGIN can be walked, alone
#
# Deciding validity from a LIST of comparable kinds (numeric, String, Symbol,
# an object whose class defines <=>) left Array off the list, so ruby's
# perfectly ordinary `(["a"]..["f"])` was an ArgumentError at CONSTRUCTION --
# which hid every later question about it: #min, #max and #cover? never ran,
# and #each, #to_a and #min(2) reported the constructor's ArgumentError where
# ruby reports a TypeError from the walk.
#
# Deciding walkability from EITHER endpoint made `(1..10.0)` unwalkable, and
# hard-coding the class in its message reported `(["a"]..["f"]).max(2)` as
# "can't iterate from Float".

def t(label)
  puts "%-44s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-44s <%s: %s>" % [label, e.class, e.message]
end

# --- what can a range BE? whatever <=> answers for ---
t('([1]..[2])')                   { ([1]..[2]) }
t('([1,2]..[1])')                 { ([1,2]..[1]) }        # backwards is still valid
t('([[1]]..[[2]])')               { ([[1]]..[[2]]) }      # nested, element-wise
t('([1]..["a"])')                 { ([1]..["a"]) }        # [1] <=> ["a"] is nil
t('([1,[2]]..[1,["a"]])')         { ([1,[2]]..[1,["a"]]) } # the deciding pair is nil
t('([1]..1)')                     { ([1]..1) }
t('(nil..[2])')                   { (nil..[2]) }          # one end is no constraint
t('({}..{})')                     { ({}..{}) }            # == , so <=> is 0
t('({a: 1}..{b: 2})')             { ({a: 1}..{b: 2}) }    # Hash has no <=>
t('(//..//)')                     { (//..//) }            # == , so <=> is 0
t('(/a/../b/)')                   { (/a/../b/) }          # Regexp has no <=>
t('(1..2**64)')                   { (1..2**64) }
t("(1..'a')")                     { (1..'a') }
t('(Object.new..Object.new)')     { (Object.new..Object.new) }
# `(o..o)` for a bare Object is valid too -- Object#<=> answers 0 for the same
# object -- but its inspect carries an ADDRESS, so it is asked here as a
# question with a stable answer rather than printed.
o = Object.new
t('(o..o) is built')              { (o..o).class }        # Object#<=> is 0 for self
t('(o..o).min.equal?(o)')         { (o..o).min.equal?(o) }

class Cmp
  include Comparable
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(other); other.is_a?(Cmp) ? n <=> other.n : nil; end
  def inspect; "Cmp(#{n})"; end
end
t('(Cmp..Cmp)')                   { (Cmp.new(1)..Cmp.new(2)) }
t('(Cmp..1) -- its <=> says nil') { (Cmp.new(1)..1) }

class Raiser
  def <=>(other); raise "asked"; end
end
t('a <=> that RAISES')            { (Raiser.new..Raiser.new) }

# --- an ARRAY range: valid, comparable, and not walkable ---
ar = ['a']..['f']
t('array range: min')             { ar.min }
t('array range: max')             { ar.max }
t('array range: first')           { ar.first }
t('array range: last')            { ar.last }
t('array range: minmax')          { ar.minmax }
t('array range: cover?')          { ar.cover?(['b']) }
t('array range: === ')            { ar === ['b'] }
t('array range: to_a')            { ar.to_a }
t('array range: each')            { ar.each { |x| x } }
t('array range: include?')        { ar.include?(['b']) }
t('array range: count')           { ar.count }
t('array range: size')            { ar.size }
t('array range: sum')             { ar.sum }
t('array range: first(2)')        { ar.first(2) }
t('array range: min(2)')          { ar.min(2) }
t('array range: max(2)')          { ar.max(2) }
t('array range: exclusive max')   { (['a']...['f']).max }
t('array range: exclusive minmax'){ (['a']...['f']).minmax }

# --- the BEGIN alone decides the walk ---
t('(1..10.0).max(2)')             { (1..10.0).max(2) }
t('(1...10.0).max(2)')            { (1...10.0).max(2) }
t('(1..10.0).min(2)')             { (1..10.0).min(2) }
t('(1.0..10).max(2)')             { (1.0..10).max(2) }
t('(1..3.5).to_a')                { (1..3.5).to_a }
t('(1..3.5).size')                { (1..3.5).size }
t('(1...4.0).size')               { (1...4.0).size }
t('(1.5..3.5).size')              { (1.5..3.5).size }
t('(1.5..3.5).count')             { (1.5..3.5).count }
t('(1.0..3.0).sum')               { (1.0..3.0).sum }
t('(1.0..3.0).min / max')         { [(1.0..3.0).min, (1.0..3.0).max] }
t('(1.0..3.0).first')             { (1.0..3.0).first }
t('(1.0..3.0).minmax')            { (1.0..3.0).minmax }
t('(1.0...3.0).minmax')           { (1.0...3.0).minmax }
t('(1.5...3).minmax')             { (1.5...3).minmax }
t('(nil..1).size')                { (nil..1).size }
t('(..5).sum')                    { (..5).sum }
t("('a'..'f').size")              { ('a'..'f').size }
t("(:a..:f).size")                { (:a..:f).size }
t("('a'..'f').count")             { ('a'..'f').count }
t("('a'..'f').first")             { ('a'..'f').first }

# --- a BIGNUM bound is not an unwalkable bound ---
t('(1..2**64).size')              { (1..2**64).size }
t('(2**64..2**65).size')          { (2**64..2**65).size }
t('(2**64..).size')               { (2**64..).size }
t('(1..).size')                   { (1..).size }
t('(1..2**64).count')             { (1..2**64).count }
t('(1..2**64).sum')               { (1..2**64).sum }
t('(1...2**64).sum')              { (1...2**64).sum }
t('(1..2**64).first(2)')          { (1..2**64).first(2) }
t('(1..2**64).take(3)')           { (1..2**64).take(3) }
t('(1...2**64).max')              { (1...2**64).max }
t('(2**64..2**64+2).to_a')        { (2**64..2**64+2).to_a }
t('(2**64..2**64+2).sum')         { (2**64..2**64+2).sum }
t('(2**64..2**64+2).minmax')      { (2**64..2**64+2).minmax }
t('(2**64..2**64+2).each')        { a = []; (2**64..2**64+2).each { |x| a << x }; a }
t('(2**64..2**64+2).map')         { (2**64..2**64+2).map { |x| x - 2**64 } }
t('(2**64..2**64+2).include?')    { (2**64..2**64+2).include?(2**64 + 1) }
t('(0...2**64).min(2)')           { (0...2**64).min(2) }

# --- #minmax IS #min and #max, so it agrees with them ---
t('(1...10).minmax')              { (1...10).minmax }
t("('a'...'f').minmax")           { ('a'...'f').minmax }
t('(3..1).minmax')                { (3..1).minmax }
t('(1...10.0).minmax')            { (1...10.0).minmax }
t('(1..10).minmax')               { (1..10).minmax }

# --- an object begin with no #succ: endpoints answer, walks refuse ---
require 'time'
ts = Time.at(0)
te = Time.at(9)
t('Time range: min')              { (ts..te).min == ts }
t('Time range: max')              { (ts..te).max == te }
t('Time range: first')            { (ts..te).first == ts }
t('Time range: minmax')           { (ts..te).minmax == [ts, te] }
t('Time range: exclusive max')    { (ts...te).max }
t('Time range: to_a')             { (ts..te).to_a }
t('Time range: size')             { (ts..te).size }
t('Time range: count')            { (ts..te).count }
t('Time range: sum')              { (ts..te).sum }
t('Time range: first(2)')         { (ts..te).first(2) }
t('Time range: include?')         { (ts..te).include?(Time.at(5)) }
t('Time range: cover?')           { (ts..te).cover?(Time.at(5)) }

class NumSub < Numeric
  attr_reader :n
  def initialize(n); @n = n; end
  def <=>(o); n <=> (o.respond_to?(:n) ? o.n : o); end
  def inspect; "NumSub(#{n})"; end
end
ns = NumSub.new(1)..NumSub.new(9)
t('NumSub range: min / max')      { [ns.min, ns.max] }
t('NumSub range: minmax')         { ns.minmax }
t('NumSub range: to_a')           { ns.to_a }
t('NumSub range: size')           { ns.size }
t('NumSub range: count')          { ns.count }
t('NumSub range: include?')       { ns.include?(NumSub.new(5)) }

class Succ < Cmp
  def succ; Succ.new(n + 1); end
  def inspect; "Succ(#{n})"; end
end
sc = Succ.new(1)..Succ.new(3)
t('Succ range: to_a')             { sc.to_a }
t('Succ range: count')            { sc.count }
t('Succ range: size')             { sc.size }
t('Succ range: minmax')           { sc.minmax }
t('Succ range: first(2)')         { sc.first(2) }

# --- membership in a HALF-OPEN range it cannot compare ---
t("('aa'..).include?('a')")       { ('aa'..).include?('a') }
t("(..'aa').include?('a')")       { (..'aa').include?('a') }
t("(['a']..).include?(['b'])")    { (['a']..).include?(['b']) }
t("(..['f']).include?(['b'])")    { (..['f']).include?(['b']) }
t('(Succ..).include?(Succ)')      { (Succ.new(0)..).include?(Succ.new(5)) }
t('(1..).include?(5)')            { (1..).include?(5) }
t('(1.5..).include?(2)')          { (1.5..).include?(2) }
t('(Time..).include?(Time)')      { (ts..).include?(Time.at(5)) }
t('(..Time).include?(Time)')      { (..te).include?(Time.at(5)) }
t('(nil..nil).include?(1)')       { (nil..nil).include?(1) }
