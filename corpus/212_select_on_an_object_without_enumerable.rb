# Found by the sweep that measured corpus/211: a bare `select` inside
# a method of an object without Enumerable bounced between the Enumerable route
# and the Kernel route until the native stack overflowed. ruby has Kernel#select
# (this interpreter does not); what both must do is answer, not die.
class NoEnum; def t; select; end; end
begin
  NoEnum.new.t
rescue ArgumentError, NoMethodError => e
  p e.class.ancestors.include?(StandardError)
end
class WithEnum; include Enumerable; def each; yield 1; yield 2; end; def t; select { |x| x > 1 }; end; end
p WithEnum.new.t
