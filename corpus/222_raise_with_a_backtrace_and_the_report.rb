# `raise Klass, message, backtrace` dropped its third argument, so the frames
# came from where the raise was written; the top-level report printed only
# `file:line: message (Class)`. The backtrace is kept now, and an uncaught
# exception is reported the way full_message renders it: the head line, a
# "\tfrom" per frame, then each cause.
def report(e) = e.full_message(highlight: false)

begin
  raise RuntimeError, "foo", ["/dir/foo.rb:10:in `raising'", "/dir/bar.rb:20:in `caller'"]
rescue => e
  p e.backtrace
  print report(e)
end
begin
  raise ArgumentError, "one frame", "only.rb:1"
rescue => e
  p e.backtrace, e.class
end
begin
  raise TypeError, "none", nil
rescue => e
  p e.backtrace.is_a?(Array), e.message
end
class Oops < StandardError
  def initialize(msg = "oops") = super
end
begin
  raise Oops, "custom", ["x.rb:3:in 'y'"]
rescue Oops => e
  p e.backtrace, e.message
end
def inner = raise("the cause")
def outer
  inner
rescue
  raise IOError, "wrapped", ["w.rb:5:in 'outer'"]
end
begin
  outer
rescue => e
  print report(e).lines.first
  p e.cause.message
end
