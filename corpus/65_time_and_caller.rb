require "time"

# formatting is zone-independent for a UTC time
t = Time.utc(2023, 11, 15, 7, 13, 20)
p t.iso8601, t.xmlschema
p t.httpdate
p t.rfc2822
p Time.utc(2024, 2, 29).iso8601

# parsing, with the zone spelled out so CRuby and mere-ruby agree
p Time.parse("2023-11-15T07:13:20Z").iso8601
p Time.iso8601("2024-02-29T00:00:00Z").iso8601
# (CRuby keeps the +00:00 offset here; mere-ruby has no zone and says Z,
#  so compare the instant rather than the spelling)
p Time.parse("Wed, 15 Nov 2023 07:13:20 GMT").to_i
begin
  Time.parse("not a date")
rescue ArgumentError => e
  p e.class.to_s
end

# Time arithmetic and the calendar fields it needs
u = Time.utc(2023, 11, 15, 7, 13, 20)
p u.to_i, u.wday, u.yday
p (u + 60).to_i, (u - 60).to_i
p (u + 86400).day
p ((u + 60) - u)
p Time.utc(1970, 1, 1).wday, Time.utc(1970, 1, 1).yday
p Time.utc(2024, 3, 1).yday, Time.utc(2023, 3, 1).yday, Time.utc(2024, 12, 31).yday

# an implicit-self call inside a reopened Time reaches its builtin methods
class Time
  def ymd; [year, month, day]; end
end
p Time.utc(2020, 5, 6).ymd

# Kernel#caller: mere-ruby keeps no call stack, so the array is empty
p caller.class, caller.empty?
p caller_locations.class

# Constants come from the ancestors of the enclosing class too: an included
# module's constants are visible in the including class, and a subclass sees
# its superclass's.
module Holder
  module PAT
    ESC = "esc"
  end
  TOP = "top"
end
class UserOfHolder
  include Holder
  def a; PAT::ESC; end
  def b; TOP; end
end
p UserOfHolder.new.a, UserOfHolder.new.b

class BaseWithConst
  BK = "base"
end
class SubOfBase < BaseWithConst
  def c; BK; end
end
p SubOfBase.new.c

# ...but the lexical scope still wins over an ancestor's
module Outer2
  SHARED = :lexical
  module Mixin
    SHARED = :from_mixin
  end
  class Both
    include Mixin
    def which; SHARED; end
  end
end
p Outer2::Both.new.which
