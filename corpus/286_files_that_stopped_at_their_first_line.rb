# What stopped five of CRuby's test files at their first lines, and three more
# part-way (note 272): `!~` leaving $~, Module.used_modules, a class's private
# hook as a Method, objspace, Time.new with :dst / :std, a combination walked
# one at a time, and an index too big to write.
ENV["TZ"] = "America/New_York"

# `!~` is `=~` answered the other way round; a match still sets $~
p(/(\d+)-(\d+)/ !~ "a 12-34 b")
p $~ && $~.captures
p(/z/ !~ "abc")
p $~

module RefA; refine(String) { def shout = upcase + "!" }; end
module RefB; include RefA; refine(Integer) { def twice = self * 2 }; end
p Module.used_modules
module UsesB
  using RefB
  p Module.used_modules
  p Module.used_refinements.size
end

class Hooked
  class << self
    define_method(:method_added, Module.method(:method_added))
  end
  def later = 1
end
p Hooked.new.later

require "objspace"
p ObjectSpace.memsize_of(nil), ObjectSpace.memsize_of(1)
p ObjectSpace.memsize_of("x" * 1000) >= 1000
p ObjectSpace.count_objects.key?(:TOTAL)
p ObjectSpace.trace_object_allocations { :inside }

p Time.new(2010, 11, 7, 1, 30, 0, :dst).utc_offset
p Time.new(2010, 11, 7, 1, 30, 0, :std).utc_offset
p Time.new(2000, 1, 1, 0, 0, 0, :std).to_s

seen = 0
(0..60).to_a.combination(30) { |c| seen += 1; break if seen == 3 }
p seen
r = []
[1, 2, 3].permutation(2) { |x| r << x }
p r
r = []
[1, 2].repeated_combination(2) { |x| r << x }
p r
r = []
[1, 2].repeated_permutation(2) { |x| r << x }
p r
p [1, 2, 3].combination(0).to_a, [1, 2].combination(3).to_a

[2**60 - 1, 2**62, 2**63 - 1].each do |i|
  begin
    [0][i] = 1
  rescue IndexError => e
    p e.message
  end
end
begin
  [0][2**60 - 2, 1] = [1, 2]
rescue IndexError => e
  p e.message
end
p RbConfig::CONFIG["EXECUTABLE_EXTS"]
