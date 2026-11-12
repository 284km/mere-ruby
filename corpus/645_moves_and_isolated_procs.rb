# Round 24 of note 545 (stage 9): what a ractor is sent with move: true is
# gone from the sender; make_shareable freezes in ruby's order and checks a
# Proc's self and a Method's receiver; shareable_proc and Ractor.new isolate
# their block; a ractor has standard streams of its own; a method define_method
# made from an unshareable block stays in its ractor.
Warning[:experimental] = false

# a moved object (and what it held) answers nothing; the receiver has it
r = Ractor.new { Ractor.receive }
inner = "inner".dup
box = [inner, 1]
r.send(box, move: true)
p r.value
[box, inner].each do |o|
  begin
    o.size
  rescue Ractor::MovedError => e
    p [Ractor::MovedObject === o, e.message]
  end
end
begin
  [].concat(box)
rescue TypeError => e
  p e.class
end

# make_shareable: the object's own #freeze first, then what it holds
class Holder
  def initialize; @a = "a".dup; end
  def freeze; @c = ["set by freeze"]; super; end
  attr_reader :a, :c
end
class N24 < Numeric; def /(o) = 1; end
h = Holder.new
all = [h, Complex(N24.new, 0), Rational(N24.new, 0), ("x".dup.."y".dup), /m/.match("m")]
Ractor.make_shareable(all)
p [h.frozen?, h.a.frozen?, h.c, h.c.frozen?, all[1].real.frozen?, all[2], all[3].begin.frozen?, all[4].frozen?]
p Ractor.shareable?(all), /m/.match("m").instance_variables

# a Proc needs a shareable self, a Method a shareable receiver
[nil.instance_exec { Proc.new {} }, Proc.new {}].each do |pr|
  Ractor.make_shareable(pr)
  p :ok
rescue Ractor::Error => e
  p e.message[/^.+?:/]
end
begin
  Ractor.make_shareable(Object.new.method(:hash))
rescue Ractor::Error => e
  p e.message.start_with?("can not make shareable object")
end
M24 = Ractor.make_shareable(Object.method(:name))
p Ractor.new { M24.call }.value

# shareable_proc: a copy whose self is nil, the outer locals it reads copied
v1, v2 = :a, [1].freeze
sp = Ractor.shareable_proc { [self, v1, v2] }
p sp.call, sp.frozen?
p Ractor.shareable_lambda { v1 }.lambda?
begin
  Ractor.shareable_proc(self: Object.new) {}
rescue Ractor::IsolationError => e
  p e.message.start_with?("self should be shareable")
end
w = 1
begin
  Ractor.shareable_proc { w }
rescue Ractor::IsolationError => e
  p e.message
end
w = 2
mut = "mutable".dup
begin
  Ractor.shareable_proc { mut }
rescue Ractor::IsolationError => e
  p e.message.end_with?("from variable 'mut'")
end

# an isolated proc cannot reach where it was written
outer = 42
pr = Ractor.shareable_proc { eval("outer") }
begin
  pr.call
rescue SyntaxError => e
  p e.class
end
begin
  pr.binding
rescue ArgumentError => e
  p e.message
end
p(begin; Ractor.new { eval("outer") }.value; rescue Ractor::RemoteError => e; e.cause.class; end)

# a ractor's own $stdout, on the same descriptor
p Ractor.new { [$stdout.fileno, $stderr.fileno] }.value
ours = $stdout.object_id
p Ractor.new(ours) { |o| $stdout.object_id == o }.value

# a method from an unshareable block answers only in its ractor
str = "s".dup
define_method(:grow24) { |x| str << x.to_s }
p(begin; Ractor.new { grow24(1) }.join; rescue Ractor::RemoteError => e; e.cause.message; end)

# a non-main ractor's trap handler may not read the ractor's locals
p(begin
    Ractor.new { s = 1; trap(:USR2) { s } }.join
  rescue Ractor::RemoteError => e
    e.cause.message
  end)

# a queue of 20,000 unread messages is linear
q = Thread::Queue.new
20_000.times { |i| q << i }
p q.size, q.pop, q.pop
