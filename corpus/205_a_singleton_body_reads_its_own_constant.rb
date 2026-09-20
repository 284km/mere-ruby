# A constant defined in a `class << self` body, read from that same body.
#
# Two keys are involved and they are not the same string. The DEFINITION is
# keyed by the singleton alone -- "(sng:M)::X" -- because that is where
# `M.singleton_class.constants` looks. The lexical SCOPE of the body is
# "M::(sng:M)", the enclosing part being there so a read can continue out to
# M and then to the top level.
#
# The read walked that scope by stripping one segment at a time: "M::(sng:M)",
# then "M", then "". It never asked the one spelling the write had used, so a
# body could not see its own constant while everyone outside could. uri is
# exactly this shape (`module Schemes; class << self; ReservedChars = ".+-"`)
# and `require "uri"` died on it.
#
# The same walk is written twice -- once for constants and once for autoloads
# -- and fixing one left the other answering NameError for the same program
# with one word changed. Both are here.

module M
  Z = "enclosing"
  class << self
    X = "abc"
    def f = X
    def out = Z            # the read must still walk OUT of the singleton
  end
end

p M.f
p M.out
p M.singleton_class.const_get(:X)
p M.singleton_class.constants.include?(:X)
p M.constants.include?(:X)   # false: it belongs to the singleton, not to M
p defined?(M::X)

# A class, not a module, and a second body that must get its OWN constant.
class C
  class << self
    K = 1
    def g = K
  end
end
class D
  class << self
    K = 2
    def g = K
  end
end
p [C.g, D.g]

# remove_const reaches it, which is the other door that could not see the key.
M.singleton_class.send(:remove_const, :X)
p M.singleton_class.constants.include?(:X)

# ...and the autoload twin: a bare `autoload` in a `class << self` body
# registers under the singleton too.
path = "/tmp/mere_ruby_corpus_205_al.rb"
File.open(path, "w") { |f| f.write("module M; class << self; AL = 42; end; end\n") }
$LOAD_PATH.unshift("/tmp")

module M
  class << self
    autoload :AL, "mere_ruby_corpus_205_al"
    def later = AL
  end
end

p M.later
File.delete(path)
