# Lazy steps as they are named, eager methods that stop where they stop,
# Enumerable's visibility and orphan break, \u that is refused, and the
# character an undefined conversion names

# a lazy step prints the name it was called by, and its arguments
l = (1..10).lazy.map {}.collect {}.flat_map {}.collect_concat {}.select {}.find_all {}.reject {}.grep(1).zip(?a..?c).take(10).take_while {}.drop(3).drop_while {}.cycle(3)
puts l.inspect
p (1..3).lazy.with_index.inspect, (1..3).lazy.uniq.inspect, (1..3).lazy.compact.inspect

# an eager method on a lazy walks it one element at a time
p (1..).lazy.find { |x| x > 3 }, (1..).lazy.map { _1 * 2 }.find { |x| x > 3 }
p (1..9).lazy.map { _1 * 2 }.each_slice(2).to_a
p (1..4).lazy.select(&:even?).sort_by { -_1 }
File.write("/tmp/mere_corpus_385.txt", "a\nb\n\nclass X\n\nc\n\nd\n")
File.open("/tmp/mere_corpus_385.txt") do |f|
  ln = nil
  r = f.lazy.each("").map { |pa| pa[/\A\s*(.*)/, 1] }.find { |s| if s[/^class/]; ln = f.lineno; true; end }
  p r, ln
end
File.delete("/tmp/mere_corpus_385.txt")

# to_enum on a lazy names the eager method; with_index hands two values
a = [1, 2, 3].to_enum
p a.lazy.to_enum(:map).first(2).to_a, a.lazy.to_enum(:take, 2).first(2).to_a
lz = [1, 2, 3].lazy
def lz.foo(*args) = (yield args; yield args)
p lz.to_enum.to_a, lz.to_enum(:foo, :a).to_a
w = []
p (0..Float::INFINITY).lazy.with_index(2, &->(i, j) { w << [i - 1, j] }).take(2).to_a, w
p (0..Float::INFINITY).lazy.with_index(2).map(&->(i, j) { [i - 1, j] }).take(2).to_a
ary = [42, :foo]
%i[to_enum enum_for lazy each].each { |m| ary.define_singleton_method(m) { fail "#{m} was called" } }
p (1..2).lazy.zip(ary).force

# Enumerable: an operator made private is refused, a kept block's break
k = Class.new { include Enumerable; def each; yield 1; yield 2; yield 3; end }
%i[+ *].each do |op|
  begin
    Integer.class_eval { private op }
    k.new.inject(op)
  rescue NoMethodError => e
    p e.message
  ensure
    Integer.class_eval { public op }
  end
end
begin
  Integer.class_eval { private :+ }
  [1, 2].inject(:+)
rescue NoMethodError => e
  p e.message
ensure
  Integer.class_eval { public :+ }
end
p k.new.inject(:+), [1, 2].inject(:+)
kept = Object.new
class << kept
  attr_reader :block
  include Enumerable
  def each(&block) = (@block = block; self)
end
kept.first
begin; kept.block.call; rescue LocalJumpError => e; p e.message; end

# \u: four digits, a codepoint that exists, the regexp's own encoding
['"\uab"', '"\u"', '"\ughij"', '"\u{110000}"', '"\u{D800}"', '"\u{123.}"', '/\u{6666}/n', '/A/n'].each do |src|
  begin
    p [src, eval(src)]
  rescue SyntaxError
    p [src, :SyntaxError]
  end
end
p %x{echo "A"}, %x(printf '%s' "ü").bytes

# an undefined conversion names its character
begin
  "abc\xa4\xa2def".force_encoding("EUC-JP").encode("ISO-8859-1")
rescue Encoding::UndefinedConversionError => e
  p e.error_char, e.source_encoding_name, e.destination_encoding_name
end
