# A module really does respond to Module's instance methods, so
# `method(:autoload?)` inside one has to find it. zeitwerk branches on that
# method's arity to pick which autoload? form to call.
module M
  ARITY = method(:autoload?).arity
  p method(:autoload?).class
end
p M::ARITY
p M.method(:name).call
p M.respond_to?(:autoload?)
p M.respond_to?(:ancestors)
p M.respond_to?(:const_get)
p M.respond_to?(:no_such_thing_at_all)
p M.method(:const_get).call(:ARITY)

class K
  def self.mine; :mine; end
end
p K.respond_to?(:mine)
p K.method(:mine).call
p K.respond_to?(:instance_methods)

# `internal def m ... end` -- a def parsed as a command argument. The flag that
# stops the COMMAND taking a do-block must not leak into the def's own body.
def internal(name)
  name
end

internal def with_do(x)
  [x].each do |y|
    y
  end
end
p with_do(1)

p(internal def with_brace(x)
  [x].map { |y| y * 2 }
end)
p with_brace(3)

private def privately(x)
  [x, x].each_with_index do |v, i|
    v + i
  end
end
p send(:privately, 5)

# ...and the command still does not take a do-block itself
def takes_block(name)
  block_given? ? :block : name
end
p takes_block def plain
  1
end
