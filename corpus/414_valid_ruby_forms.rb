# Ruby that ruby reads and mere-ruby refused (note 438), each with its value.

# a line break inside a destructuring group of block parameters
r = [[1, [2, 3]]].each_with_index.map {|(a,
                                          (b, c)), i| [a, b, c, i] }
p r

# the first argument of a command is a regexp after the space
def takes(*a) = a
p(takes /test_/, "why")
x = takes /ab/
p x
p(10 / 2, 10/5)

# a regexp with a quote inside an interpolation
ee = 'a"b'
puts %Q<#{ee.gsub(/["`$^]/, '\\\\\\&')} \\>
puts "#{ "q\"r".gsub(/["]/, "'") }"

# prefixed integers take the rational-imaginary suffix
p 0xFFri, 0b11r, 0o17i

# $0 is no match variable: it can be aliased
alias $prog_name_alias $0
p $prog_name_alias == $0

# the name after :: may be on the next line
p Comparable::
  name

# a setter given two values inside a brace block in an array
S = Struct.new(:name, :version)
p [S.new.tap {|s| s.name = "z", s.version = 1 }]

# patterns over several lines, with comments
h = {a: 1, b: [2], c: "x"}
case h
in {
  # the a key
  a: Integer,
  b: [
    # one element
    Integer
  ],
  c: (
    Symbol |
    String
  )
}
  p :matched
end
Pt = Struct.new(:x, :y)
case Pt.new(1, 2)
in Pt[
  x: 1,
  y:
]
  p y
end

# a character literal as a command argument
def first_char(c) = c
p(first_char ?!)

# []= called by its name at the end of a line
def setter_named
  nil.[]=
rescue NoMethodError => e
  e.name
end
p setter_named
