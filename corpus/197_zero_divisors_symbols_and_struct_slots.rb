# ---- 1. the two degenerate divisors ---------------------------------------
# `div` / `divmod` / `modulo` / `%` / `remainder` all REFUSE a zero divisor,
# whatever the operand types -- including 0.0, which looked like an exception
# to the rule and is not. Only `/` and `fdiv` answer Infinity. Every one of
# these used to come back with a NUMBER: 9223372036854775807 (the saturating
# conversion of Infinity) or the dividend itself.
[-> { 5.div(0) },      -> { 5.div(0.0) },     -> { 5.0.div(0) },
 -> { 5.divmod(0) },   -> { 5.divmod(0.0) },  -> { 5.0.divmod(0.0) },
 -> { 5 % 0 },         -> { 5 % 0.0 },        -> { 5.0 % 0 },
 -> { 5.0 % 0.0 },     -> { 5.modulo(0.0) },  -> { 5.0.modulo(0.0) },
 -> { 5.remainder(0) }, -> { 5.remainder(0.0) }, -> { 5.0.remainder(0) },
 -> { Rational(1, 2) % 0 }, -> { Rational(1, 2).div(Rational(0, 1)) },
 -> { (2**70).div(0) }, -> { (2**70).divmod(0) },
 # ...and NaN, which is not zero, so it divided: floor(x/NaN) saturated to 0
 -> { 5.0.div(Float::NAN) }, -> { 5.divmod(Float::NAN) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
# the two that DO answer
p [5.0 / 0, 5.fdiv(0), 5.0 % Float::NAN]

# an infinite divisor: the remainder comes from fmod and is pulled into the
# DIVISOR's sign, and the quotient is derived from it. `x - y*floor(x/y)` is
# 0*Inf = NaN, which is what these used to answer.
p [5.0 % Float::INFINITY, (-5.0) % Float::INFINITY, 5 % Float::INFINITY]
p [5.0.divmod(Float::INFINITY), (-5.0).divmod(Float::INFINITY),
   5.0.divmod(-Float::INFINITY)]

# ---- 2. arguments ruby refuses ---------------------------------------------
# pow's second argument is a MODULUS: a non-integer fell past the two-argument
# pattern into the one-argument arm, so this answered 8 with the modulus
# silently dropped.
[-> { 2.pow(3, "x") }, -> { 2.round("x") }, -> { 2.round(2**70) },
 -> { 2.round(Float::INFINITY) }, -> { 2.round(1 << 31) },
 -> { Rational(1, 2).truncate("x") },
 -> { "ab".match(/(a)(b)/).values_at(Object.new) },
 -> { warn "x", uplevel: "no" },
 -> { Float("x", exception: 1) }, -> { Integer("1", exception: 0) }].each do |f|
  begin
    f.call
  rescue => e
    puts "#{e.class}: #{e.message}"
  end
end
p [2.pow(3, 5), 2.round(1), Rational(1, 2).truncate(1),
   "ab".match(/(a)(b)/).values_at(0, 1)]

# ---- 3. Symbol ------------------------------------------------------------
p [Symbol.include?(Comparable), Symbol.ancestors.include?(Comparable)]
p [:b.between?(:a, :c), (:a <=> :b), :a.clamp(:b, :c)]

# #to_proc is a LAMBDA: it is strict about its arguments and a `return` inside
# it returns from IT. Two walks over its parameter list disagreed by a marker,
# so calling it wanted one argument more than its own #arity reported.
pr = :upcase.to_proc
p [pr.lambda?, pr.arity, pr.call("ok")]
p [:size.to_proc.call("xyz"), [:a, :b].map(&:to_s)]

# #name answers the SAME frozen string every call
a = :abc.name
b = :abc.name
p [a.equal?(b), a.frozen?, a]
# ...and #id2name is the older spelling, an ordinary copy
p [:abc.id2name.frozen?, :abc.id2name]

# one rule for a symbol's encoding, so #encoding, #to_s and #name agree
p [:abc.encoding.to_s, :abc.to_s.encoding.to_s, :abc.name.encoding.to_s]
p ["\u{3042}".to_sym.encoding.to_s, "\u{3042}".to_sym.to_s.encoding.to_s]

# `:$12` is ONE global, not `:$1` followed by 2 -- the numbered backref globals
# run to as many digits as are written, and this lexer took three characters.
p [:$1, :$12, :$1234, :$foo, :$~]
p [:$1234.to_s, :$1234.inspect, :"$ruby!".inspect]

# Symbol#=== is Symbol#==
p Symbol.instance_method(:===) == Symbol.instance_method(:==)
# ...and match/[] go through the string, so the block and the conversions do too
p :abc.match(/b/) { |m| m[0] }
p :abc.match(/b/)[0]
p :abc.match?(/b/)
len = Class.new { def to_int = 2 }
p :mbc[0, len.new]

# ---- 4. a Struct keeps its members outside the ivar table -----------------
S197 = Struct.new(:a, :b)
s = S197.new(1, 2)
p s.instance_variables
p s.instance_variable_get(:@a)
# setting an ivar that shares a member's name makes an ORDINARY ivar and leaves
# the member alone. It used to OVERWRITE the member, silently.
s.instance_variable_set(:@a, 99)
p [s.a, s[:a], s[0], s.to_h, s.to_a, s.values_at(0, 1)]
p [s.instance_variables, s.instance_variable_get(:@a)]
s.instance_variable_set(:@z, 7)
p [s.instance_variables.sort, s.to_h, s.instance_variable_defined?(:@z)]
# ...and everything the struct's own readers answer still comes from the member
s.a = 5
p [s.a, s.to_h, s.dig(:a), s.each_pair.to_a, s == S197.new(5, 2), s.inspect]
p s
Named197 = Struct.new(:x)
p [Named197.new(3).inspect, Named197.new(3).instance_variables]
kw = Struct.new(:m, keyword_init: true)
p [kw.new(m: 4).m, kw.new(m: 4).instance_variables, kw.new(m: 4).to_h]
case S197.new(7, 8)
in {a:, b:} then p [a, b]
end
