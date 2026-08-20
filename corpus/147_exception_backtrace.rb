# An exception carries the frames of the raise. The stack was there after the
# previous slice; what was missing was somewhere to put a copy -- and the
# built-in exception representation is a class and a message with no identity, so
# there is nowhere ON it. The frames of the raise in flight are kept in one slot
# and answered for the exception that IS in flight (`$!`); an exception that has
# been rescued and put aside answers nil rather than another raise's frames.
# KNOWN_GAPS.md says so.
def inner
  raise ArgumentError, "boom"
end
def outer
  inner
end
begin
  outer
rescue => e
  p e.backtrace
end

begin
  raise "at the top level"
rescue => e
  p e.backtrace
end

# the innermost frame is the raise, not the rescue
def three_deep
  raise "deep"
end
begin
  three_deep
rescue => e
  p [e.backtrace.length, e.backtrace.first.include?("in `three_deep'")]
end

# a raise inside a block reports the line the raise is on
begin
  [1].each { raise "in a block" }
rescue => e
  p e.backtrace.first.split(":")[1].to_i > 0
end
