# `^name` pins a local: a name that is none where it stands is a SyntaxError
def pin_err(src)
  eval(src)
  :ok
rescue SyntaxError => e
  e.message[/\w+: no such local variable/]
end
p pin_err("case 0\nin ^a\nend")
p pin_err("case {k: 1}\nin {k: ^q}\nend")
x = 1
p eval("case 1; in ^x then :pinned; end")
o = Object.new
z = 3
p o.instance_eval("case 3; in ^z then :pinned_z; end")
case [1, 1]
in [a, ^a] then p :pattern_var
end
p(5 ^ 3, x ^1)

# an eval may start at line 0 or below
obj = Object.new
obj.instance_eval("def t(e = false);raise if e; __LINE__;end", "test", -100)
p obj.t, obj.method(:t).source_location
begin
  obj.t(true)
rescue => e
  p e.backtrace_locations.first.lineno, e.backtrace.first
end
obj.instance_eval("def u\n  __LINE__\nend", "t2", 0)
p obj.u
p eval("[__LINE__,\n__LINE__]", nil, "x", -3)
