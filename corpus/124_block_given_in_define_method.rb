# A define_method body is a BLOCK, so `block_given?` inside it asks about the
# frame the block was written in -- never about the call that reached the
# method. `C.new.dm { }` answered true here, where Ruby answers false.
class C
  define_method(:dm) { block_given? }
  def normal; block_given?; end
end
p C.new.dm { }
p C.new.dm
p C.new.normal { }
p C.new.normal

# ...and a body defined inside a method that WAS called with a block answers
# true, because that is the frame it was written in.
class D
  def self.mk; define_method(:z) { block_given? }; end
end
D.mk { }
p D.new.z
p D.new.z { }

class E
  def self.mk_noblock; define_method(:w) { block_given? }; end
end
E.mk_noblock
p E.new.w
p E.new.w { }

# an explicit &b still receives the caller's block, which is the supported way
class F
  define_method(:amp) { |&b| b ? b.call : :none }
end
p F.new.amp { :got }
p F.new.amp

# `block_given?` inside a BLOCK asks about the enclosing METHOD frame, and
# Ruby's rule reaches it through any number of blocks. Reading the block value
# threaded through evaluation answered about the innermost block call instead,
# so a plain `def m; [1].each { block_given? }; end` was false however m was
# called.
def outer_each; [1].each { |_| p block_given? }; end
outer_each { }
outer_each

def nested; [1].each { [2].each { p block_given? } }; end
nested { }
nested

def with_lambda; l = lambda { block_given? }; p l.call; end
with_lambda { }
with_lambda
