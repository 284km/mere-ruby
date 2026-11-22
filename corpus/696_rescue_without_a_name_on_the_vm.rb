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

# A matcher can keep the exception even when the clause binds no variable.
class RetainingRescueMatcher
  class << self
    attr_accessor :accept
    attr_reader :saved, :same_current
    def ===(exception)
      @saved = exception
      @same_current = exception.equal?($!)
      @accept
    end
  end
end
RetainingRescueMatcher.accept = true
begin
  boom("retained")
rescue RetainingRescueMatcher
end
saved = RetainingRescueMatcher.saved
frames = saved.backtrace.dup
begin
  boom("later")
rescue ArgumentError
end
p saved.message, frames == saved.backtrace, RetainingRescueMatcher.same_current

# A rejecting matcher and a subsequent accepting matcher see one object.
class AcceptingRescueMatcher
  def self.===(exception)
    p exception.equal?(RetainingRescueMatcher.saved), exception.equal?($!)
    true
  end
end
RetainingRescueMatcher.accept = false
begin
  boom("next clause")
rescue RetainingRescueMatcher
rescue AcceptingRescueMatcher
end

# Splat patterns share the pinned object, as does propagation to an outer rescue.
matchers = [RetainingRescueMatcher, AcceptingRescueMatcher]
begin
  boom("splat")
rescue *matchers
end
begin
  begin
    boom("propagated")
  rescue RetainingRescueMatcher
  end
rescue => exception
  p exception.equal?(RetainingRescueMatcher.saved), exception.equal?($!)
end

# Resolving a rescue class can itself execute Ruby and replace raise metadata.
require 'tmpdir'
def original_autoload_raise
  raise 'original autoload exception'
end
Dir.mktmpdir('rescue-autoload') do |directory|
  feature = File.join(directory, 'retaining_matcher.rb')
  File.write(feature, <<~RUBY)
    begin
      raise 'during matcher loading'
    rescue
    end
    class AutoloadRetainingRescueMatcher
      def self.===(exception)
        $autoload_saved_exception = exception
        $autoload_same_exception = exception.equal?($!)
        true
      end
    end
  RUBY
  autoload :AutoloadRetainingRescueMatcher, feature
  begin
    original_autoload_raise
  rescue AutoloadRetainingRescueMatcher
  end
  p [:autoload_frames, $autoload_saved_exception.backtrace.first.include?('original_autoload_raise'),
     $autoload_same_exception, $autoload_saved_exception.message]
end

class MissingRescueMatcherNamespace
  def self.const_missing(name)
    begin
      raise 'during const_missing'
    rescue
    end
    AutoloadRetainingRescueMatcher
  end
end
begin
  original_autoload_raise
rescue MissingRescueMatcherNamespace::Matcher
end
p [:missing_constant_frames, $autoload_saved_exception.backtrace.first.include?('original_autoload_raise'),
   $autoload_same_exception]
