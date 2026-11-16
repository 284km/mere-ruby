# Round 41 of note 552: pattern matching, compiled and run on the ISeq VM.
# `case / in`, `expr => pattern` and `expr in pattern` are compiled as
# prism_compile.c compiles them -- the stack as the scratch space, the
# deconstruct cache, the error a single pattern raises put together as it
# fails -- and the VM runs that. A child runs one script as it is and with
# MERE_RUBY_VM=strict, which raises where the compiler or the VM would not
# take the file, and the two runs print the same lines, ruby's: array, find
# and hash patterns, guards, pins, alternatives, a Struct's deconstruct and
# deconstruct_keys, and the errors (NoMatchingPatternError with why,
# NoMatchingPatternKeyError with its key, the TypeError of a deconstruct of
# the wrong type). And beside them what the first whole files of patterns
# on the VM showed: a NameError's local_variables has the locals its frame
# has not assigned yet, `raise Cls, obj` says the object's own to_s.
require "rbconfig"
require "tmpdir"

MAIN = <<~'RUBY'
  def t(l); r = yield; puts "#{l}: #{r.inspect}"; rescue Exception => e; puts "#{l}: #{e.class}: #{e.message}"; end
  t(1) { case [1, 2]; in [a, b] then a + b; in [] then 0; end }
  t(2) { case 5; in Integer => n if n > 3 then [:big, n]; in String then :s; end }
  t(3) { case {a: 1, b: 2}; in {a: Integer => v, **rest} then [v, rest]; end }
  t(4) { x = [1, [2, 3]]; x => [a, [b, *c]]; [a, b, c] }
  t(5) { [1, 2] => [a] }
  t(6) { {a: 1} => {b:} }
  t(7) { 5 => String }
  t(8) { case [1, 42, "x", :k]; in [*, String => s, *post] then [s, post]; end }
  t(9) { pin = 42; [([1, 42] in [_, ^pin]), ([1, 41] in [_, ^pin]), (1 in Integer | String)] }
  t(10) { case 7; in 1..3 then :low; in 4.. then :high; end }
  t(11) { case {name: "x", extra: 1}; in {name: String => nm, **nil} then nm; else :no; end }
  t(12) { case 3; in String then 1; in Symbol then 2; end }
  Point = Struct.new(:x, :y)
  t(13) { case Point.new(1, 2); in [x, y] then [x, y]; end }
  t(14) { case Point.new(1, 2); in {x:, y:} then x + y; end }
  t(15) { case Point.new(1, 2); in Point(x:, y: 5) then :five; in Point(x, y) then [:pos, x, y]; end }
  t(16) { o = Object.new; def o.deconstruct = 1; case o; in [a] then a; end }
  t(17) { case 5; in n unless n > 3 then :small; in n then [:any, n]; end }
  t(18) { case [1, [2, [3, 4]]]; in [a, [b, [*c]]] then [a, b, c]; end }
  t(19) { {a: 1} => {a: String} }
  t(20) { nil => {a:} }
  t(21) { o = Object.new; def o.deconstruct_keys(k) = 1; case o; in {a:} then a; end }
  t(22) { case {a: 1}; in {a: 1 | 2 => v} then v; end }
  t(23) { case [1, 2, 3, 4, 5]; in [first, *mid, last] then [first, mid, last]; end }
  t(24) { h = {status: "ok", items: [{id: 1}, {id: 2}]}; case h; in {status: "ok", items: [{id: first_id}, *]} then first_id; end }
  t(25) { case 1; in Integer | Float => num then num; end }
  t(26) { x = 5; case 5; in ^x then :same; end }
  t(27) { case []; in [] then :empty; end }
  t(28) { case {}; in {} then :empty_hash; end }
  t(29) { case {a: 1}; in {} then :empty_hash; else :not_empty; end }
  t(30) { a = [1, "two", :three, 4.0]; a.map { |v| case v; in Integer | Float => n then n * 2; in String => s then s.upcase; in Symbol then :sym; end } }

  # a NameError's locals: the frame's own, assigned yet or not
  def lv666(a, b = nil); e = a; 1.times { |f| g = no_such_thing; g }; e; end
  t(31) { begin; lv666(3); rescue NameError => e; e.local_variables.sort; end }
  # a message that is no String
  t(32) { begin; raise RuntimeError, 3; rescue => e; e.message; end }
  t(33) { begin; raise ArgumentError, :sym; rescue => e; e.message; end }
  t(34) { o = Object.new; def o.to_s = "mine"; begin; raise TypeError, o; rescue => e; e.message; end }
  # values as nobody reads them: an unread range is its bounds, nil&.m is nil
  t(35) { r = 0; (r = 1)..(r += 1); x = nil&.never_called(r += 5); [r, x] }
  # a flip-flop's state, a pattern alone as a condition (the last line read)
  t(36) { (1..10).select { |i| true if (i == 3)..(i == 5) } + (1..10).select { |i| true if (i % 4 == 0)...(i % 2 == 0) } }
  t(37) { $_ = "a line"; [(/line/ ? :hit : :miss), (/none/ ? :hit : :miss)] }
  # once: `/o` builds its pattern the first time it is reached, a thread that
  # arrives meanwhile waits for it; END registers its block the first time
  t(38) { f = ->(x) { /a#{x}/o }; [f.(1), f.(2), f.(1).equal?(f.(3))] }
  t(39) do
    g = proc { |s, c| /#{c.call; s}/o }
    i = 0
    b = Thread.new { sleep 0.01 until i == 1; i = 2; g.call("late", proc { sleep 0.2 }); nil }
    a = Thread.new { g.call("first", proc { i = 1; sleep 0.01 until i == 2; sleep 0.01 }); nil }
    [a, b].each(&:join)
    g.call.source
  end
  # a for loop's target that is no local: the block's parameters written to it
  t(41) { o = Struct.new(:x).new; h = {}; for @iv in [1, 2]; end; for $g666 in [3]; end; for o.x in [7]; end; for h[1] in [8]; end; [@iv, $g666, o.x, h] }
  t(42) { r = []; for a, b in [[1, 2], 5, [6, 7, 8], nil]; r << [a, b]; end; for *s in [[1, 2], 3]; r << s; end; for i, in [[4, 5]]; r << i; end; r }
  n666 = 40
  t(40) { 3.times { END { puts "END, registered once: #{n666}" } }; n666 += 1 }
  at_exit { puts "at_exit, before the END registered earlier" }
RUBY

Dir.mktmpdir do |d|
  File.write(File.join(d, "main666.rb"), MAIN)
  runs = [{}, { "MERE_RUBY_VM" => "strict" }].map do |env|
    IO.popen([env, RbConfig.ruby, File.join(d, "main666.rb"), err: [:child, :out]], &:read).gsub(d, "DIR")
  end
  puts runs[0]
  puts "the same on the VM: #{runs[0] == runs[1]}"
  puts runs[1] unless runs[0] == runs[1]
end
