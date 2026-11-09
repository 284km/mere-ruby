# Round 5 of note 533 (numbers, strings, conversions): a number's === asks an
# object as its == does; Rational#quo and Complex#quo through #coerce; the
# numbers' #inspect encoding; "%#o" with a precision; ObjectSpace.dump's
# "fstring" field.
require "objspace"

# --- `1 === obj` is `obj == 1` (num_equal), for every kind of number
o = Object.new
def o.==(x) = x == 7 || x == 7.0 || x == 7r
p [7 === o, 7.0 === o, 7r === o, 8 === o, (2**70) === o]
r = case o
    when 3 then :three
    when 7 then :seven
    end
p r

# --- the numbers inspect in US-ASCII
p [1.inspect, (2**70).inspect, 1.5.inspect, 1r.inspect, 1i.inspect].map(&:encoding).uniq

# --- Rational#quo is Rational#/: through #coerce, the pair is asked #/
cr = Object.new
def cr./(x) = :divided
co = Object.new
ob = Object.new
ob.define_singleton_method(:coerce) { |x| [cr, co] }
p [Rational(3, 4) / ob, Rational(3, 4).quo(ob)]
# ...and Complex#quo and #/ ask the coerced pair #quo
ob2 = Object.new
def ob2.coerce(x) = [4, 2]
p [Complex(3, 9).quo(ob2), Complex(3, 9) / ob2]

# --- "%#o" with a precision: the precision's leading 0 is the one # asks for
[-8, 0, 1, 8, 0o777].each do |n|
  p [format("% #+-020.8o", n), format("%#-0.8o", n), format("%#.8o", n), format("%#o", n), format("%#.2o", n)]
end

# --- ObjectSpace.dump says which strings are fstrings (and chilled ones)
p [ObjectSpace.dump("dumped".freeze).include?('"fstring":true'),
   ObjectSpace.dump(-"abc".dup).include?('"fstring":true'),
   ObjectSpace.dump("abc".dup).include?('"fstring"'),
   ObjectSpace.dump(eval(%{"lit"})).include?('"chilled":true')]
