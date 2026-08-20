# A block's own `&b` parameter binds the block given at the CALL SITE, exactly as
# a method's does. The interpreter bound nil, with a comment saying blocks are not
# re-passed through block params -- ruby says otherwise, and a comment that says
# why something is not done outlives the reason.
pr = proc { |*a, &b| [a, b.class, (b ? b.call(a[0]) : nil)] }
p pr.call(5) { |v| v * 3 }
p proc { |x, &b| b.call(x) }.call(7) { |v| v + 1 }
def m2(x); yield x; end
p proc { |*a, &b| m2(*a, &b) }.call(9) { |v| v * 2 }
p proc { |x, &b| b.nil? }.call(1)

# ... which is what lets Method#to_proc carry a block to the method. The proc also
# answers the METHOD's arity and is a lambda, where the `*args` forwarder that
# implements it would say -1 and false.
def takes_block(x); yield x; end
m = method(:takes_block)
p m.to_proc.call(5) { |v| v * 3 }
def one(a); end
def opt(a, b = 1); end
def splat(*a); end
[method(:one), method(:opt), method(:splat)].each do |mm|
  p [mm.name, mm.arity, mm.to_proc.arity, mm.to_proc.lambda?]
end
def no_block(x); x * 2; end
p [1, 2, 3].map(&method(:no_block))
p (m.to_proc.call(1) rescue $!.class)

# An Errno class puts the system's own text in front of the message it is given.
begin; raise Errno::ENOENT, "boom"; rescue => e; p e.message; end
begin; raise Errno::EACCES; rescue => e; p e.message; end
begin; raise Errno::EPIPE, "x"; rescue SystemCallError => e; p [e.class, e.message]; end
p Errno::ENOENT.ancestors.include?(SystemCallError)

# A reflection call REFUSES a name that could never be a variable of that kind,
# rather than answering nil. (Only the class is compared: the wording here
# follows ruby 3.4's quoting, and the reference for this corpus is 3.2.2.)
o = Object.new
["x", "@@x", "@", "", "@1", "@ x"].each do |n|
  p [n, (begin; o.instance_variable_get(n); rescue NameError; :NameError; end)]
end
p o.instance_variable_get(:@never_set)
o.instance_variable_set(:@ok, 1)
p [o.instance_variable_get("@ok"), o.instance_variable_defined?(:@ok), o.instance_variables]
class K; end
["x", "@x", "@@"].each do |n|
  p [n, (begin; K.class_variable_get(n); rescue NameError; :NameError; end)]
end

# caller_locations answers one Location per frame, from the same frames caller
# reads -- it used to answer a single location with an empty label and lineno 0.
def m3; caller_locations(0, 2).map(&:label); end
p m3
def m4; caller_locations(0, 2).map { |l| [l.label, l.lineno.is_a?(Integer), l.path.end_with?(".rb")] }; end
p m4
p caller_locations(0, 1).map(&:label)

# A Location prints as the frame it names, and that answer is needed twice: the
# dispatcher answers `loc.to_s`, and a Location inside an array is formatted by
# the value printer instead, which is what `p caller_locations` goes through.
def m5; caller_locations(0, 1); end
p m5.map { |l| l.to_s.end_with?("in `m5'") }
p m5.first.inspect.end_with?("in `m5'\"")
p caller_locations.class

# `a&.map(&:to_s)`: a trailing block-PASS is a block, and safe navigation used to
# keep it as an ARGUMENT -- so this answered an Enumerator with a stray argument
# where ruby answers a mapped array. `.map(&:to_s)` went through the same rewrite
# already; only `&.` did not.
p [1, 2]&.map(&:to_s)
p [3, 1]&.sort_by { |x| -x }
p nil&.map(&:to_s)
p "ab"&.sub("a") { "z" }
p({ a: 1 }&.map { |k, v| [k, v] })
