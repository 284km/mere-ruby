# An alias of a builtin class's `new` saved on its singleton runs the
# builtin construction after `define_singleton_method(:new)` replaces it --
# ActiveSupport's travel_to stubs Time.new this way. It recursed into the
# replacement (and before that, constructed by allocate + initialize, which
# Time refused as "already initialized")
Time.singleton_class.alias_method :__orig_new, :new
Time.define_singleton_method(:new) { |*a, **o| a.empty? ? at(0) : Time.send(:__orig_new, *a, **o) }
p Time.new(2000, 1, 2).year
p Time.__orig_new(2001, 2, 3).month
p Time.new.to_i
p Time.new(2002, 3, 4, 5, 6, 7, "+09:00").utc_offset
class << Time
  remove_method :new
  alias_method :new, :__orig_new
end
p Time.new(2003).year
String.singleton_class.alias_method :__orig_new, :new
String.define_singleton_method(:new) { |*a| String.__orig_new(*a) + "!" }
p String.new("x"), String.__orig_new("y")
class << String
  remove_method :new
end
p String.new("z")
Array.singleton_class.alias_method :__orig_new, :new
Array.define_singleton_method(:new) { |*a, &b| [:wrapped, Array.__orig_new(*a, &b)] }
p Array.new(2) { |i| i * 3 }
class << Array
  remove_method :new
end
p Array.new(2, 0)
