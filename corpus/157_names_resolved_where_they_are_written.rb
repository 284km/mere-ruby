# A rescue clause names a CONSTANT, and a constant resolves through the lexical
# scope it is written in. The clause's names used to be compared as bare text, so
# inside a namespace they never matched what was raised -- `Bundler.settings`
# rescues its own GemfileNotFound that way, which made every `bundle` subcommand
# answer "Could not locate Gemfile".
module Ns
  class MyError < StandardError; end
  class Other < StandardError; end
  def self.boom; raise MyError, "from boom"; end
  def self.bare
    boom
  rescue MyError
    :bare
  end
  def self.qualified
    boom
  rescue Ns::MyError
    :qualified
  end
  def self.wrong_one
    boom
  rescue Other
    :wrong
  end
  def self.memoized
    @memo ||= boom
  rescue MyError
    :memoized
  end
end
p [Ns.bare, Ns.qualified, Ns.memoized]
p (Ns.wrong_one rescue [:escaped, $!.class])

class Outer
  class Inner < StandardError; end
  def self.raise_it; raise Inner, "x"; end
  def self.catch_it
    raise_it
  rescue Inner => e
    [:caught, e.class]
  end
end
p Outer.catch_it

# `yield` takes a paren-less argument that begins with punctuation. A
# double-quoted string does (it can interpolate) where a single-quoted one does
# not, so `yield "k", 2` parsed as a bare yield followed by a string and the
# statement parser stopped. rubygems' config_file.rb writes exactly that.
def pairs
  yield "a", 1
  yield "b", 2 if true
  yield :c, 3 unless false
  yield "d#{1}", 4
  yield 5, "e"
end
pairs { |k, v| p [k, v] }
def bare_yield
  yield
end
p bare_yield { :nothing }

# Exception#cause is what was in flight when this one was raised. An exception
# OBJECT records it; the built-in class-and-message representation has nowhere to
# keep one and answers nil, which is also ruby's answer when nothing was in
# flight.
class MyErr < StandardError; end
begin
  begin
    raise "inner"
  rescue
    raise MyErr.new("outer")
  end
rescue => e
  p [e.class, e.message, e.cause.class, e.cause.message]
end
begin; raise MyErr.new("solo"); rescue => e; p e.cause; end
p MyErr.new("x").respond_to?(:cause)

# Signal.trap records a handler and answers the previous one; nothing here
# delivers a signal, and every CLI traps INT before doing anything else.
p Signal.list["INT"]
p Signal.signame(2)
p [Signal.trap("USR2", "DEFAULT"), Signal.trap("USR2", "IGNORE")]
p Signal.list.size
