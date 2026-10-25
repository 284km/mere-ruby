# Self-referencing defaults, an endless def's rescue modifier, `it` as a
# parameter name, implicit parameters an eval cannot see, a clone's own
# singleton class, loop modifiers with a flip-flop, refused syntax, and a
# return in a class body

def f1(bar = bar) = bar
def f2(bar: bar) = bar
p f1, f2
def f3(x) = raise("e") rescue "res #{x}"
p f3(1)
p proc { |it| it * 2 }.call(4)
[1].each { p((eval("_1") rescue $!.class)); p((eval("it") rescue $!.class)); p eval("[:a].map { it }") }

a = []
def a.f = :a
b = a.clone
def b.f = :b
p [a.f, b.f]

@n = nil
@n = 456 while @n == nil..true
p @n

["->a,... {}", "proc {_1; _1 = nil}", "proc {_1 = nil}", "proc {|_3|}", "def _5; end", "def foo=() = 42",
 "class X; return; end", "class X; [1].each { return }; end"].each do |src|
  r = begin
    RubyVM::InstructionSequence.compile(src)
    :ok
  rescue SyntaxError => e
    e.message[/unexpected \.\.\.|Can't assign to numbered parameter _1|_\d is reserved|setter method|Invalid return/]
  end
  p [src, r]
end

class C396
  begin
    proc { return }.call
  rescue LocalJumpError => e
    p e.message
  end
  begin
    eval "return"
  rescue LocalJumpError => e
    p e.message
  end
end
x = "#{return}"
p :not_reached
