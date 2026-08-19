# `alias` in a class or module body is a statement, and it has to work wherever
# a statement can go. Only the top level of the body was handled, so an alias
# inside an `if`, an `unless` or a block silently did nothing -- and rubygems
# guards the one alias the whole of `require` hangs off:
#
#   unless defined?(gem_original_require)
#     alias gem_original_require require
#   end
class Aliased
  def orig; :from_orig; end
  if true
    alias in_if orig
  end
  unless false
    alias in_unless orig
  end
  [1].each do
    alias in_block orig
  end
  alias plain orig
end
a = Aliased.new
p [a.in_if, a.in_unless, a.in_block, a.plain]

# the shape rubygems uses: alias a BUILTIN, then replace it, and reach the
# original through the alias
module Kernel
  unless defined?(original_require)
    alias original_require require
    private :original_require
  end
  def require(path)
    $require_count = ($require_count || 0) + 1
    original_require(path)
  end
end
p require("set")
p [$require_count, Set.new([1, 2, 2]).size]

# ... and an alias inside a conditional fires method_added, as one at the top
# level does
class Hooked
  def self.method_added(name)
    (@added ||= []) << name
  end
  def self.added; @added; end
  def base; end
  if true
    alias conditional_alias base
  end
end
p Hooked.added
