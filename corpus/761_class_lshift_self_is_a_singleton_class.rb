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

# Whitespace between the receiver separator and `class` keeps a method name.
p o. class <<BARE
bare
BARE
p o. class <<-INDENTED
  indented
  INDENTED
p o. class <<~'QUOTED'
  quoted
QUOTED
p o:: class <<-COLON
colon
COLON
p o.	class <<-TAB
 tab
TAB
p o.
 class <<-NEWLINE
newline
NEWLINE

# ...and so do a comment, a line continuation, or a comment-only line between
# them (the receiver's `.` or `::` is still what comes before `class`)
p o. # receiver comment
 class <<-COMMENT
comment
COMMENT
p o. \
 class <<-CONT
continued
CONT
p o:: # colon comment
 class <<-CCOLON
colon comment
CCOLON
p o::
 # a comment-only line
 class <<-ONLY
comment line
ONLY
# while a real `class <<self` after a comment line is the singleton class
class Foo # trailing note
  # a comment-only line
  class <<self
    def after_comment = :ok
  end
end
p Foo.after_comment
