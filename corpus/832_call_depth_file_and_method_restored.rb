# After a call returns -- in order, by an exception, out of a block, a Fiber
# or a Thread -- the file and the method the caller is in are its own again:
# what caller_locations, __method__ and a backtrace say next. The methods
# called are written in other files, so a wrong file after the return shows.
require "tmpdir"
dir = Dir.mktmpdir("mrb_depth")
File.write(File.join(dir, "depth_a.rb"), <<~'A')
  module DepthA
    def self.where = caller_locations(0, 2).map { |l| [File.basename(l.path), l.label] }
    def self.boom = raise(ArgumentError, "a")
    def self.twice = yield + yield
  end
A
File.write(File.join(dir, "depth_b.rb"), <<~'B')
  module DepthB
    def self.via_a = DepthA.where
    def self.rescued = (DepthA.boom rescue $!.backtrace_locations.first(2).map { |l| [File.basename(l.path), l.label] })
  end
B
require File.join(dir, "depth_a.rb")
require File.join(dir, "depth_b.rb")

def here = caller_locations(0, 1).map { |l| [File.basename(l.path), l.label] }.first

class Probe
  def run
    out = []
    out << DepthA.where
    out << here
    out << DepthB.via_a
    out << here
    out << DepthB.rescued
    out << here
    out << (begin; DepthA.boom; rescue => e; [e.message, here]; end)
    out << DepthA.twice { here[1].size }
    out << [__method__, here]
    out
  end
end
Probe.new.run.each { |x| p x }

f = Fiber.new { [DepthB.via_a, here] }
p f.resume, here
p Thread.new { [DepthA.where.first, here] }.value, here

def deep(n) = n.zero? ? [DepthA.where.first, __method__] : deep(n - 1)
p deep(50), here

r = [1, 2].map { |i| [DepthB.via_a.first, here[1]] }
p r, here
