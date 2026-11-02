# coding: US-ASCII
# A method the interpreter writes in Ruby is a C method of ruby's: its frame
# is at the place of the frame that called it
def strip(ls) = ls.map { |l| l.to_s.sub(/\A.*?:(\d+)?:?in /) { "#{$1}:in " } }
o = Object.new
def o.each; yield caller_locations(0); end
o.extend(Enumerable)
def t(o) = o.to_a.first
puts strip(t(o))
puts "--"

# an Enumerator walks under Enumerator#each (and a generator under its
# Generator#each), and to_a under Enumerable#to_a
e = Enumerator.new { |y| y << caller_locations(0) }
puts strip(e.to_a.first)
puts "--"
puts strip(e.map { |x| x }.first)
puts "--"
def v = Thread.to_enum(:each_caller_location).to_a
puts strip(v.first(2))
p((Thread.to_enum(:each_caller_location).next rescue $!.class))
puts "--"

# a builtin of an object's takes no block and ignores one
p Object.new.frozen? { }, Object.new.respond_to?(:x) { }
p((Object.new.no_such_thing { } rescue $!.class))
def o.kept; yield [caller_locations(0)[0]].map(&:to_s).size; end
p o.kept { |n| n }

# a builtin ruby writes in Ruby has its place, and its disassembly
p "x".method(:unpack).source_location, 1.method(:times).source_location, 1.method(:+).source_location
puts RubyVM::InstructionSequence.of("\x00".method(:unpack)).disasm.lines[3]

# RubyVM::AbstractSyntaxTree refuses what the parser refuses; an interpolated
# literal of this US-ASCII file is a literal too
p RubyVM::AbstractSyntaxTree.parse("a = 1").type
[%q[def (1).foo; end], %q[def ("#{42}").foo; end], %q[def (:"#{42}").foo; end]].each do |c|
  begin
    RubyVM::AbstractSyntaxTree.parse(c)
    p :parsed
  rescue SyntaxError => e
    p e.message
  end
end

# TracePoint: the #each an Enumerable method calls, by the name it was called
# by; a block's and a define_method body's events name the alias
s = Class.new(String) { include Enumerable; alias each each_char }.new("foo")
ev = []
TracePoint.new(:c_call, :c_return) { |tp| ev << [tp.event, tp.method_id, tp.callee_id] }.enable { s.find { true } }
p ev
k = Class.new { define_method(:m) { tap { return } }; alias alias_m m }.new
ev = []
TracePoint.new(:b_return) { |tp| ev << [tp.event, tp.method_id, tp.callee_id] }.enable { k.alias_m }
p ev[0, 2]
c = Class.new { alias initialize itself }
ev = []
TracePoint.new(:c_call) { |tp| ev << [tp.method_id, tp.callee_id] }.enable { c.new }
p ev
