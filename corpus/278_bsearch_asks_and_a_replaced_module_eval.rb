# Range#bsearch asks the block exactly what CRuby asks it, in the same order --
# CRuby's own tests count the asks -- and a module_eval the program replaced
# on a singleton takes its block call.
[[1..100, 37], [-123456789..-1, 0], [-42...42, -7], [0..0, 0], [5..4, 1],
 [-(2**100)..-123456789, -1000], [-(2**70)..(2**70), 12345]].each do |r, t|
  asked = []
  found = r.bsearch { |x| asked << x; x >= t }
  p [found, asked.size, asked.first(4)]
end
asked = []
p (0..100).bsearch { |x| asked << x; 50 <=> x }, asked
p (-5..5).bsearch { |x| x >= 0 }, (1...1).bsearch { |x| true }

module M278; end
M278.singleton_class.send :define_method, :module_eval do |src, id, line|
  [src, id, line]
end
p M278.module_eval("f", "", 3) { }
class K278
  def self.class_exec(*a) = (yield + a.size)
end
p K278.class_exec(1, 2) { 10 }
