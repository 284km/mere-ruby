# A rescue clause that only matches -- `rescue; end`, `rescue Foo; end` --
# binds nothing, and the VM no longer makes the exception an object with its
# own frames for it (as run_rescues does not). Every clause that can see the
# exception still gets that object, and $! is it.

def boom(m = "boom") = raise(ArgumentError, m)

# a clause that only matches, many times over
n = 0
2000.times { begin; boom; rescue; n += 0; end }
3000.times do
  begin
    boom
  rescue ArgumentError
  end
end
p n, $!

# a clause that binds it: the same object as $!, and its own frames
begin
  boom("bound")
rescue => e
  p e.equal?($!), e.message, e.backtrace.first[/in .*/], $!.class
end
p $!

# a bare raise in the clause passes the same exception on
begin
  begin
    boom("again")
  rescue
    raise
  end
rescue => e2
  p e2.message, e2.class
end

# retry, then a clause that binds
tries = 0
begin
  tries += 1
  boom("retry") if tries < 3
  p tries
rescue
  retry
end

# $! in an ensure after a clause that only matched
def ens
  begin
    boom("ens")
  rescue ArgumentError
  ensure
    return $!.inspect
  end
end
p ens

# a class with its own === sees the exception it is asked about
class Matcher
  @seen = []
  class << self
    attr_reader :seen
    def ===(x) = (@seen << x.message; true)
  end
end
begin
  boom("matched")
rescue Matcher
end
p Matcher.seen

# a nested rescue that only matches, inside one that binds
begin
  begin
    boom("inner")
  rescue TypeError
  end
rescue ArgumentError => outer
  p outer.message, outer.equal?($!)
end
