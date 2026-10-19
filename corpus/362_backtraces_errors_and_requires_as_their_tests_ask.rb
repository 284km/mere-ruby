# Backtraces, errors and requires as test_backtrace, test_exception and
# test_require ask (note 386): an exception the interpreter raised has
# Locations as well as a backtrace; another thread's backtrace has Locations
# and is selected by (level, length); a standard stream given an external
# encoding writes other encodings converted to it, and raise keeps a message's
# encoding; `(a, b), = [[1, 2]]` takes the first element apart; a feature a
# required file provides by name is loaded, and a feature enters $" when its
# file finishes.
require "tmpdir"
def catch_it(k)
  yield
rescue k => e
  e
end
e = catch_it(TypeError) { {**1} }
p e.backtrace_locations.first.lineno == e.backtrace.first[/:(\d+):/, 1].to_i
p e.backtrace_locations.first.class
def th_rec(q, n = 3) = n > 1 ? th_rec(q, n - 1) : q.pop
q = Thread::Queue.new
th = Thread.new { th_rec(q) }
Thread.pass until th.status == "sleep"
p th.backtrace_locations.map(&:to_s) == th.backtrace
p th.backtrace(0, 2).size, th.backtrace_locations(1, 1).size
q << true
th.join
s = "\x82\xa0".dup.force_encoding("Windows-31J")
$stdout.set_encoding("UTF-8")
$stdout.write(s, "\n")
p $stdout.external_encoding
begin
  raise s
rescue => err
  p err.message.encoding
end
(a, b), = [[1, 2]]
p [a, b]
(c, (d, f)), = [[3, [4, 5]]]
p [c, d, f]
Dir.mktmpdir do |dir|
  File.write(File.join(dir, "target362.rb"), "raise 'should not load'\n")
  File.write(File.join(dir, "provide362.rb"), "$\" << 'target362.rb'\n")
  $: << dir
  p require("provide362"), require("target362")
  p $".last(2).map { File.basename(_1) }
  File.write(File.join(dir, "outer362.rb"), "require 'inner362'\n")
  File.write(File.join(dir, "inner362.rb"), "")
  require "outer362"
  p $".last(2).map { File.basename(_1) }
end
