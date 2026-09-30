# Refinements are lexical: a method sees the refinements active where it was
# WRITTEN, not where it is called from, and a `using` ends with its scope.

module Shout
  refine String do
    def shout; upcase + "!"; end
  end
end

class Outside
  def self.try(s)
    s.shout
  rescue NoMethodError
    "no refinement here"
  end
end

class Inside
  using Shout
  def self.try(s) = s.shout
  def self.lam = -> { "block".shout }
end

puts Inside.try("hi")
puts Outside.try("hi")          # called from nowhere refined
puts Inside.lam.call            # a lambda keeps its scope
begin
  "top".shout
rescue NoMethodError => e
  puts "top: #{e.class}"
end

# a method written outside the `using` does not see it, even when called inside
res = nil
Module.new do
  def self.call_it(s) = (s.shout rescue "outside")
  using Shout
  res = [call_it("x"), "y".shout]
end
p res

# the refine body has its own module's refinements -- all of them
Json = Module.new do
  refine(Integer) { def to_j = to_s }
  refine(Array) { def to_j = "[" + map { |x| x.to_j }.join(",") + "]" }
  refine(Hash) { def to_j = "{" + map { |k, v| "#{k.to_j}:#{v.to_j}" }.join(",") + "}" }
end
Module.new do
  using Json
  p [1, {2 => [3]}].to_j
end

# using an including module activates the included module's refinements too
Inc = Module.new do
  include Json
  refine(String) { def to_j = inspect }
end
Module.new do
  using Inc
  p [5.to_j, "s".to_j]
  p Module.used_refinements.size
end

# import_methods copies a module's own methods into the refinement
Pad = Module.new { def pad(n) = " " * n + self }
Padded = Module.new { refine(String) { import_methods Pad } }
Module.new do
  using Padded
  p "x".pad(2)
  p String.instance_method(:pad).owner == Padded.refinements.first
  p "x".respond_to?(:pad)
end
begin
  Module.new { refine(String) { import_methods Integer } }
rescue TypeError => e
  puts e.message
end

# main.using checks its argument
[-> { eval("using", TOPLEVEL_BINDING) }, -> { eval("using 1", TOPLEVEL_BINDING) }].each do |f|
  f.call
rescue => e
  puts "#{e.class}: #{e.message}"
end
