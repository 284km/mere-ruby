require 'tmpdir'

# An operator answers as refined only for the receiver and the operator a
# refinement covers, only in the file that used it, and only for the code
# written after the `using`.

module IntPlus835
  refine Integer do
    def +(o) = "plus(#{self},#{o})"
  end
end

module StrAppend835
  refine String do
    def <<(o) = "append(#{self},#{o})"
  end
end

module IntEq835
  refine Integer do
    def ==(o) = :refined_eq
  end
end

module ArrayFirst835
  refine Array do
    def first = :refined_first
  end
end

# written before any `using`: no refinement reaches into it, whenever it runs
def plus_before(a, b) = a + b
def append_before(s, t) = s << t
def eq_before(a, b) = a == b
add_before = proc { |a, b| a + b }

Dir.mktmpdir('refined-ops-835-') do |dir|
  # a file that never uses the refinements: its operators are the builtins'
  other = File.join(dir, 'unrefined_835.rb')
  File.write(other, <<~RUBY)
    def unrefined_plus_835(a, b) = a + b
    def unrefined_append_835(s, t) = s << t
    def unrefined_eq_835(a, b) = a == b
    def unrefined_loop_835(n)
      i = 0
      i += 1 while i < n
      i
    end
  RUBY
  require other

  # a refinement of another class is active: numbers, strings and
  # comparisons still answer as the builtins do
  using ArrayFirst835
  i = 0
  sum = 0
  while i < 1000
    sum += i * 2 - 1
    i += 1
  end
  p [i, sum, 7 / 2, 7 % 3, 2**10, 1 << 4, 6 & 3, 6 | 3, 6 ^ 3, 1.5 * 2]
  p [1 < 2, 2 <= 2, 3 > 4, 3 >= 4, 1 == 1, 1 != 1, "a" == "a", :s == :s, [1] == [1], nil == false]
  s = +"ab"
  s << "cd"
  p [s, [1, 2].first]

  using IntPlus835
  using StrAppend835
  p 1 + 2
  p 1.5 + 2                       # Float is not refined
  p 2 - 1                         # only + is
  t = +"x"
  p t << "y"
  p t
  p [1, 2] << 3                   # Array#<< is not refined
  p plus_before(1, 2)             # defined before the using
  p append_before(+"p", "q")
  p add_before.call(3, 4)
  p unrefined_plus_835(1, 2)      # the file that did not use them
  p unrefined_append_835(+"m", "n")
  p unrefined_loop_835(5)
  add_after = proc { |a, b| a + b }
  p add_after.call(3, 4)

  # send and public_send reach the refined operator, as ruby's do
  p 1.send(:+, 2)
  p 1.public_send(:+, 2)
  p "u".send(:<<, "v")
  p 1.send(:-, 2)

  using IntEq835
  p 1 == 2
  p 1 != 2
  p eq_before(1, 2)
  p unrefined_eq_835(1, 2)
  # a builtin's own comparisons are not refined
  p [1, 2].include?(5)
  p [1, 2].index(5)
  p({1 => :a}.key?(5))
  p [1, 2] == [1, 5]
  p [3, 1, 2].sort
  p (case 5 when 6 then :six else :other end)
end
