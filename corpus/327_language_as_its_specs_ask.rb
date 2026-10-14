# The language as ruby/spec's language specs ask it (note 349).
def se(src)
  eval(src)
  "no error"
rescue SyntaxError => e
  e.message[/identifier \S+ is not valid to get|numbered parameter is already used in outer block|_1 is reserved for numbered parameters|void value expression|unexpected 'in'|unexpected 'when'|expected a delimiter after the patterns of an `in` clause|duplicated variable name|\w+: no such local variable|expected a label as the key in the hash pattern|duplicated key name|Can't assign to \w+|Can't change the value of self/] || "other"
end
[
  "{a!:}", "{a?:}", "-> { _1; -> { _2 } }", "_1 = 0", "break true or false", "next true or false",
  "return true or false", "case []\nwhen 1 == 1\nin []\nend", "case []\nin []\nwhen 1 == 1\nend",
  "case 0\nin 1 + 1\n  true\nend", "case [0]\nin [a, a]\nend", "case [1, 2]\nin [^n, n]\nend",
  "case {a: 1}\nin {\"a\" => 1}\nend", "case {a: 1}\nin {a: 1, b: 2, a: 3}\nend",
  "nil = true", "true = 1", "self = 1",
].each { |src| puts "#{src.inspect}: #{se(src)}" }
# still fine
p [1, 2].map { break 3 }, (def m(a) = (return a, 2 if a; 3); m(1)), [1].map { next _1 * 2 }

# Object::A ||= reads the top-level constant
Object::A9 = 20
Object::A9 ||= 10
p Object::A9
begin; Object::B9 &&= 10; rescue NameError; p :name_error; end

# an operator's NoMethodError names it
[-> { nil + 3 }, -> { nil < 3 }, -> { Object.new < 3 }].each do |l|
  begin; l.call; rescue NoMethodError => e; p [e.name, e.args]; end
end
k = Class.new { attr_writer :foo; def foo = nil }
begin; k.new&.foo += 3; rescue NoMethodError => e; p e.name; end

# rescue: a modifier on an operator assignment's value, ===, splat to_a
a = "a"; c = "c"
a += b rescue c
p a
r = Class.new
def r.===(e) = true
begin; raise Exception; rescue r; p :success; rescue Exception; p :failure; end
o = Object.new
def o.to_a = [ArgumentError]
begin; raise ArgumentError; rescue *o; p :caught; end
