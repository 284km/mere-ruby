# Ripper's handlers answer what they like: the parse never looks inside a
# value an event returned (test/ripper's parse-files Parser answers
# Object.new for every event).
require "ripper"
require "prism"

class Opaque < Ripper
  PARSER_EVENTS.each { |n| define_method("on_#{n}") { |*a| Object.new } }
  SCANNER_EVENTS.each { |n| define_method("on_#{n}") { |*a| Object.new } }
end
p Opaque.new("foo 1, 2\nbar(3)\nbaz &blk\nx.y 4\n").parse.class
p Ripper.sexp("foo 1, 2")
p Ripper.sexp("foo &b")

# The node a frame was running, by the id ruby's Prism compiler gives it
# (error_highlight finds the node with this).
def two(a, b) = a
begin
  nil.foo + 1
rescue NoMethodError => e
  p RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(e.backtrace_locations.first)
end
begin
  two(1)
rescue ArgumentError => e
  p e.backtrace_locations.map { |l| RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(l) }
end
begin
  1.+(nil)
rescue TypeError => e
  p e.backtrace_locations.map { |l| RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(l) }
end
# Two calls of one name on the line: the node is the one that raised, or none
# at all -- never the call that succeeded.
begin
  'first'.upcase; nil.upcase
rescue NoMethodError => e
  id = RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(e.backtrace_locations.first)
  node = Prism.parse_file(__FILE__).value.breadth_first_search { |n| n.node_id == id }
  p node.nil? || node.slice == "nil.upcase"
end
p((RubyVM::AbstractSyntaxTree.node_id_for_backtrace_location(1) rescue $!))
p((RubyVM::AbstractSyntaxTree.of(proc { 1 }) rescue $!))
p((RubyVM::AbstractSyntaxTree.of(method(:p)) rescue $!))
p((RubyVM::AbstractSyntaxTree.of(1) rescue $!))

# A rescued exception keeps its own frames when something else raises later.
begin
  1 + nil
rescue TypeError => e
end
first = e.backtrace_locations.map(&:lineno)
begin; raise "later"; rescue; end
p e.backtrace_locations.map(&:lineno) == first, e.backtrace == e.backtrace_locations.map(&:to_s)

# A refused []= names whom it was asked of.
begin
  nil[0] = 1
rescue NoMethodError => e
  p e.message, e.name
end

# A detailed_message of the program's own reaches a raised TypeError, and its
# super is Exception's. (ruby has error_highlight loaded from the start, and
# its #detailed_message takes error_highlight: false to leave the snippet out)
module Decorate
  def detailed_message(highlight: false, **) = "<" + super + ">"
end
TypeError.prepend(Decorate)
begin
  1 + nil
rescue TypeError => e
  p e.detailed_message(error_highlight: false)
end

# An object's instance variables in the order they were set; one removed and
# set again goes to the end.
class Three
  def initialize
    @a = 1
    @b = 2
    @c = 3
  end
end
t = Three.new
p t.instance_variables
t.remove_instance_variable(:@a)
p t.instance_variables
t.instance_variable_set(:@a, 4)
p t.instance_variables, t.inspect.sub(/0x\h+/, "X")
S3 = Struct.new(:x)
s = S3.new(1)
s.instance_variable_set(:@q, 2)
p s.instance_variables

# The exception a rescue binds equals the one a TracePoint saw being made,
# alone and inside arrays, from either side.
seen = nil
tp = TracePoint.new(:c_call) { |t| seen = t.self if t.method_id == :initialize && t.defined_class == Exception }
tp.enable
begin; raise RuntimeError; rescue RuntimeError => bound; end
tp.disable
p bound == seen, seen == bound, [bound] == [seen], [seen] == [bound], [[1, seen]] == [[1, bound]]

# ...but that exception does not hand its comparison to an unrelated object:
# one whose #== says true to anything is not asked, from inside an Array
# either (PR #81's review).
class EqualAnything
  def ==(other)
    $calls += 1
    true
  end
end
$calls = 0
other = EqualAnything.new
p seen == other, [seen] == [other], [[1, seen]] == [[1, other]], [seen].include?(other), $calls
p other == seen, $calls

# ...and an exception on the right that overrides #== is compared by the
# left one's Exception#== (class, message, backtrace), without calling the
# override (PR #81's review, second round).
tp2 = TracePoint.new(:c_call) { |t| seen = t.self if t.method_id == :initialize && t.defined_class == Exception }
tp2.enable
begin; raise RuntimeError, "same"; rescue RuntimeError => bound; end
tp2.disable
twin = bound.dup
$calls = 0
def twin.==(x)
  $calls += 1
  false
end
p seen == twin, [seen] == [twin], [seen].include?(twin), $calls

# ...comparing what the exceptions hold, not what #message / #backtrace
# present: an override neither changes the answer nor runs (third round).
shown = bound.dup
$calls = 0
def shown.message
  $calls += 1
  "different"
end
loud = bound.dup
def loud.message = raise("called")
def loud.backtrace = raise("called")
p seen == shown, [seen] == [shown], [seen].include?(shown), $calls
p seen == loud, [seen] == [loud]
