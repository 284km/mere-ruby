# A private constant is "not there" as far as the scope operator is concerned,
# so a class with its OWN #const_missing gets asked -- Ruby calls the hook here
# exactly as it does for a name that was never defined. This raised straight
# past the hook.
#
# The predicate that made it possible is new: "does this class define the method
# ITSELF", as distinct from "can the method be called on it". They were sharing
# one answer, and the chain for const_missing always ends at a builtin one, so
# asking the old question said yes for every class in the program -- and calling
# that builtin says "uninitialized constant", which is the wrong thing to say
# about a constant that does exist.
class WithHook
  SECRET = 1
  private_constant :SECRET
  def self.const_missing(n); "missing #{n}"; end
end
p WithHook::SECRET

class NoHook
  SECRET = 2
  private_constant :SECRET
end
begin
  NoHook::SECRET
rescue => e
  puts "#{e.class}: #{e.message}"
end

# the constant is still readable from inside
class Inside
  V = 3
  private_constant :V
  def self.read; V; end
end
p Inside.read

# private_constant / public_constant as METHODS on the class -- only the
# statement form inside a class body existed. Ruby marks the names it
# recognises BEFORE raising for one it does not, so a call that fails part way
# through still took effect for the rest.
class Later
  A = 1
  B = 2
end
begin
  Later.private_constant :A, :NOPE
rescue NameError => e
  puts e.message
end
begin
  Later::A
rescue => e
  puts e.message
end
p Later::B
Later.public_constant :A
p Later::A
