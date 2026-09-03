# Interned frozen strings (`"lit".freeze`, `-str`), a proc's source location and
# a curried proc's collected arguments live in tables the collector does not
# otherwise see. A collection between their creation and their next use must
# leave them intact: each of these once came back blank after one.
class Node; attr_accessor :v; def initialize(v) = @v = v; end
def mk_canon; ">= 3.0.1".freeze; end
def mk_dyn(x); -"dyn-#{x}"; end
mk_canon          # interned here, held by nobody across the collection below
mk_dyn(7)
pr = proc { |a| a }
loc = pr.source_location
add3 = ->(a, b, c) { a + b + c }
c1 = add3.curry[1][2]
sym_pr = :upcase.to_proc
i = 0
while i < 80
  junk = Array.new(200) { |k| Node.new(k + i) }
  s = 0
  junk.each { |n| s += n.v }
  i += 1
end
second = mk_canon
p [second, second.frozen?, second.length, second.equal?(mk_canon)]
p [mk_dyn(7), mk_dyn(7).frozen?, mk_dyn(7).equal?(mk_dyn(7))]
p [pr.source_location == loc, loc[0].end_with?("165_interned_strings_survive_gc.rb"), loc[1]]
p c1[3]
p sym_pr.call("ok")
