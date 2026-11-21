# `class <<self` with no space opens the singleton class; it is no here
# document whose terminator is "self" (rbs.rb writes it so)
class Foo
  class <<self
    def hi = :singleton
  end
end
p Foo.hi
obj = Object.new
class <<obj
  def there = 1
end
p obj.there
module M
  class<<self; def m = 2; end
end
p M.m
# ...while `<<` where a value starts is still a heredoc, and after a method
# named `class` it is an argument
x = <<self
inside
self
p x
o = Object.new
def o.class(*a) = a
p o.class <<-EOS
arg
EOS
