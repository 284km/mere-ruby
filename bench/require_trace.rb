# Where does a gem's load time actually go?
#
#   GEM_HOME=... GEM_PATH=... RUBYGEMS_LIB=<rubygems>/lib \
#     mere-ruby -I<stdlib> bench/require_trace.rb <gem>
#
# Wraps Kernel#require, prints one line per enter/leave, and reports SELF time
# per file (total minus the requires nested inside it). Run it under CRuby the
# same way to get the number to compare against.
#
# The `ensure` matters: a require that RAISES (every C extension does here)
# never returns, and without it every second after the raise is charged to the
# file that raised. That mis-read is what made a plain slow load look like a
# pathology once already.
$LOAD_PATH.unshift(ENV["RUBYGEMS_LIB"]) if ENV["RUBYGEMS_LIB"]
require "rubygems"

# a monotonic clock with sub-second resolution on both interpreters (mere-ruby's
# Time has one-second resolution, which is far too coarse for this)
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

$t0 = now
$events = []

module Kernel
  alias_method :__rt_require, :require
  def require(f)
    $events << [now, :enter, f]
    __rt_require(f)
  ensure
    $events << [now, :leave, f]
  end
end

target = ARGV[0] or abort "usage: require_trace.rb <gem>"
begin
  gem target
rescue Exception
end
begin
  require target
  ok = true
rescue Exception => e
  ok = false
  err = "#{e.class}: #{e.message}"
end

self_time = Hash.new(0.0)
stack = []
last = $t0
$events.each do |(t, kind, f)|
  here = stack.last || "(top level)"
  self_time[here] += t - last
  last = t
  if kind == :enter
    stack.push(f)
  else
    stack.pop
  end
end

puts "total #{(last - $t0).round(1)}s, #{$events.count { |e| e[1] == :enter }} requires, #{ok ? 'loaded' : err}"
puts "unfinished: #{stack.last(3).inspect}" unless stack.empty?
self_time.sort_by { |_, v| -v }.first(15).each do |name, secs|
  puts format("%6.1fs  %s", secs, name)
end
