# Two things the VM did otherwise than the evaluator in ruby's test files
# outside test/ruby (LOOP (80)). A child runs each script as it is and with
# MERE_RUBY_VM=strict, and both print ruby's lines:
# - a call on ::Kernel inside a class under BasicObject (delegate.rb's
#   `kernel = ::Kernel.dup` in Delegator): the VM wrote the receiver as
#   `Kernel`, which such a class cannot see;
# - line Coverage of a file the VM runs, which is now compiled by the native
#   compiler (only branch Coverage needs the Ruby one): the counts are the
#   same, and a 10,000-line file no longer takes seconds.
require "rbconfig"
require "tmpdir"

MAIN = <<~'RUBY'
  class Bare690 < BasicObject
    K = ::Kernel.dup
    ::Kernel.p K.instance_of?(::Module)
    ::Kernel.p ::Kernel.format("%05.1f", 3.14159)
    ::Kernel.p ::Kernel.Integer("42")
  end
  def deleg690
    require "delegate"
    c = DelegateClass(Array)
    c.new([3, 1, 2]).sort
  end
  p deleg690
RUBY

COV = <<~'RUBY'
  require "coverage"
  Coverage.start
  require_relative "lines690"
  r = Coverage.result.find { |k, _| k.end_with?("lines690.rb") }&.last
  p r.size, r.compact.sum, r.first(6)
RUBY

LINES = <<~'RUBY'
  def f690(x)
    if x > 1
      x * 2
    else
      0
    end
  end
  3.times { |i| f690(i) }
RUBY

Dir.mktmpdir do |d|
  File.write(File.join(d, "main690.rb"), MAIN)
  File.write(File.join(d, "cov690.rb"), COV)
  File.write(File.join(d, "lines690.rb"), LINES + ("x = 1\n" * 2000))
  %w[main690.rb cov690.rb].each do |f|
    runs = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
      IO.popen([env, RbConfig.ruby, File.join(d, f), err: [:child, :out]], &:read).gsub(d, "DIR")
    end
    puts runs[0]
    puts "the same on the VM: #{runs[0] == runs[1]}"
    puts runs[1] unless runs[0] == runs[1]
  end
end
